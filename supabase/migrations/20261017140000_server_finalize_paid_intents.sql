-- Attivazione automatica dei pagamenti SumUp/Satispay lato server — PASSO 1.
--
-- Tutto nasce SPENTO: con app_feature_flags.server_finalize = false il job
-- 'paid-intents-tick' gira ogni minuto ma esce subito senza toccare nulla,
-- quindi il sistema si comporta esattamente come oggi (attiva solo l'app).
--
-- Spegnimento d'emergenza (uno dei due basta):
--   UPDATE public.app_feature_flags SET enabled = false, updated_at = now() WHERE key = 'server_finalize';
--   SELECT cron.unschedule('paid-intents-tick');
--
-- Non modifica nulla di esistente: generate_italian_receipt_number, trigger,
-- edge function, create-payment e testi delle ricevute restano identici.

-- ─── 1. Finalizzazione di un singolo intento pagato ──────────────────────
-- Replica, in una sola transazione, i passi che l'app esegue in
-- PaidIntentsService._processSingleIntent + SubscriptionService.createBatchPaymentAndReceipts
-- (claim_paid_intent → create_payment_confirmation → ricevuta → user_subscriptions
-- → attach_intent_confirmation). Se un trigger blocca, tutto torna com'era
-- (intento di nuovo 'matched') e il motivo finisce in payment_intents.notes:
-- alla riapertura l'app mostra il dialogo di sempre.
CREATE OR REPLACE FUNCTION public.finalize_paid_intent(p_intent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
SET "TimeZone" TO 'UTC'
AS $fn$
DECLARE
  r            public.payment_intents;
  v_paid_at    timestamptz;
  v_payer      uuid;
  v_benef      uuid;
  v_is_child   boolean;
  v_method     public.payment_method_type;
  v_method_txt text;
  v_plan_name  text;
  v_tx         text;
  v_conf_id    uuid;
  p            public.user_profiles;
  c            public.child_profiles;
  v_customer   text;
  v_tax        text;
  v_address    text;
  v_notes      text;
  v_guardian   text;
  v_minor_name text;
  v_minor_cf   text;
  v_receipt_no text;
  v_plan       public.custom_subscription_plans;
  v_rome_now   timestamp;
  v_annual     timestamp;
  v_entries    integer;
  v_expires    timestamptz;
  v_err        text;
BEGIN
  BEGIN
    -- a. Presa in carico: stesso UPDATE ... WHERE status = 'matched' di
    --    claim_paid_intent, quindi app e server non possono attivare due volte.
    UPDATE public.payment_intents
       SET status = 'confirmed', notes = COALESCE(notes, 'preso in carico dal server')
     WHERE id = p_intent_id AND status = 'matched'
     RETURNING * INTO r;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'intento non in attesa');
    END IF;
    v_paid_at := LEAST(COALESCE(r.matched_at, r.created_at + interval '1 hour'),
                       r.created_at + interval '1 hour');

    -- b. Pagante e beneficiario.
    v_payer      := r.user_id;
    v_benef      := COALESCE(r.beneficiary_profile_id, r.user_id);
    v_is_child   := v_benef <> v_payer;
    v_method_txt := lower(r.provider);
    v_method     := v_method_txt::public.payment_method_type;
    v_plan_name  := COALESCE(r.plan_name, 'Abbonamento');

    -- Dati del pagante (come refreshUserDataFromDatabase).
    SELECT * INTO p FROM public.user_profiles WHERE id = v_payer;
    v_customer := btrim(COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, ''));
    IF v_customer = '' THEN v_customer := 'Cliente'; END IF;
    v_tax := CASE
               WHEN NULLIF(btrim(p.tax_code), '') IS NOT NULL THEN p.tax_code
               WHEN NULLIF(btrim(p.codice_fiscale), '') IS NOT NULL THEN p.codice_fiscale
               ELSE COALESCE(p.tax_code, p.codice_fiscale, 'NON DISPONIBILE')
             END;
    v_address := CASE WHEN p.address_line IS NOT NULL
                      THEN concat_ws(', ', p.address_line, p.city, p.province, p.cap) END;

    IF NOT v_is_child THEN
      -- Pagante minorenne con account proprio: ricevuta al tutore (teenMinorNote).
      IF p.birth_date IS NOT NULL
         AND date_part('year', age((now() AT TIME ZONE 'Europe/Rome')::date, p.birth_date)) < 18 THEN
        v_guardian := btrim(COALESCE(p.parent_guardian_name, '') || ' ' || COALESCE(p.parent_guardian_surname, ''));
        IF v_guardian <> '' AND p.parent_guardian_codice_fiscale IS NOT NULL
           AND p.parent_guardian_codice_fiscale <> '' THEN
          v_customer   := v_guardian;
          v_tax        := p.parent_guardian_codice_fiscale;
          v_minor_name := btrim(COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, ''));
          v_minor_cf   := COALESCE(p.tax_code, p.codice_fiscale, '');
          v_notes := 'Quota relativa al minore: ' || v_minor_name
                  || CASE WHEN v_minor_cf <> '' THEN ' | Codice Fiscale: ' || v_minor_cf ELSE '' END
                  || ' | Data di nascita: ' || to_char(p.birth_date, 'YYYY-MM-DD');
        END IF;
      END IF;
    ELSE
      -- Acquisto per un figlio: ricevuta al pagante (il tutore) con buildMinorNote.
      SELECT * INTO c FROM public.child_profiles WHERE id = v_benef;
      IF FOUND THEN
        v_minor_name := COALESCE(c.full_name, btrim(COALESCE(c.first_name, '') || ' ' || COALESCE(c.last_name, '')));
        v_minor_cf   := COALESCE(c.tax_code, c.codice_fiscale, '');
        v_notes := 'Quota relativa al minore: ' || v_minor_name
                || CASE WHEN v_minor_cf <> '' THEN ' | Codice Fiscale: ' || v_minor_cf ELSE '' END
                || CASE WHEN c.birth_date IS NOT NULL
                        THEN ' | Data di nascita: ' || to_char(c.birth_date, 'YYYY-MM-DD') ELSE '' END;
      END IF;
    END IF;

    -- c. Conferma di pagamento: stesse colonne di create_payment_confirmation
    --    (che non si può chiamare da qui perché richiede auth.uid()).
    v_tx := 'TXN_' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint || '_' || v_payer;
    INSERT INTO public.payment_confirmations (
      user_id, amount, payment_method, status, confirmed_at,
      batch_transaction_id, custom_plan_id, subscription_plan_id,
      target_discipline, target_discipline_2,
      beneficiary_profile_id, beneficiary_type
    ) VALUES (
      v_payer, r.amount, v_method, 'confirmed', v_paid_at,
      v_tx, r.custom_plan_id, r.custom_plan_id,
      NULL, NULL,
      v_benef, CASE WHEN v_is_child THEN 'child' ELSE 'adult' END
    )
    RETURNING id INTO v_conf_id;

    -- d. Ricevuta non fiscale.
    v_receipt_no := public.generate_italian_receipt_number();
    INSERT INTO public.non_fiscal_receipts (
      created_by, customer_name, customer_tax_code, customer_address,
      description, amount, unit_price, quantity, payment_method, status,
      vat_rate, vat_amount, discount_percentage,
      batch_transaction_id, receipt_number, issue_date, notes
    ) VALUES (
      v_payer, v_customer, v_tax, v_address,
      v_plan_name || ' (via ' || CASE v_method_txt WHEN 'sumup' THEN 'SumUp' ELSE 'Satispay' END || ')',
      r.amount, r.amount, 1, v_method, 'issued',
      '0', 0, 0,
      v_tx, v_receipt_no, (now() AT TIME ZONE 'Europe/Rome')::date, v_notes
    );

    -- e. user_subscriptions solo per un beneficiario adulto: per un figlio
    --    l'app ci prova ma la FK su user_profiles fallisce sempre, e l'accesso
    --    arriva da payment_confirmations. Regole di scadenza dell'app; le date
    --    sono salvate come l'app: ora di Roma scritta come se fosse UTC.
    IF NOT v_is_child AND r.custom_plan_id IS NOT NULL THEN
      SELECT * INTO v_plan FROM public.custom_subscription_plans WHERE id = r.custom_plan_id;
      IF FOUND THEN
        v_entries := 0;
        v_expires := NULL;
        IF COALESCE(v_plan.is_unlimited, false) AND COALESCE(v_plan.entry_count, 0) > 0 THEN
          v_entries := v_plan.entry_count;
        ELSE
          v_rome_now := now() AT TIME ZONE 'Europe/Rome';
          IF lower(COALESCE(v_plan.name, '')) LIKE '%iscrizione%'
             OR lower(COALESCE(v_plan.name, '')) LIKE '%annuale%' THEN
            -- _computeAnnualExpiry: 28/08 di quest'anno, o del prossimo se già passato.
            v_annual := make_timestamp(extract(year FROM v_rome_now)::int, 8, 28, 0, 0, 0);
            IF v_rome_now > v_annual THEN v_annual := v_annual + interval '1 year'; END IF;
            v_expires := v_annual AT TIME ZONE 'UTC';
          ELSE
            v_expires := ((now() + make_interval(days => 30 * COALESCE(v_plan.duration_months, 1)))
                          AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'UTC';
          END IF;
        END IF;
        INSERT INTO public.user_subscriptions (
          user_id, custom_plan_id, entries_remaining, entries_total, is_active, expires_at
        ) VALUES (
          v_benef, v_plan.id, v_entries, v_entries, true, v_expires
        );
      END IF;
    END IF;

    -- f. Aggancio della conferma all'intento (attach_intent_confirmation).
    UPDATE public.payment_intents SET confirmation_id = v_conf_id WHERE id = r.id;

    RETURN jsonb_build_object(
      'ok', true, 'intent_id', r.id, 'confirmation_id', v_conf_id,
      'batch_transaction_id', v_tx, 'receipt_number', v_receipt_no
    );
  EXCEPTION WHEN OTHERS THEN
    -- Il blocco interno è stato annullato per intero: l'intento è di nuovo 'matched'.
    v_err := SQLERRM;
    UPDATE public.payment_intents
       SET notes = COALESCE(notes || ' | ', '') || 'blocco server: ' || left(v_err, 300)
     WHERE id = p_intent_id AND status = 'matched';
    RETURN jsonb_build_object('ok', false, 'intent_id', p_intent_id, 'error', v_err);
  END;
END
$fn$;

REVOKE ALL ON FUNCTION public.finalize_paid_intent(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_paid_intent(uuid) TO service_role;

-- ─── 2. Giro ogni minuto: verifica dei pagamenti aperti + finalizzazione ──
CREATE OR REPLACE FUNCTION public.paid_intents_tick()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  i           record;
  v_res       jsonb;
  v_base      constant text := 'https://knedvtdgthwriawhxwgr.supabase.co/functions/v1';
  v_checked   integer := 0;
  v_activated integer := 0;
  v_failed    integer := 0;
BEGIN
  IF NOT COALESCE((SELECT enabled FROM public.app_feature_flags WHERE key = 'server_finalize'), false) THEN
    RETURN jsonb_build_object('enabled', false);
  END IF;

  -- VERIFICA: richiama le callback esistenti (pubbliche, rileggono l'esito dal
  -- provider) solo per i pagamenti ancora aperti, entro la loro scadenza.
  FOR i IN
    SELECT id, provider, provider_payment_id
      FROM public.payment_intents
     WHERE status = 'pending'
       AND provider_payment_id IS NOT NULL
       AND created_at > now() - interval '70 minutes'
       AND ((provider = 'sumup'    AND created_at > now() - interval '45 minutes')
         OR (provider = 'satispay' AND created_at > now() - interval '60 minutes'))
  LOOP
    BEGIN
      IF i.provider = 'sumup' THEN
        PERFORM net.http_post(
          url := v_base || '/sumup/callback',
          body := '{}'::jsonb,
          params := jsonb_build_object('id', i.provider_payment_id),
          headers := jsonb_build_object('Content-Type', 'application/json'),
          timeout_milliseconds := 10000);
      ELSE
        PERFORM net.http_post(
          url := v_base || '/satispay/callback',
          body := '{}'::jsonb,
          params := jsonb_build_object('payment_id', i.provider_payment_id),
          headers := jsonb_build_object('Content-Type', 'application/json'),
          timeout_milliseconds := 10000);
      END IF;
      v_checked := v_checked + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'paid_intents_tick verifica %: %', i.id, SQLERRM;
    END;
  END LOOP;

  -- FINALIZZAZIONE: lascia all'app 3 minuti di vantaggio, al massimo un
  -- intento per pagante a giro, e salta il pagante se ha una ricevuta da meno
  -- di 70 secondi (terminator_cleanup cancellerebbe la ricevuta del fratello).
  FOR i IN
    SELECT DISTINCT ON (pi.user_id) pi.id, pi.user_id, pi.matched_at, pi.created_at
      FROM public.payment_intents pi
     WHERE pi.status = 'matched'
       AND pi.matched_at < now() - interval '3 minutes'
       AND COALESCE(pi.notes, '') NOT ILIKE '%blocco server%'
       AND NOT EXISTS (
             SELECT 1 FROM public.non_fiscal_receipts nfr
              WHERE nfr.created_by = pi.user_id
                AND nfr.created_at > now() - interval '70 seconds')
     ORDER BY pi.user_id, pi.matched_at, pi.created_at
  LOOP
    BEGIN
      v_res := public.finalize_paid_intent(i.id);
      IF COALESCE((v_res ->> 'ok')::boolean, false) THEN
        v_activated := v_activated + 1;
      ELSE
        v_failed := v_failed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
      RAISE WARNING 'paid_intents_tick finalizzazione %: %', i.id, SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object('enabled', true, 'verificati', v_checked,
                            'attivati', v_activated, 'non_attivati', v_failed);
END
$fn$;

REVOKE ALL ON FUNCTION public.paid_intents_tick() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.paid_intents_tick() TO service_role;

-- ─── 3. Interruttore, spento ─────────────────────────────────────────────
INSERT INTO public.app_feature_flags (key, enabled) VALUES ('server_finalize', false)
ON CONFLICT DO NOTHING;

-- ─── 4. Job ogni minuto (con l'interruttore spento esce subito) ─────────
SELECT cron.schedule('paid-intents-tick', '* * * * *', 'SELECT public.paid_intents_tick()');
