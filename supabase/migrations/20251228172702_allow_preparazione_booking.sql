-- Migration: Allow users with "Preparazione Atletica" subscriptions to book Prep. Atletica classes
-- Description: Extends check_class_booking_eligibility to permit booking of Prep. Atletica classes
--              for users with subscriptions containing "preparazione" or "prep." in the plan name

-- Drop and recreate the check_class_booking_eligibility function with updated logic
DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(uuid, discipline_type);

CREATE OR REPLACE FUNCTION public.check_class_booking_eligibility(p_user_id uuid, p_class_discipline discipline_type)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_payment_record RECORD;
    v_plan_name TEXT;
    v_is_doppio BOOLEAN;
    v_subscription_record RECORD;
    v_has_monthly_for_discipline BOOLEAN := FALSE;
BEGIN
    -- ========================================
    -- PRIORITY 1: CHECK PAYMENT CONFIRMATIONS (Monthly subscriptions for specific disciplines)
    -- CRITICAL: Monthly subscriptions take priority over entry-based for their specific disciplines
    -- ========================================
    
    -- Get user's valid payment confirmations
    FOR v_payment_record IN 
        SELECT 
            pc.target_discipline,
            sp.name AS plan_name
        FROM public.payment_confirmations pc
        LEFT JOIN public.subscription_plans sp ON pc.subscription_plan_id = sp.id
        WHERE pc.user_id = p_user_id
        AND pc.status IN ('confirmed', 'paid')
        AND pc.expires_at > NOW()
        ORDER BY pc.created_at DESC
    LOOP
        -- Get plan name (handle NULL for plans without subscription_plan_id)
        v_plan_name := COALESCE(v_payment_record.plan_name, '');
        
        -- Check if it's a Corso Doppio plan
        v_is_doppio := public.is_corso_doppio_plan(v_plan_name);
        
        -- Rule 1: Grappling is accessible to everyone with valid payment
        IF p_class_discipline = 'grappling' THEN
            v_has_monthly_for_discipline := TRUE;
            RETURN jsonb_build_object(
                'allowed', TRUE,
                'reason', NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;
        
        -- NEW RULE: Prep. Atletica is accessible to users with subscriptions containing "preparazione" or "prep."
        -- Check case-insensitive match for keywords in plan name
        IF p_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                v_has_monthly_for_discipline := TRUE;
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 2: Corso Doppio gives access to MMA, BJJ, Sambo, and Grappling
        IF v_is_doppio THEN
            IF p_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                v_has_monthly_for_discipline := TRUE;
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 3: target_discipline='mma' gives access to MMA and Grappling
        IF v_payment_record.target_discipline = 'mma' THEN
            IF p_class_discipline IN ('mma', 'grappling') THEN
                v_has_monthly_for_discipline := TRUE;
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
        
        -- Rule 4: target_discipline='bjj' gives access to BJJ and Grappling
        IF v_payment_record.target_discipline = 'bjj' THEN
            IF p_class_discipline IN ('bjj', 'grappling') THEN
                v_has_monthly_for_discipline := TRUE;
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
    END LOOP;
    
    -- ========================================
    -- PRIORITY 2: CHECK ENTRY-BASED SUBSCRIPTIONS (Ingresso Singolo, Pacchetto 10 Ingressi)
    -- ONLY if no monthly subscription covers the requested discipline
    -- ========================================
    
    -- If we reach here, no monthly subscription covers this discipline
    -- Check for active entry-based subscriptions (single_entry or multi_entry)
    FOR v_subscription_record IN 
        SELECT 
            us.entries_remaining,
            sp.plan_type,
            sp.name AS plan_name
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
        AND us.is_active = true
        AND sp.plan_type IN ('single_entry', 'multi_entry')
        AND (us.expires_at IS NULL OR us.expires_at > NOW())
        ORDER BY us.created_at DESC
        LIMIT 1
    LOOP
        -- Check if entries are exhausted
        IF v_subscription_record.entries_remaining <= 0 THEN
            RETURN jsonb_build_object(
                'allowed', FALSE,
                'reason', 'Ingressi esauriti! Per prenotare acquista nuovi ingressi o un nuovo abbonamento.'
            );
        END IF;
        
        -- Entry-based subscriptions allow ANY discipline (universal booking)
        -- This is only reached when no monthly subscription covers the discipline
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'reason', NULL,
            'entries_remaining', v_subscription_record.entries_remaining,
            'plan_type', v_subscription_record.plan_type,
            'booking_type', 'entry_based'
        );
    END LOOP;
    
    -- If no matching payment or subscription found, deny access
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason', 'Accesso negato: la tua iscrizione non include questa disciplina o è scaduta.'
    );
END;
$function$;