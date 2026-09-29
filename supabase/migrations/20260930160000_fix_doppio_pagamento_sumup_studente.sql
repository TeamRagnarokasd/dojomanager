-- Bug: il pagamento SumUp fatto dall'ALLIEVO stesso (self-service, non
-- creato da un admin) può creare più righe payment_confirmations
-- 'confirmed' per un solo vero addebito.
--
-- Causa reale (vedi PR): PaidIntentsService/SubscriptionService, quando la
-- conferma fallisce DOPO che la riga payment_confirmations è già stata
-- inserita con successo (es. un insert riuscito lato database ma la cui
-- risposta di rete non arriva mai al telefono, o un passo successivo come
-- l'inserimento della ricevuta che fallisce), rilasciano l'intento
-- (release_paid_intent lo riporta a 'matched') così che un tentativo
-- successivo — al prossimo resume dell'app, o al prossimo giro di polling —
-- possa riprovare. Quel retry però rigenera da zero un nuovo
-- batch_transaction_id e crea una NUOVA riga payment_confirmations, senza
-- mai controllare prima se una conferma per lo stesso acquisto esiste già.
-- Il fix vero è lato app: prima di riprovare, si controlla se esiste già
-- una conferma recente per lo stesso beneficiario/importo/piano, ed eventuali
-- errori del database vengono distinti da un vero "va riprovato da zero".
--
-- Questo trigger è la rete di sicurezza indipendente lato database, per il
-- solo percorso self-service (batch_transaction_id 'TXN_%', generato da
-- SubscriptionService.createBatchPaymentAndReceipts — diverso dal prefisso
-- 'MANUAL_RECEIPT_%' delle ricevute create a mano da un admin, già protetto
-- da un trigger separato su non_fiscal_receipts, vedi
-- 20260929120000_fix_manual_payment_double_submit.sql). Usa
-- COALESCE(beneficiary_profile_id, user_id) invece del solo user_id, per
-- restare coerente con la stessa correzione già fatta altrove in questo
-- database (payment_confirmations_server_checks / prenotazioni lezioni), dato
-- che per gli acquisti a favore di un profilo bambino user_id è sempre
-- l'adulto pagante, non il beneficiario reale.
--
-- Una finestra scorrevole di 3 minuti (non un troncamento a intervalli
-- fissi) evita l'artefatto dei bordi già discusso nel trigger di riferimento
-- sopra: qui basta guardare all'indietro da "adesso", perché è sempre il
-- SECONDO tentativo (il duplicato) ad attivare il blocco confrontandosi con
-- il primo, già confermato in precedenza.
--
-- Idempotente: rieseguibile senza errori (CREATE OR REPLACE FUNCTION, DROP
-- TRIGGER IF EXISTS + CREATE TRIGGER).
--
-- NON APPLICATA: solo scritta, come richiesto — la applica l'utente dopo
-- revisione.

CREATE OR REPLACE FUNCTION public.prevent_duplicate_sumup_self_service_confirmation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_beneficiary_id uuid;
    v_recent_duplicate boolean;
BEGIN
    v_beneficiary_id := COALESCE(NEW.beneficiary_profile_id, NEW.user_id);

    SELECT EXISTS (
        SELECT 1
        FROM public.payment_confirmations pc
        WHERE pc.id <> NEW.id
          AND pc.status = 'confirmed'
          AND COALESCE(pc.beneficiary_profile_id, pc.user_id) = v_beneficiary_id
          AND pc.amount = NEW.amount
          AND (
              (NEW.custom_plan_id IS NOT NULL AND pc.custom_plan_id = NEW.custom_plan_id)
              OR (
                  NEW.custom_plan_id IS NULL
                  AND NEW.subscription_plan_id IS NOT NULL
                  AND pc.subscription_plan_id = NEW.subscription_plan_id
              )
          )
          AND pc.created_at >= now() - interval '3 minutes'
    ) INTO v_recent_duplicate;

    IF v_recent_duplicate THEN
        RAISE EXCEPTION 'Pagamento già confermato pochi minuti fa per lo stesso acquisto: probabile doppio tentativo, nessuna nuova conferma creata.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_sumup_self_service_confirmation
    ON public.payment_confirmations;

CREATE TRIGGER trg_prevent_duplicate_sumup_self_service_confirmation
    BEFORE INSERT ON public.payment_confirmations
    FOR EACH ROW
    WHEN (
        NEW.status = 'confirmed'
        AND NEW.payment_method = 'sumup'::public.payment_method_type
        AND NEW.batch_transaction_id LIKE 'TXN_%'
    )
    EXECUTE FUNCTION public.prevent_duplicate_sumup_self_service_confirmation();
