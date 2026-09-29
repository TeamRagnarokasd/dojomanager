-- "Email Palestra": permette all'admin di ignorare una fattura letta per
-- errore da un allegato che non era davvero una fattura (o comunque non
-- rilevante), togliendola dalla lista "Fatture da pagare" senza doverla
-- confermare.
--
-- NON APPLICATA: solo scritta, come richiesto.
-- Idempotente: rieseguibile senza errori (CREATE OR REPLACE FUNCTION).

CREATE OR REPLACE FUNCTION public.mailbox_ignore_invoice(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Funzione riservata agli amministratori.';
  END IF;

  UPDATE public.mailbox_invoices
  SET status = 'ignorata'
  WHERE id = p_invoice_id
    AND status = 'da_confermare';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fattura non trovata o già gestita.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_ignore_invoice(uuid) TO authenticated;
