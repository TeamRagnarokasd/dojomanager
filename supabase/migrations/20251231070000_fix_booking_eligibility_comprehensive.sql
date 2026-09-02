-- Location: supabase/migrations/20251231070000_fix_booking_eligibility_comprehensive.sql
-- Schema Analysis: Existing payment_confirmations, user_subscriptions, subscription_plans, schedule_instances tables
-- Integration Type: Fix booking eligibility logic to handle both single purchases and subscriptions
-- Dependencies: payment_confirmations, user_subscriptions, subscription_plans, schedule_instances

-- 🔥 CRITICAL FIX: Comprehensive booking eligibility check for both single purchases and subscriptions

-- Drop existing broken function
DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(UUID, UUID);

-- Create comprehensive eligibility check function
CREATE OR REPLACE FUNCTION public.check_class_booking_eligibility(
    p_schedule_instance_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    v_discipline TEXT;
    v_has_valid_single_purchase BOOLEAN := false;
    v_has_valid_subscription BOOLEAN := false;
    v_subscription_count INTEGER := 0;
    v_single_purchase_count INTEGER := 0;
BEGIN
    -- Get discipline from the class instance
    SELECT discipline::TEXT INTO v_discipline 
    FROM public.schedule_instances 
    WHERE id = p_schedule_instance_id;

    IF v_discipline IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'Classe non trovata o disciplina non valida'
        );
    END IF;

    -- 🔥 CHECK 1: Single entry purchases (payment_confirmations with target_discipline)
    -- This handles "corsi singoli" purchases where user selected a specific discipline
    SELECT COUNT(*) INTO v_single_purchase_count
    FROM public.payment_confirmations pc
    WHERE pc.user_id = p_user_id
      AND pc.status = 'confirmed'
      AND LOWER(COALESCE(pc.target_discipline, '')) = LOWER(v_discipline)
      AND (pc.expires_at IS NULL OR pc.expires_at > CURRENT_TIMESTAMP);

    v_has_valid_single_purchase := (v_single_purchase_count > 0);

    -- 🔥 CHECK 2: Active subscriptions with remaining entries
    -- First, get valid subscription IDs that have remaining entries
    WITH valid_subscriptions AS (
        SELECT us.id
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND us.entries_remaining > 0
          AND (us.expires_at IS NULL OR us.expires_at > CURRENT_TIMESTAMP)
    )
    SELECT COUNT(*) INTO v_subscription_count
    FROM valid_subscriptions;

    v_has_valid_subscription := (v_subscription_count > 0);

    -- 🔥 DECISION LOGIC: Allow booking if EITHER condition is true
    IF v_has_valid_single_purchase OR v_has_valid_subscription THEN
        RETURN jsonb_build_object(
            'allowed', true,
            'reason', 'Abbonamento valido o acquisto singolo confermato'
        );
    ELSE
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'Nessun abbonamento valido o acquisto per questa disciplina. Acquista un abbonamento per prenotare.'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return safe failure
        RAISE NOTICE 'Error in check_class_booking_eligibility: %', SQLERRM;
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'Errore durante la verifica dell''idoneità alla prenotazione'
        );
END;
$func$;

-- Add comment explaining the function
COMMENT ON FUNCTION public.check_class_booking_eligibility(UUID, UUID) IS 
'Comprehensive booking eligibility check that handles both:
1. Single-entry purchases (payment_confirmations with target_discipline)
2. Active subscriptions (user_subscriptions with remaining entries)
Returns JSON: {allowed: boolean, reason: string}';