-- Fix cancellation deadline timezone bug
-- Problem: class_datetime was cast to TIMESTAMPTZ without specifying timezone,
--   so PostgreSQL interpreted the stored time as UTC instead of Europe/Rome.
--   This caused the 1-hour deadline check to fire 1-2 hours too early,
--   blocking users from cancelling even when well within the allowed window.
-- Fix: interpret class_date + start_time as Europe/Rome local time before comparing with NOW().

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
    usage_entry_id UUID;
    class_datetime TIMESTAMPTZ;
    result JSONB;
BEGIN
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Find the registration (also fetch start_time for deadline check)
    SELECT cr.*, si.class_date, si.discipline, si.start_time
    INTO registration_record
    FROM public.class_registrations cr
    JOIN public.schedule_instances si ON cr.schedule_instance_id = si.id
    WHERE cr.schedule_instance_id = instance_id
    AND cr.user_id = user_uuid
    AND cr.registration_status IN ('confirmed', 'pending');

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Registration not found');
    END IF;

    -- Build the full class datetime in Europe/Rome timezone.
    -- IMPORTANT: we must interpret the stored date+time as Europe/Rome local time,
    -- not UTC, otherwise the deadline check fires 1-2 hours too early.
    class_datetime := (
        (registration_record.class_date::TEXT || ' ' || registration_record.start_time::TEXT)::TIMESTAMP
        AT TIME ZONE 'Europe/Rome'
    );

    -- Check if it is too late to cancel (less than 1 hour before class start)
    IF NOW() >= (class_datetime - INTERVAL '1 hour') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel less than 1 hour before the class starts');
    END IF;

    -- Update registration status
    UPDATE public.class_registrations
    SET 
        registration_status = 'cancelled'::public.registration_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = cancel_class_registration.cancellation_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.id;

    -- Restore subscription entry if it was used
    IF registration_record.user_subscription_id IS NOT NULL THEN
        -- Find and remove the most recent matching usage entry
        SELECT id INTO usage_entry_id
        FROM public.subscription_entry_usage
        WHERE user_subscription_id = registration_record.user_subscription_id
        AND user_id = user_uuid
        AND used_at >= registration_record.registered_at
        AND class_type = registration_record.discipline::TEXT
        ORDER BY used_at DESC
        LIMIT 1;

        -- Delete the usage entry if found
        IF usage_entry_id IS NOT NULL THEN
            DELETE FROM public.subscription_entry_usage
            WHERE id = usage_entry_id;

            -- Restore the entry to subscription
            UPDATE public.user_subscriptions
            SET entries_remaining = entries_remaining + 1
            WHERE id = registration_record.user_subscription_id
            AND user_id = user_uuid;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration cancelled successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cancellation failed: ' || SQLERRM
        );
END;
$$;
