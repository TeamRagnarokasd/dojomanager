-- Migration: Fix entry-based credit countdown
--
-- Problem 1: register_for_class passes WRONG params to use_subscription_entry.
--   It calls use_subscription_entry(user_uuid, subscription_id) but
--   use_subscription_entry expects (user_subscription_uuid, class_type, notes).
--   So the user's UUID goes where the subscription ID should be → entry never decremented.
--
-- Problem 2: register_for_class doesn't return entries_remaining after booking,
--   so the app can't display a countdown.
--
-- Problem 3: cancel_class_registration doesn't refund the entry when cancelling
--   an entry-based booking.
--
-- This migration rewrites register_for_class, cancel_class_registration, and
-- use_subscription_entry to work together properly.

-- ========================================
-- FIX 1: Rewrite use_subscription_entry to accept 1 UUID param
-- (the subscription ID) and derive user from auth.uid()
-- ========================================

DROP FUNCTION IF EXISTS public.use_subscription_entry(uuid, text, text);

CREATE OR REPLACE FUNCTION public.use_subscription_entry(
    p_subscription_id UUID,
    class_type_param TEXT DEFAULT NULL,
    notes_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    current_entries INTEGER;
    sub_user_id UUID;
BEGIN
    SELECT entries_remaining, user_id INTO current_entries, sub_user_id
    FROM public.user_subscriptions
    WHERE id = p_subscription_id
    AND is_active = true;

    IF current_entries IS NULL OR current_entries <= 0 THEN
        RETURN false;
    END IF;

    UPDATE public.user_subscriptions
    SET entries_remaining = entries_remaining - 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_subscription_id;

    INSERT INTO public.subscription_entry_usage (
        user_subscription_id,
        user_id,
        class_type,
        notes
    ) VALUES (
        p_subscription_id,
        sub_user_id,
        class_type_param,
        notes_param
    );

    IF current_entries - 1 <= 0 THEN
        UPDATE public.user_subscriptions
        SET is_active = false,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_subscription_id;
    END IF;

    RETURN true;
END;
$func$;

-- ========================================
-- FIX 2: Rewrite register_for_class with correct entry deduction
-- and return entries_remaining in the response
-- ========================================

DROP FUNCTION IF EXISTS public.register_for_class(UUID, UUID);

CREATE OR REPLACE FUNCTION public.register_for_class(
    instance_id UUID,
    subscription_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_enrollment INTEGER;
    max_cap INTEGER;
    user_uuid UUID;
    v_discipline TEXT;
    v_entries_remaining INTEGER;
    v_entry_deducted BOOLEAN := false;
BEGIN
    user_uuid := auth.uid();
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Check if already registered
    IF EXISTS(
        SELECT 1 FROM public.class_registrations
        WHERE user_id = user_uuid
        AND schedule_instance_id = instance_id
        AND registration_status = 'registered'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Already registered for this class');
    END IF;

    -- Get class info
    SELECT si.max_capacity, si.discipline::TEXT, COALESCE(ec.cnt, 0)
    INTO max_cap, v_discipline, current_enrollment
    FROM public.schedule_instances si
    LEFT JOIN (
        SELECT schedule_instance_id, COUNT(*)::INTEGER AS cnt
        FROM public.class_registrations
        WHERE registration_status = 'registered'
        GROUP BY schedule_instance_id
    ) ec ON si.id = ec.schedule_instance_id
    WHERE si.id = instance_id;

    IF max_cap IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Class not found');
    END IF;

    IF current_enrollment >= max_cap THEN
        RETURN jsonb_build_object('success', false, 'error', 'Class is full');
    END IF;

    -- Deduct entry BEFORE registering (so we fail early if no entries left)
    IF subscription_id IS NOT NULL THEN
        v_entry_deducted := public.use_subscription_entry(
            subscription_id,
            v_discipline,
            'Prenotazione classe'
        );

        IF NOT v_entry_deducted THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Nessun ingresso rimanente nella sottoscrizione'
            );
        END IF;

        SELECT entries_remaining INTO v_entries_remaining
        FROM public.user_subscriptions
        WHERE id = subscription_id;
    END IF;

    -- Register user
    INSERT INTO public.class_registrations (
        user_id,
        schedule_instance_id,
        user_subscription_id,
        registration_status
    ) VALUES (
        user_uuid,
        instance_id,
        subscription_id,
        'registered'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully registered for class',
        'entries_remaining', v_entries_remaining,
        'entry_deducted', v_entry_deducted
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ========================================
-- FIX 3: Rewrite cancel_class_registration to refund
-- the entry when cancelling an entry-based booking
-- ========================================

DROP FUNCTION IF EXISTS public.cancel_class_registration(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.cancel_class_registration(
    instance_id UUID,
    cancellation_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    user_uuid UUID;
    registration_record RECORD;
    v_entries_remaining INTEGER;
BEGIN
    user_uuid := auth.uid();
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    SELECT * INTO registration_record
    FROM public.class_registrations
    WHERE user_id = user_uuid
    AND schedule_instance_id = instance_id
    AND registration_status = 'registered'
    LIMIT 1;

    IF registration_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active registration found');
    END IF;

    -- Cancel the registration
    UPDATE public.class_registrations
    SET registration_status = 'cancelled',
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = COALESCE(cancel_class_registration.cancellation_reason, 'Cancelled by user'),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.id;

    -- Refund entry if booking used an entry-based subscription
    IF registration_record.user_subscription_id IS NOT NULL THEN
        UPDATE public.user_subscriptions
        SET entries_remaining = entries_remaining + 1,
            is_active = true,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = registration_record.user_subscription_id;

        SELECT entries_remaining INTO v_entries_remaining
        FROM public.user_subscriptions
        WHERE id = registration_record.user_subscription_id;

        -- Log the refund
        INSERT INTO public.subscription_entry_usage (
            user_subscription_id,
            user_id,
            class_type,
            notes
        ) VALUES (
            registration_record.user_subscription_id,
            user_uuid,
            'refund',
            'Ingresso rimborsato per cancellazione prenotazione'
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Registration cancelled and entry refunded',
            'entry_refunded', true,
            'entries_remaining', v_entries_remaining
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration cancelled successfully',
        'entry_refunded', false
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;
