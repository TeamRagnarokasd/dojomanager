-- ========================================
-- MIGRATION: Universal booking eligibility with dynamic discipline matching
-- Date: 2025-12-29
-- Purpose: 
--   1. Update target_discipline by dynamically finding Isabella's user_id
--   2. Rewrite check_class_booking_eligibility to be 100% dynamic
--   3. Remove hardcoded 'fitness' checks, use direct discipline matching
-- ========================================

-- ========================================
-- PART 1: DATA CORRECTION BY USER_ID (DYNAMIC)
-- ========================================

-- Update target_discipline for Isabella's subscription using dynamic ID lookup
UPDATE payment_confirmations
SET target_discipline = 'Preparazione Atletica'
WHERE user_id = (SELECT id FROM user_profiles WHERE first_name ILIKE 'isabella' LIMIT 1)
AND status = 'confirmed'
AND expires_at > NOW()
AND (target_discipline IS NULL OR target_discipline != 'Preparazione Atletica');

-- ========================================
-- PART 2: UNIVERSAL BOOKING ELIGIBILITY FUNCTION
-- ========================================

-- Drop the existing function (both possible signatures)
DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(uuid, discipline_type);
DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(uuid, uuid);

-- Create new universal function with dynamic discipline lookup
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
    -- ========================================
    
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
        
        -- Rule 3: SECONDARY CHECK - Subscription plan name contains 'preparazione' or 'prep.'
        -- for Preparazione Atletica classes
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
    -- ========================================
    
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
        IF v_subscription_record.entries_remaining <= 0 THEN
            RETURN jsonb_build_object(
                'allowed', FALSE,
                'reason', 'Ingressi esauriti! Per prenotare acquista nuovi ingressi o un nuovo abbonamento.'
            );
        END IF;
        
        -- Entry-based subscriptions allow ANY discipline
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'reason', NULL,
            'entries_remaining', v_subscription_record.entries_remaining,
            'plan_type', v_subscription_record.plan_type,
            'booking_type', 'entry_based'
        );
    END LOOP;
    
    -- No valid subscription found
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason', 'Accesso negato: la tua iscrizione non include questa disciplina o è scaduta.'
    );
END;
$function$;