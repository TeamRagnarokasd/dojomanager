-- "Email Palestra": il badge delle email non lette deve escludere quelle
-- eliminate dall'admin (hidden = true, colonna già esistente). L'elenco
-- stesso è già filtrato lato app (MailboxService.getMessages ora aggiunge
-- .eq('hidden', false)); qui si corregge il conteggio lato database, che
-- altrimenti continuerebbe a contare anche le email nascoste.
--
-- NON APPLICATA: solo scritta, come richiesto — la applica l'utente dopo
-- revisione.
-- Idempotente: rieseguibile senza errori (CREATE OR REPLACE FUNCTION).

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
      AND hidden = false
  ) ELSE 0 END;
$$;
