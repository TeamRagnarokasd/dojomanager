-- ============================================================================
-- Prenotazione lezioni: registra davvero il profilo figlio attivo, non
-- sempre l'account del genitore.
--
-- class_registrations.user_id ha un vincolo di chiave esterna verso
-- public.user_profiles(id) e va lasciato SEMPRE uguale all'adulto autenticato
-- (auth.uid()): è lì che restano agganciati abbonamento/crediti (nessuna
-- modifica alla logica di business), ed è l'unico modo per rispettare il
-- vincolo, dato che i profili figlio vivono in child_profiles, una tabella
-- separata da user_profiles.
--
-- Per sapere CHI si è davvero prenotato (l'adulto per sé stesso o uno dei
-- suoi figli) si usa una colonna separata, senza vincolo di chiave esterna
-- (può contenere sia un id di user_profiles sia uno di child_profiles) —
-- stesso pattern già usato in payment_confirmations.beneficiary_profile_id.
--
-- Nota: NON applicata — va eseguita manualmente.
-- ============================================================================

-- 1) Nuova colonna, senza FK.
ALTER TABLE public.class_registrations
  ADD COLUMN IF NOT EXISTS beneficiary_profile_id uuid;

-- 2) Backfill: le righe esistenti sono tutte prenotazioni fatte dall'adulto
--    per sé stesso (il bug che correggiamo impediva di registrare i figli).
UPDATE public.class_registrations
SET beneficiary_profile_id = user_id
WHERE beneficiary_profile_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_class_registrations_beneficiary
  ON public.class_registrations (beneficiary_profile_id);

-- 3) Il vincolo di unicità passa da (lezione, adulto) a (lezione,
--    beneficiario effettivo), così due figli dello stesso genitore possono
--    prenotare la stessa lezione (oggi impossibile: la seconda prenotazione
--    fallirebbe perché user_id, l'adulto, è lo stesso per entrambi).
ALTER TABLE public.class_registrations
  DROP CONSTRAINT IF EXISTS class_registrations_schedule_instance_id_user_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_class_registrations_instance_beneficiary
  ON public.class_registrations (
    schedule_instance_id,
    COALESCE(beneficiary_profile_id, user_id)
  );

-- ============================================================================
-- 4) register_for_class: nuovo parametro p_beneficiary_profile_id.
--    Scalo crediti/abbonamento e vincolo "già prenotato" restano sull'adulto
--    autenticato (auth.uid(), subscription_id) — invariato. Se
--    p_beneficiary_profile_id non è passato, vale l'adulto stesso, così il
--    comportamento per chi non seleziona un profilo figlio resta identico.
-- ============================================================================
DROP FUNCTION IF EXISTS public.register_for_class(uuid, uuid);

CREATE OR REPLACE FUNCTION public.register_for_class(
    instance_id UUID,
    subscription_id UUID DEFAULT NULL,
    p_beneficiary_profile_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_enrollment INTEGER;
    max_cap INTEGER;
    user_uuid UUID;
    v_beneficiary UUID;
    v_discipline TEXT;
    v_entries_remaining INTEGER;
    v_entry_deducted BOOLEAN := false;
BEGIN
    user_uuid := auth.uid();
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    v_beneficiary := COALESCE(p_beneficiary_profile_id, user_uuid);

    -- Check if already registered — per beneficiario effettivo, non per
    -- adulto: così due figli dello stesso genitore possono prenotare la
    -- stessa lezione.
    IF EXISTS(
        SELECT 1 FROM public.class_registrations
        WHERE COALESCE(beneficiary_profile_id, user_id) = v_beneficiary
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

    -- Deduct entry BEFORE registering (so we fail early if no entries left).
    -- Invariato: il credito resta sull'abbonamento dell'adulto autenticato.
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

    -- Register: user_id resta l'adulto autenticato (vincolo di FK e scalo
    -- crediti), beneficiary_profile_id è chi si sta davvero prenotando.
    INSERT INTO public.class_registrations (
        user_id,
        beneficiary_profile_id,
        schedule_instance_id,
        user_subscription_id,
        registration_status
    ) VALUES (
        user_uuid,
        v_beneficiary,
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

-- ============================================================================
-- 5) cancel_class_registration: nuovo parametro p_beneficiary_profile_id,
--    per trovare la riga giusta da cancellare anche quando l'adulto ha più
--    figli prenotati sulla stessa lezione. Invariato tutto il resto
--    (finestra dei 30 minuti, rimborso credito sull'adulto autenticato).
-- ============================================================================
DROP FUNCTION IF EXISTS public.cancel_class_registration(uuid, text);

CREATE OR REPLACE FUNCTION public.cancel_class_registration(
    instance_id UUID,
    cancellation_reason TEXT DEFAULT NULL,
    p_beneficiary_profile_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID := auth.uid();
    v_beneficiary UUID;
    registration_record RECORD;
    class_datetime TIMESTAMPTZ;
    v_entries_remaining INTEGER;
BEGIN
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    v_beneficiary := COALESCE(p_beneficiary_profile_id, user_uuid);

    -- Find the registration (also fetch start_time for deadline check).
    -- Include ALL active statuses: 'registered', 'confirmed', 'pending'.
    -- Matchata per beneficiario effettivo, non solo per adulto: così se
    -- l'adulto ha più figli prenotati sulla stessa lezione si cancella la
    -- riga giusta.
    SELECT cr.*, si.class_date, si.discipline, si.start_time
    INTO registration_record
    FROM public.class_registrations cr
    JOIN public.schedule_instances si ON cr.schedule_instance_id = si.id
    WHERE cr.schedule_instance_id = instance_id
    AND cr.user_id = user_uuid
    AND COALESCE(cr.beneficiary_profile_id, cr.user_id) = v_beneficiary
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
