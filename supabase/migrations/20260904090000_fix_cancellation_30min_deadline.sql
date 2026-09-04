-- Fix cancellation deadline: change from 1 hour to 30 minutes before class start.
-- Also ensures 'registered' status is included (from previous migration).
-- This replaces cancel_class_registration with the corrected 30-minute window.

CREATE OR REPLACE FUNCTION public.cancel_class_registration(
    instance_id UUID,
    cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID := auth.uid();
    registration_record RECORD;
    class_datetime TIMESTAMPTZ;
    v_entries_remaining INTEGER;
BEGIN
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Find the registration (also fetch start_time for deadline check)
    -- Include ALL active statuses: 'registered', 'confirmed', 'pending'
    SELECT cr.*, si.class_date, si.discipline, si.start_time
    INTO registration_record
    FROM public.class_registrations cr
    JOIN public.schedule_instances si ON cr.schedule_instance_id = si.id
    WHERE cr.schedule_instance_id = instance_id
    AND cr.user_id = user_uuid
    AND cr.registration_status IN ('registered', 'confirmed', 'pending');

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Registration not found');
    END IF;

    -- Build the full class datetime in Europe/Rome timezone.
    -- IMPORTANT: interpret the stored date+time as Europe/Rome local time,
    -- not UTC, otherwise the deadline check fires 1-2 hours too early.
    class_datetime := (
        (registration_record.class_date::TEXT || ' ' || registration_record.start_time::TEXT)::TIMESTAMP
        AT TIME ZONE 'Europe/Rome'
    );

    -- Check if it is too late to cancel (less than 30 minutes before class start)
    IF NOW() >= (class_datetime - INTERVAL '30 minutes') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel less than 30 minutes before the class starts');
    END IF;

    -- Update registration status
    UPDATE public.class_registrations
    SET
        registration_status = 'cancelled'::public.registration_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = cancel_class_registration.cancellation_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.id;

    -- Refund entry if booking used an entry-based subscription
    IF registration_record.user_subscription_id IS NOT NULL THEN
        UPDATE public.user_subscriptions
        SET entries_remaining = entries_remaining + 1,
            is_active = true,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = registration_record.user_subscription_id
        AND user_id = user_uuid;

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
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cancellation failed: ' || SQLERRM
        );
END;
$$;
