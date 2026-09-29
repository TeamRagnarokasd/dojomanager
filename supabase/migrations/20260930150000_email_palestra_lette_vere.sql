-- "Email Palestra": "letta/non letta" deve rispecchiare lo stato VERO della
-- casella email su Aruba (flag IMAP \Seen), uguale per tutti gli admin e
-- coerente con quello che si vede aprendo la webmail vera — non più una
-- lettura "personale" registrata solo quando un admin tocca l'email dentro
-- l'app.
--
-- mailbox_message_reads e mailbox_mark_read NON vengono toccate né
-- cancellate (per non rischiare nulla): restano nel database, semplicemente
-- l'app smette di usarle per questo scopo.
--
-- NON APPLICATA: solo scritta, come richiesto.
-- Idempotente: rieseguibile senza errori (ADD COLUMN IF NOT EXISTS, CREATE
-- OR REPLACE FUNCTION).

ALTER TABLE public.mailbox_messages
  ADD COLUMN IF NOT EXISTS is_unread boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.mailbox_unread_count()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN public.is_admin_from_auth() THEN (
    SELECT count(*)::integer
    FROM public.mailbox_messages
    WHERE is_unread = true
  ) ELSE 0 END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_unread_count() TO authenticated;
