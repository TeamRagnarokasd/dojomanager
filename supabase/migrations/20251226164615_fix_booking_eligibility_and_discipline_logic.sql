-- Migration: Fix booking eligibility and discipline logic
-- Purpose: Update Giulia's data and ensure proper booking rules for MMA, BJJ, and Grappling classes

-- ==========================
-- STEP 1: Ensure Giulia's payment confirmations have correct target_discipline
-- ==========================

-- Update Giulia's existing payment confirmations to ensure target_discipline is set correctly
UPDATE payment_confirmations
SET target_discipline = 'mma'::discipline_type
WHERE user_id = (
    SELECT id 
    FROM user_profiles 
    WHERE email = 'danyssj4@yahoo.it'
)
AND target_discipline IS NULL;

-- ==========================
-- STEP 2: Update function to determine if plan is "Corso Doppio"
-- ==========================

CREATE OR REPLACE FUNCTION is_corso_doppio_plan(plan_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if plan name contains "Doppio" (case-insensitive)
    RETURN LOWER(plan_name) LIKE '%doppio%';
END;
$$;

-- ==========================
-- STEP 3: Update booking eligibility validation function
-- ==========================

CREATE OR REPLACE FUNCTION check_class_booking_eligibility(
    p_user_id UUID,
    p_class_discipline discipline_type
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_record RECORD;
    v_plan_name TEXT;
    v_is_doppio BOOLEAN;
BEGIN
    -- Get user's valid payment confirmations
    FOR v_payment_record IN 
        SELECT 
            pc.target_discipline,
            sp.name AS plan_name
        FROM payment_confirmations pc
        LEFT JOIN subscription_plans sp ON pc.subscription_plan_id = sp.id
        WHERE pc.user_id = p_user_id
        AND pc.status IN ('confirmed', 'paid')
        AND pc.expires_at > NOW()
        ORDER BY pc.created_at DESC
    LOOP
        -- Get plan name (handle NULL for plans without subscription_plan_id)
        v_plan_name := COALESCE(v_payment_record.plan_name, '');
        
        -- Check if it's a Corso Doppio plan
        v_is_doppio := is_corso_doppio_plan(v_plan_name);
        
        -- Rule 1: Grappling is accessible to everyone with valid payment
        IF p_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed', TRUE,
                'reason', NULL
            );
        END IF;
        
        -- Rule 2: Corso Doppio gives access to MMA, BJJ, Sambo, and Grappling
        IF v_is_doppio THEN
            IF p_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL
                );
            END IF;
        END IF;
        
        -- Rule 3: target_discipline='mma' gives access to MMA and Grappling
        IF v_payment_record.target_discipline = 'mma' THEN
            IF p_class_discipline IN ('mma', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL
                );
            END IF;
        END IF;
        
        -- Rule 4: target_discipline='bjj' gives access to BJJ and Grappling
        IF v_payment_record.target_discipline = 'bjj' THEN
            IF p_class_discipline IN ('bjj', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed', TRUE,
                    'reason', NULL
                );
            END IF;
        END IF;
    END LOOP;
    
    -- If no matching payment found, deny access
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason', 'Accesso negato: la tua iscrizione non include questa disciplina o è scaduta.'
    );
END;
$$;

-- ==========================
-- STEP 4: Add helpful comments
-- ==========================

COMMENT ON FUNCTION check_class_booking_eligibility(UUID, discipline_type) IS 
'Validates if a user can book a specific class based on their payment confirmations and target disciplines.
Rules:
- Grappling: Accessible to all users with valid payment
- Corso Doppio: Access to MMA, BJJ, Sambo, Grappling
- target_discipline=mma: Access to MMA and Grappling
- target_discipline=bjj: Access to BJJ and Grappling
All require status=confirmed and future expires_at date';

COMMENT ON FUNCTION is_corso_doppio_plan(TEXT) IS 
'Helper function to identify "Corso Doppio" subscription plans';

-- ==========================
-- STEP 5: Verify Giulia's setup
-- ==========================

DO $$
DECLARE
    v_user_id UUID;
    v_payment_count INTEGER;
BEGIN
    -- Get Giulia's user ID
    SELECT id INTO v_user_id
    FROM user_profiles
    WHERE email = 'danyssj4@yahoo.it';
    
    IF v_user_id IS NOT NULL THEN
        -- Count her payment confirmations with target_discipline='mma'
        SELECT COUNT(*) INTO v_payment_count
        FROM payment_confirmations
        WHERE user_id = v_user_id
        AND target_discipline = 'mma'::discipline_type
        AND status = 'confirmed'
        AND expires_at > NOW();
        
        RAISE NOTICE '✅ Giulia (%) has % valid MMA payment confirmations', v_user_id, v_payment_count;
        
        -- Test her eligibility for MMA class
        IF (check_class_booking_eligibility(v_user_id, 'mma'::discipline_type))->>'allowed' = 'true' THEN
            RAISE NOTICE '✅ Giulia CAN book MMA classes';
        ELSE
            RAISE NOTICE '❌ Giulia CANNOT book MMA classes';
        END IF;
        
        -- Test her eligibility for Grappling class
        IF (check_class_booking_eligibility(v_user_id, 'grappling'::discipline_type))->>'allowed' = 'true' THEN
            RAISE NOTICE '✅ Giulia CAN book Grappling classes';
        ELSE
            RAISE NOTICE '❌ Giulia CANNOT book Grappling classes';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ User Giulia (danyssj4@yahoo.it) not found';
    END IF;
END $$;