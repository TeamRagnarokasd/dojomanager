-- Anti-doppio-invio sulla creazione manuale di ricevute/pagamenti
-- (manual_receipt_creation_dialog.dart, italian_receipt_generation.dart).
--
-- Il fix vero è lato app (bottone disabilitato durante l'invio); questo
-- trigger è solo la rete di sicurezza indipendente lato database.
--
-- Perché su non_fiscal_receipts e non su payment_confirmations (come
-- proposto inizialmente): ogni tocco sul bottone "Crea Ricevuta" chiama
-- ItalianReceiptService.createManualReceipt() ESATTAMENTE UNA VOLTA, che fa
-- UN SOLO insert in non_fiscal_receipts — quindi un doppio tocco produce
-- sempre due righe distinte qui, con created_by/customer_name/description/
-- amount identici a pochi istanti di distanza: un bersaglio pulito.
-- payment_confirmations invece non lo è: una singola creazione riuscita
-- (via italian_receipt_generation.dart, che oltre alla ricevuta attiva
-- anche l'abbonamento) inserisce LEGITTIMAMENTE più righe con lo stesso
-- user_id e lo stesso amount nello stesso istante quando il piano include
-- una seconda disciplina o la preparazione atletica (batch_transaction_id
-- con suffisso _D2 / _PREP) — un vincolo lì avrebbe rischiato di bloccare
-- queste attivazioni legittime. Il batch_transaction_id di ogni riga di
-- payment_confirmations creata da questo flusso deriva comunque dalla
-- stessa riga di non_fiscal_receipts, quindi bloccare qui a monte impedisce
-- anche i pagamenti duplicati a valle, senza quel rischio.
--
-- Anche una finestra fissa per secondo (date_trunc('second', created_at))
-- è stata scartata: due tocchi rapidi a cavallo di un cambio di secondo
-- (es. .995s e .005s del secondo dopo, ~10ms di distanza reale) non
-- verrebbero riconosciuti come duplicati. Il trigger sotto usa invece una
-- vera finestra scorrevole di 5 secondi sul timestamp reale, che non ha
-- questo problema e resta ampiamente sotto il tempo che serve per compilare
-- a mano una ricevuta per un cliente diverso.
--
-- Idempotente: rieseguibile senza errori (CREATE OR REPLACE FUNCTION, DROP
-- TRIGGER IF EXISTS + CREATE TRIGGER).
--
-- NON APPLICATA: solo scritta, come richiesto.

CREATE OR REPLACE FUNCTION public.prevent_duplicate_manual_receipt()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recent_duplicate boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.non_fiscal_receipts r
        WHERE r.id <> NEW.id
          AND r.batch_transaction_id LIKE 'MANUAL_RECEIPT_%'
          AND r.created_by IS NOT DISTINCT FROM NEW.created_by
          AND r.customer_name IS NOT DISTINCT FROM NEW.customer_name
          AND r.description IS NOT DISTINCT FROM NEW.description
          AND r.amount = NEW.amount
          AND r.created_at BETWEEN NEW.created_at - interval '5 seconds'
                                AND NEW.created_at + interval '5 seconds'
    ) INTO v_recent_duplicate;

    IF v_recent_duplicate THEN
        RAISE EXCEPTION 'Ricevuta già creata pochi istanti fa per lo stesso cliente, descrizione e importo: probabile doppio invio, controlla l''archivio prima di riprovare.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_manual_receipt
    ON public.non_fiscal_receipts;

CREATE TRIGGER trg_prevent_duplicate_manual_receipt
    BEFORE INSERT ON public.non_fiscal_receipts
    FOR EACH ROW
    WHEN (NEW.batch_transaction_id LIKE 'MANUAL_RECEIPT_%')
    EXECUTE FUNCTION public.prevent_duplicate_manual_receipt();
