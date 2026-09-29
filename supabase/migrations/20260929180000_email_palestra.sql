-- ============================================================================
-- "Email Palestra": riepilogo nell'app della casella email condivisa della
-- palestra (Aruba, IMAP) e lettura automatica delle fatture allegate.
--
-- Una edge function (mailbox-sync, invocata ogni 15 minuti da pg_cron) legge
-- la casella via IMAP con la service role, salva i messaggi in
-- mailbox_messages e, per ogni PDF allegato, lo fa leggere a Claude e crea
-- una riga in mailbox_invoices con importo/scadenza/descrizione letti.
-- L'app mostra l'elenco email (sola lettura + segna-letto) e le fatture da
-- confermare/pagare, riservato a admin/principal_admin.
--
-- NON APPLICATA: solo scritta, da rivedere e applicare manualmente.
-- Idempotente: rieseguibile senza errori (CREATE TABLE IF NOT EXISTS, DROP
-- POLICY IF EXISTS + CREATE POLICY, CREATE OR REPLACE FUNCTION).
-- ============================================================================

-- ============================================================================
-- 1) mailbox_messages — un riepilogo per ogni email arrivata sulla casella
--    condivisa. Scritta SOLO dalla edge function (service role, che bypassa
--    RLS): nessuna policy di INSERT/UPDATE/DELETE per authenticated.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mailbox_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_uid text UNIQUE,
  message_id_header text,
  from_address text,
  subject text,
  received_at timestamptz,
  snippet text,
  has_attachment boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mailbox_messages_received_at
  ON public.mailbox_messages (received_at DESC);

ALTER TABLE public.mailbox_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mailbox_messages_select_admin ON public.mailbox_messages;
CREATE POLICY mailbox_messages_select_admin
  ON public.mailbox_messages FOR SELECT TO authenticated
  USING (public.is_admin_from_auth());

-- ============================================================================
-- 2) mailbox_message_reads — quali messaggi ha già aperto ciascun admin, per
--    il numerino "non lette" personale (badge diverso per ogni admin).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mailbox_message_reads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.mailbox_messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  read_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_mailbox_message_reads_user
  ON public.mailbox_message_reads (user_id);

ALTER TABLE public.mailbox_message_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mailbox_message_reads_own_rows ON public.mailbox_message_reads;
CREATE POLICY mailbox_message_reads_own_rows
  ON public.mailbox_message_reads FOR ALL TO authenticated
  USING (user_id = auth.uid() AND public.is_admin_from_auth())
  WITH CHECK (user_id = auth.uid() AND public.is_admin_from_auth());

-- ============================================================================
-- 3) mailbox_invoices — una riga per ogni fattura letta da un allegato PDF.
--    Volutamente NON collegata allo scadenzario ASD: asd_deadlines è per
--    scadenze ricorrenti/istituzionali (due_month/due_day/repeat_months,
--    nessun importo), non per un pagamento puntuale con importo e scadenza
--    propri come una bolletta o una fattura fornitore. deadline_completion_id
--    resta come semplice riferimento libero per un eventuale collegamento
--    manuale futuro, senza inserire automaticamente nulla in
--    asd_deadline_completions.
--
--    status: 'da_confermare' (appena letta, importo/scadenza da rivedere) ->
--    'confermata' (admin ha confermato/corretto i dati) -> 'pagata' (prova
--    di bonifico caricata). 'ignorata' per scartare una riga non rilevante.
--    ('pagata' è stata aggiunta rispetto all'elenco iniziale: senza non si
--    potrebbe mai raggiungere lo stato finale richiesto dal punto C.)
--
--    attachment_path (prova di bonifico) segue lo stesso pattern, già usato
--    altrove nel progetto, di asd_deadline_completions.attachment_path: un
--    semplice percorso di storage in una colonna di testo, niente tabelle
--    aggiuntive.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mailbox_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mailbox_message_id uuid REFERENCES public.mailbox_messages(id) ON DELETE CASCADE,
  sender text,
  subject text,
  amount numeric,
  due_date date,
  description text,
  pdf_path text,
  status text NOT NULL DEFAULT 'da_confermare'
    CHECK (status IN ('da_confermare', 'confermata', 'pagata', 'ignorata')),
  confirmed_by uuid REFERENCES public.user_profiles(id),
  confirmed_at timestamptz,
  deadline_completion_id uuid REFERENCES public.asd_deadline_completions(id) ON DELETE SET NULL,
  attachment_path text,
  paid_by uuid REFERENCES public.user_profiles(id),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mailbox_invoices_status
  ON public.mailbox_invoices (status);
CREATE INDEX IF NOT EXISTS idx_mailbox_invoices_message
  ON public.mailbox_invoices (mailbox_message_id);

ALTER TABLE public.mailbox_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mailbox_invoices_admin_all ON public.mailbox_invoices;
CREATE POLICY mailbox_invoices_admin_all
  ON public.mailbox_invoices FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 4) mailbox_sync_state — singola riga che tiene traccia dell'ultimo UID
--    IMAP sincronizzato (e dell'ultimo errore, per poterlo controllare senza
--    dover leggere i log della edge function). Solo service role: nessuna
--    policy per authenticated (RLS attiva = accesso negato di default).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mailbox_sync_state (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  last_uid bigint,
  last_synced_at timestamptz,
  last_error text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.mailbox_sync_state (id, last_uid)
VALUES (1, NULL)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.mailbox_sync_state ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5) Bucket storage 'mailbox-attachments' — privato. Sola lettura per admin.
--    Scrittura: solo service role per gli allegati letti dalla mailbox
--    (prefisso invoices/, popolato dalla edge function); fa eccezione il
--    prefisso proofs/, dove un admin autenticato può caricare la PROVA DI
--    BONIFICO da app (punto C) — è l'unico upload lato client di questa
--    funzione, il resto del bucket resta scrivibile solo dalla edge
--    function.
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'mailbox-attachments',
  'mailbox-attachments',
  false,
  20971520,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS mailbox_attachments_admin_read ON storage.objects;
CREATE POLICY mailbox_attachments_admin_read
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'mailbox-attachments' AND public.is_admin_from_auth());

DROP POLICY IF EXISTS mailbox_attachments_admin_write_proofs ON storage.objects;
CREATE POLICY mailbox_attachments_admin_write_proofs
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'mailbox-attachments'
    AND public.is_admin_from_auth()
    AND (storage.foldername(name))[1] = 'proofs'
  );

-- ============================================================================
-- 6) mailbox_unread_count() — quante mailbox_messages non hanno ancora una
--    riga in mailbox_message_reads per l'utente corrente. Fallisce chiuso:
--    chi non è admin vede 0 invece di un errore (il badge resta a zero).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mailbox_unread_count()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN public.is_admin_from_auth() THEN (
    SELECT count(*)::integer
    FROM public.mailbox_messages m
    WHERE NOT EXISTS (
      SELECT 1 FROM public.mailbox_message_reads r
      WHERE r.message_id = m.id AND r.user_id = auth.uid()
    )
  ) ELSE 0 END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_unread_count() TO authenticated;

-- ============================================================================
-- 7) mailbox_mark_read(p_message_id) — segna un messaggio letto per
--    l'utente corrente (upsert).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mailbox_mark_read(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Funzione riservata agli amministratori.';
  END IF;

  INSERT INTO public.mailbox_message_reads (message_id, user_id, read_at)
  VALUES (p_message_id, auth.uid(), now())
  ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_mark_read(uuid) TO authenticated;

-- ============================================================================
-- 8) mailbox_confirm_invoice(...) — l'admin conferma (eventualmente
--    correggendo) importo/scadenza/descrizione letti da Claude.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mailbox_confirm_invoice(
  p_invoice_id uuid,
  p_amount numeric,
  p_due_date date,
  p_description text
)
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
  SET amount = p_amount,
      due_date = p_due_date,
      description = p_description,
      status = 'confermata',
      confirmed_by = auth.uid(),
      confirmed_at = now()
  WHERE id = p_invoice_id
    AND status = 'da_confermare';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fattura non trovata o già confermata.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_confirm_invoice(uuid, numeric, date, text) TO authenticated;

-- ============================================================================
-- 9) mailbox_mark_invoice_paid(...) — l'admin carica la prova di bonifico e
--    segna la fattura come pagata.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mailbox_mark_invoice_paid(
  p_invoice_id uuid,
  p_attachment_path text
)
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
  SET status = 'pagata',
      attachment_path = p_attachment_path,
      paid_by = auth.uid(),
      paid_at = now()
  WHERE id = p_invoice_id
    AND status = 'confermata';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fattura non trovata o non ancora confermata.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mailbox_mark_invoice_paid(uuid, text) TO authenticated;

-- ============================================================================
-- 10) pg_cron ogni 15 minuti che invoca la edge function mailbox-sync via
--     pg_net, con l'anon key nell'header Authorization (la funzione ha
--     comunque verify_jwt=false, quindi non è strettamente richiesta, ma la
--     mandiamo comunque come da richiesta).
--
--     Nessun precedente di questo pattern nel progetto (gli altri cron,
--     es. shop-close-expired-windows, chiamano funzioni SQL direttamente).
--     URL e anon key NON sono scritti qui in chiaro: sono valori pubblici
--     dell'app ma non è comunque buona norma metterli a testo fisso in un
--     file versionato. Prima di applicare questa migrazione, imposta:
--
--       ALTER DATABASE postgres SET app.settings.supabase_url =
--         'https://<il-tuo-project-ref>.supabase.co';
--       ALTER DATABASE postgres SET app.settings.supabase_anon_key =
--         '<la-tua-anon-key>';
--
--     (stessi due valori già usati per inizializzare il client Flutter).
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'mailbox-sync';

SELECT cron.schedule(
  'mailbox-sync',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/mailbox-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.supabase_anon_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);
