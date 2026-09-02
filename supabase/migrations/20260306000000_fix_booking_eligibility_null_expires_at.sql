-- Migration: Fix booking eligibility + orphaned schedule instances + schedule RPC
--
-- Problem 1: payment_confirmations created by the app never set expires_at,
-- but the eligibility function requires `pc.expires_at > NOW()`.
-- In PostgreSQL NULL > NOW() = NULL (falsy), so ALL payments were silently rejected.
-- Fix: Treat NULL expires_at as "never expires" using (IS NULL OR > NOW()).
--
-- Problem 2: schedule_instances exist with seasonal_schedule_id = NULL (orphaned).
-- The get_class_schedule_with_enrollments RPC uses INNER JOIN seasonal_schedules,
-- which excludes these orphaned instances. The generate function can't replace them
-- due to ON CONFLICT DO NOTHING. Fix: assign orphans to the active season, and
-- make the RPC resilient to NULL seasonal_schedule_id.

-- ========================================
-- FIX 1: Assign orphaned schedule instances to the active season
-- ========================================

DO $$
DECLARE
    active_season_id UUID;
    updated_count INTEGER;
BEGIN
    SELECT id INTO active_season_id
    FROM public.seasonal_schedules
    WHERE status = 'active'
      AND start_date <= CURRENT_DATE
      AND end_date >= CURRENT_DATE
    ORDER BY created_at DESC
    LIMIT 1;

    IF active_season_id IS NOT NULL THEN
        UPDATE public.schedule_instances
        SET seasonal_schedule_id = active_season_id
        WHERE seasonal_schedule_id IS NULL
          AND class_date >= (SELECT start_date FROM public.seasonal_schedules WHERE id = active_season_id)
          AND class_date <= (SELECT end_date FROM public.seasonal_schedules WHERE id = active_season_id);

        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE 'Fixed % orphaned schedule instances (assigned to season %)', updated_count, active_season_id;
    ELSE
        RAISE NOTICE 'No active seasonal schedule found - cannot fix orphaned instances';
    END IF;
END $$;

-- ========================================
-- FIX 2: Update get_class_schedule_with_enrollments to use LEFT JOIN
-- so it works even if seasonal_schedule_id is NULL
-- ========================================

CREATE OR REPLACE FUNCTION public.get_class_schedule_with_enrollments(target_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', si.id,
            'discipline', si.discipline,
            'disciplineDisplayName',
                CASE si.discipline
                    WHEN 'bjj' THEN 'BJJ'
                    WHEN 'mma' THEN 'MMA'
                    WHEN 'sambo' THEN 'Sambo'
                    WHEN 'grappling' THEN 'Grappling'
                    WHEN 'fitness' THEN 'Prep. Atletica'
                    ELSE UPPER(si.discipline::text)
                END,
            'instructor_name', COALESCE(up.full_name, 'Istruttore Disponibile'),
            'instructor_email', COALESCE(up.email, ''),
            'instructor_bio', 'Istruttore esperto con anni di esperienza',
            'time_range', si.start_time::text || ' - ' || si.end_time::text,
            'date_formatted', TO_CHAR(si.class_date, 'DD/MM/YYYY'),
            'capacity', si.max_capacity,
            'enrolled', COALESCE(enrolled_count.count, 0),
            'is_booked', COALESCE(user_registered.is_registered, false),
            'waitlist_position', NULL,
            'description', COALESCE(wst.notes, 'Allenamento di ' ||
                CASE si.discipline
                    WHEN 'bjj' THEN 'Brazilian Jiu-Jitsu'
                    WHEN 'mma' THEN 'Mixed Martial Arts'
                    WHEN 'sambo' THEN 'Sambo'
                    WHEN 'grappling' THEN 'Grappling'
                    WHEN 'fitness' THEN 'Preparazione Atletica'
                    ELSE si.discipline::text
                END),
            'location', si.location,
            'start_time', si.start_time::text,
            'end_time', si.end_time::text,
            'class_date', si.class_date::text,
            'is_cancelled', si.is_cancelled,
            'cancellation_reason', si.cancellation_reason,
            'is_holiday_affected', si.is_holiday_affected,
            'updated_at', TO_CHAR(si.updated_at, 'YYYY-MM-DD HH24:MI:SS'),
            'created_at', TO_CHAR(si.created_at, 'YYYY-MM-DD HH24:MI:SS'),
            'is_modified', (si.updated_at > si.created_at + INTERVAL '1 minute')
        ) ORDER BY si.start_time, si.discipline
    ) INTO result
    FROM public.schedule_instances si
    LEFT JOIN public.seasonal_schedules ss ON si.seasonal_schedule_id = ss.id
    LEFT JOIN public.user_profiles up ON si.instructor_id = up.id
    LEFT JOIN public.weekly_schedule_templates wst ON si.template_id = wst.id
    LEFT JOIN (
        SELECT
            schedule_instance_id,
            COUNT(*)::integer AS count
        FROM public.class_registrations
        WHERE registration_status = 'registered'
        GROUP BY schedule_instance_id
    ) enrolled_count ON si.id = enrolled_count.schedule_instance_id
    LEFT JOIN (
        SELECT
            schedule_instance_id,
            true AS is_registered
        FROM public.class_registrations
        WHERE user_id = auth.uid()
          AND registration_status = 'registered'
    ) user_registered ON si.id = user_registered.schedule_instance_id
    WHERE si.class_date = target_date
      AND si.is_cancelled = false
      AND si.discipline IN ('bjj', 'mma', 'sambo', 'grappling', 'fitness');

    RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

-- ========================================
-- FIX 3: Booking eligibility - handle NULL expires_at
-- ========================================

DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(uuid, uuid);

CREATE OR REPLACE FUNCTION public.check_class_booking_eligibility(
    p_user_id uuid,
    p_schedule_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_payment_record RECORD;
    v_plan_name TEXT;
    v_is_doppio BOOLEAN;
    v_subscription_record RECORD;
    v_class_discipline TEXT;
    v_target_discipline TEXT;
BEGIN
    -- Dynamically get the class discipline from schedule_instances
    SELECT discipline::TEXT INTO v_class_discipline
    FROM public.schedule_instances
    WHERE id = p_schedule_instance_id;
    
    -- If schedule instance not found, deny access
    IF v_class_discipline IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'reason', 'Classe non trovata.'
        );
    END IF;
    
    -- ========================================
    -- PRIORITY 1: CHECK PAYMENT CONFIRMATIONS
    -- FIX: Handle NULL expires_at (treat as never-expiring)
    -- ========================================
    
    FOR v_payment_record IN 
        SELECT 
            pc.target_discipline,
            sp.name AS plan_name
        FROM public.payment_confirmations pc
        LEFT JOIN public.subscription_plans sp ON pc.subscription_plan_id = sp.id
        WHERE pc.user_id = p_user_id
        AND pc.status IN ('confirmed', 'paid')
        AND (pc.expires_at IS NULL OR pc.expires_at > NOW())
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_name := COALESCE(v_payment_record.plan_name, '');
        v_target_discipline := COALESCE(v_payment_record.target_discipline, '');
        
        -- Check if it's a Corso Doppio plan
        v_is_doppio := public.is_corso_doppio_plan(v_plan_name);
        
        -- Rule 1: Grappling is accessible to everyone with valid payment
        IF v_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed', TRUE,
                'reason', NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;
        
        -- Rule 2: PRIMARY CHECK - Direct target_discipline match
        IF v_target_discipline = v_class_discipline THEN
            RETURN jsonb_build_object(
                'allowed', TRUE,
                'reason', NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;
        
        -- Rule 3: Preparazione Atletica check via plan name
        IF v_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 4: Corso Doppio gives access to MMA, BJJ, Sambo, and Grappling
        IF v_is_doppio THEN
            IF v_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 5: target_discipline='MMA' gives access to MMA and Grappling
        IF UPPER(v_target_discipline) = 'MMA' THEN
            IF v_class_discipline IN ('mma', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 6: target_discipline='BJJ' gives access to BJJ and Grappling
        IF UPPER(v_target_discipline) = 'BJJ' THEN
            IF v_class_discipline IN ('bjj', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 7: target_discipline='Sambo' gives access to Sambo and Grappling
        IF v_target_discipline = 'Sambo' THEN
            IF v_class_discipline IN ('sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
    END LOOP;
    
    -- ========================================
    -- PRIORITY 2: CHECK ENTRY-BASED SUBSCRIPTIONS
    -- Returns subscription_id for direct use in booking
    -- ========================================
    
    FOR v_subscription_record IN 
        SELECT 
            us.id AS subscription_id,
            us.entries_remaining,
            sp.plan_type,
            sp.name AS plan_name
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
        AND us.is_active = true
        AND sp.plan_type IN ('single_entry', 'multi_entry')
        AND (us.expires_at IS NULL OR us.expires_at > NOW())
        AND us.entries_remaining > 0
        ORDER BY us.created_at DESC
        LIMIT 1
    LOOP
        -- Entry-based subscriptions allow ANY discipline
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'reason', NULL,
            'entries_remaining', v_subscription_record.entries_remaining,
            'plan_type', v_subscription_record.plan_type,
            'booking_type', 'entry_based',
            'subscription_id', v_subscription_record.subscription_id::TEXT
        );
    END LOOP;
    
    -- No valid subscription found
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason', 'Accesso negato: la tua iscrizione non include questa disciplina o è scaduta.'
    );
END;
$function$;
