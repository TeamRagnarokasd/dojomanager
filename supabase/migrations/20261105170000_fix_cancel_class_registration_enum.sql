-- Disdetta prenotazioni: la funzione cercava gli stati 'confirmed' e 'pending',
-- che non esistono nell'enum registration_status (registered, cancelled, waitlisted).
-- Ogni disdetta falliva con "invalid input value for enum". Ora cerca solo 'registered'.
-- Il resto della funzione è invariato.

CREATE OR REPLACE FUNCTION public.cancel_class_registration(instance_id uuid, cancellation_reason text DEFAULT NULL::text, p_beneficiary_profile_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    user_uuid UUID := auth.uid();
    v_beneficiary UUID;
    registration_record RECORD;
    class_datetime TIMESTAMPTZ;
    v_entries_remaining INTEGER;
BEGIN
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;
    v_beneficiary := COALESCE(p_beneficiary_profile_id, user_uuid);
    SELECT cr.*, si.class_date, si.discipline, si.start_time
    INTO registration_record
    FROM public.class_registrations cr
    JOIN public.schedule_instances si ON cr.schedule_instance_id = si.id
    WHERE cr.schedule_instance_id = instance_id
    AND cr.user_id = user_uuid
    AND COALESCE(cr.beneficiary_profile_id, cr.user_id) = v_beneficiary
    AND cr.registration_status = 'registered'::public.registration_status;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Registration not found');
    END IF;
    class_datetime := (
        (registration_record.class_date::TEXT || ' ' || registration_record.start_time::TEXT)::TIMESTAMP
        AT TIME ZONE 'Europe/Rome'
    );
    IF NOW() >= (class_datetime - INTERVAL '1 hour') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel less than 1 hour before the class starts');
    END IF;
    UPDATE public.class_registrations
    SET
        registration_status = 'cancelled'::public.registration_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = cancel_class_registration.cancellation_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.id;
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
        INSERT INTO public.subscription_entry_usage (
            user_subscription_id, user_id, class_type, notes
        ) VALUES (
            registration_record.user_subscription_id, user_uuid, 'refund',
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
        RETURN jsonb_build_object('success', false, 'error', 'Cancellation failed: ' || SQLERRM);
END;
$function$;
