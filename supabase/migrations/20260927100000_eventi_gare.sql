-- "Eventi e Seminari" (ricostruzione completa, con salvataggio reale) e nuova
-- sezione "Gare" (MMA / BJJ-Grappling / Sambo). Ammin crea eventi e carica
-- calendari gare (letti da Claude da una foto, poi confermati a mano prima
-- di pubblicare); allievi si prenotano agli eventi e segnalano interesse o
-- iscrizione alle gare. L'utente per cui si prenota/segnala può essere
-- l'adulto autenticato o uno dei suoi child_profiles (vedi
-- ChildProfileService.getActiveUserId() nell'app) — mai un'altra persona.
--
-- NON applicare questa migrazione finché non revisionata.
-- Idempotente: rieseguibile senza errori (CREATE TABLE IF NOT EXISTS, DROP
-- POLICY IF EXISTS + CREATE POLICY, CREATE OR REPLACE FUNCTION, INSERT ...
-- ON CONFLICT DO NOTHING).

-- ============================================================================
-- 1) events_seminars — eventi/seminari organizzati dal team. Lettura per
--    tutti gli autenticati, scrittura solo admin (public.is_admin_from_auth(),
--    la stessa verifica già usata dalle altre tabelle admin del progetto).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.events_seminars (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  event_datetime timestamptz NOT NULL,
  discipline text,
  instructor_name text,
  location text,
  room text,
  capacity integer NOT NULL,
  price numeric NOT NULL DEFAULT 0,
  description text,
  poster_path text,
  status text NOT NULL DEFAULT 'pubblicato' CHECK (status IN ('pubblicato', 'annullato')),
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT events_seminars_room_only_palacosta
    CHECK (room IS NULL OR location = 'Palacosta')
);

CREATE INDEX IF NOT EXISTS idx_events_seminars_datetime
  ON public.events_seminars (event_datetime);
CREATE INDEX IF NOT EXISTS idx_events_seminars_status
  ON public.events_seminars (status);

ALTER TABLE public.events_seminars ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS events_seminars_select_authenticated ON public.events_seminars;
CREATE POLICY events_seminars_select_authenticated
  ON public.events_seminars FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS events_seminars_admin_write ON public.events_seminars;
CREATE POLICY events_seminars_admin_write
  ON public.events_seminars FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 2) event_registrations — prenotazioni. user_id è l'id ritornato da
--    ChildProfileService.getActiveUserId() nell'app: può essere l'adulto
--    (user_profiles.id) o un suo figlio (child_profiles.id) — di proposito
--    SENZA foreign key rigida verso una sola tabella, solo indicizzato.
--    Un solo 'prenotato' per (event_id, user_id) alla volta (indice unico
--    parziale: righe 'annullato' possono coesistere/storicizzarsi).
--    Niente INSERT/UPDATE diretto per gli utenti: solo tramite le RPC
--    event_register / event_cancel_registration sotto, che verificano
--    l'appartenenza e la capienza. Admin legge/scrive tutto.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.event_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events_seminars(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  registered_at timestamptz NOT NULL DEFAULT now(),
  cancelled_at timestamptz,
  status text NOT NULL DEFAULT 'prenotato' CHECK (status IN ('prenotato', 'annullato'))
);

CREATE INDEX IF NOT EXISTS idx_event_registrations_user ON public.event_registrations (user_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_event ON public.event_registrations (event_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_event_registrations_active
  ON public.event_registrations (event_id, user_id)
  WHERE status = 'prenotato';

ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS event_registrations_select_own ON public.event_registrations;
CREATE POLICY event_registrations_select_own
  ON public.event_registrations FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.child_profiles cp
      WHERE cp.id = event_registrations.user_id AND cp.guardian_id = auth.uid()
    )
    OR public.is_admin_from_auth()
  );

DROP POLICY IF EXISTS event_registrations_admin_write ON public.event_registrations;
CREATE POLICY event_registrations_admin_write
  ON public.event_registrations FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 3) event_register / event_cancel_registration — SECURITY DEFINER: solo
--    così un allievo può contare le prenotazioni di TUTTI (per il controllo
--    di capienza) restando bloccato dalla RLS su qualunque altra lettura o
--    scrittura diretta della tabella.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.event_register(p_event_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity integer;
  v_status text;
  v_event_datetime timestamptz;
  v_registered_count integer;
  v_existing_id uuid;
  v_existing_status text;
BEGIN
  IF p_user_id <> auth.uid() AND NOT EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = p_user_id AND cp.guardian_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Non puoi prenotare per questo utente.';
  END IF;

  SELECT capacity, status, event_datetime
  INTO v_capacity, v_status, v_event_datetime
  FROM public.events_seminars
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_capacity IS NULL THEN
    RAISE EXCEPTION 'Evento non trovato.';
  END IF;
  IF v_status <> 'pubblicato' THEN
    RAISE EXCEPTION 'Questo evento non è più disponibile.';
  END IF;
  IF v_event_datetime <= now() THEN
    RAISE EXCEPTION 'Questo evento è già passato.';
  END IF;

  SELECT id, status INTO v_existing_id, v_existing_status
  FROM public.event_registrations
  WHERE event_id = p_event_id AND user_id = p_user_id
  FOR UPDATE;

  IF v_existing_status = 'prenotato' THEN
    RETURN; -- già prenotato, nessuna operazione.
  END IF;

  SELECT COUNT(*) INTO v_registered_count
  FROM public.event_registrations
  WHERE event_id = p_event_id AND status = 'prenotato';

  IF v_registered_count >= v_capacity THEN
    RAISE EXCEPTION 'Evento al completo: nessun posto disponibile.';
  END IF;

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.event_registrations
    SET status = 'prenotato', registered_at = now(), cancelled_at = NULL
    WHERE id = v_existing_id;
  ELSE
    INSERT INTO public.event_registrations (event_id, user_id, status)
    VALUES (p_event_id, p_user_id, 'prenotato');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.event_register(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.event_cancel_registration(p_event_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id <> auth.uid() AND NOT EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = p_user_id AND cp.guardian_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Non puoi annullare la prenotazione di questo utente.';
  END IF;

  UPDATE public.event_registrations
  SET status = 'annullato', cancelled_at = now()
  WHERE event_id = p_event_id AND user_id = p_user_id AND status = 'prenotato';
END;
$$;

GRANT EXECUTE ON FUNCTION public.event_cancel_registration(uuid, uuid) TO authenticated;

-- ============================================================================
-- 4) get_events_registration_counts() — quanti 'prenotato' per evento, per
--    tutti gli eventi. SECURITY DEFINER: serve a mostrare "posti rimasti"
--    a qualunque allievo senza dargli accesso diretto alle prenotazioni
--    degli altri (la RLS sopra le nasconde). Nessun dato personale, solo
--    un conteggio per evento.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_events_registration_counts()
RETURNS TABLE(event_id uuid, registered_count integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT er.event_id, COUNT(*)::integer
  FROM public.event_registrations er
  WHERE er.status = 'prenotato'
  GROUP BY er.event_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_events_registration_counts() TO authenticated;

-- ============================================================================
-- 5) competitions — calendario gare (MMA / BJJ-Grappling / Sambo). Lettura
--    per tutti gli autenticati, scrittura solo admin.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.competitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL CHECK (category IN ('mma', 'bjj_grappling', 'sambo')),
  name text NOT NULL,
  event_date_start date NOT NULL,
  event_date_end date NOT NULL,
  city text,
  notes text,
  registration_link text,
  source_image_path text,
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competitions_category ON public.competitions (category);
CREATE INDEX IF NOT EXISTS idx_competitions_date_start ON public.competitions (event_date_start);

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS competitions_select_authenticated ON public.competitions;
CREATE POLICY competitions_select_authenticated
  ON public.competitions FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS competitions_admin_write ON public.competitions;
CREATE POLICY competitions_admin_write
  ON public.competitions FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 6) competition_interest — "voglio farla" / "mi sono iscritto" per
--    (gara, utente). Stessa logica di appartenenza di event_registrations:
--    adulto o uno dei suoi child_profiles. Niente INSERT/UPDATE diretto:
--    solo tramite le RPC sotto. Admin legge/scrive tutto.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.competition_interest (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id uuid NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  interested boolean NOT NULL DEFAULT true,
  self_registered boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_competition_interest_user
  ON public.competition_interest (competition_id, user_id);
CREATE INDEX IF NOT EXISTS idx_competition_interest_user ON public.competition_interest (user_id);

ALTER TABLE public.competition_interest ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS competition_interest_select_own ON public.competition_interest;
CREATE POLICY competition_interest_select_own
  ON public.competition_interest FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.child_profiles cp
      WHERE cp.id = competition_interest.user_id AND cp.guardian_id = auth.uid()
    )
    OR public.is_admin_from_auth()
  );

DROP POLICY IF EXISTS competition_interest_admin_write ON public.competition_interest;
CREATE POLICY competition_interest_admin_write
  ON public.competition_interest FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

CREATE OR REPLACE FUNCTION public.competition_set_interest(
  p_competition_id uuid, p_user_id uuid, p_interested boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id <> auth.uid() AND NOT EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = p_user_id AND cp.guardian_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Non puoi modificare l''interesse di questo utente.';
  END IF;

  INSERT INTO public.competition_interest (competition_id, user_id, interested, updated_at)
  VALUES (p_competition_id, p_user_id, p_interested, now())
  ON CONFLICT (competition_id, user_id)
  DO UPDATE SET interested = EXCLUDED.interested, updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.competition_set_interest(uuid, uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.competition_set_self_registered(
  p_competition_id uuid, p_user_id uuid, p_registered boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id <> auth.uid() AND NOT EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = p_user_id AND cp.guardian_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Non puoi modificare l''iscrizione di questo utente.';
  END IF;

  INSERT INTO public.competition_interest (competition_id, user_id, self_registered, updated_at)
  VALUES (p_competition_id, p_user_id, p_registered, now())
  ON CONFLICT (competition_id, user_id)
  DO UPDATE SET self_registered = EXCLUDED.self_registered, updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.competition_set_self_registered(uuid, uuid, boolean) TO authenticated;

-- ============================================================================
-- 7) admin_event_participants / admin_competition_participants — elenco
--    nominativo per l'admin (prenotati a un evento, interessati/iscritti a
--    una gara). Il nome viene da user_profiles.full_name per un adulto, o
--    da child_profiles.full_name se l'id è un figlio (is_child = true).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_event_participants(p_event_id uuid)
RETURNS TABLE(
  user_id uuid,
  full_name text,
  is_child boolean,
  registered_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Funzione riservata agli amministratori.';
  END IF;

  RETURN QUERY
  SELECT
    er.user_id,
    COALESCE(up.full_name, cp.full_name) AS full_name,
    (cp.id IS NOT NULL) AS is_child,
    er.registered_at
  FROM public.event_registrations er
  LEFT JOIN public.user_profiles up ON up.id = er.user_id
  LEFT JOIN public.child_profiles cp ON cp.id = er.user_id
  WHERE er.event_id = p_event_id AND er.status = 'prenotato'
  ORDER BY er.registered_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_event_participants(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_competition_participants(p_competition_id uuid)
RETURNS TABLE(
  user_id uuid,
  full_name text,
  is_child boolean,
  interested boolean,
  self_registered boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Funzione riservata agli amministratori.';
  END IF;

  RETURN QUERY
  SELECT
    ci.user_id,
    COALESCE(up.full_name, cp.full_name) AS full_name,
    (cp.id IS NOT NULL) AS is_child,
    ci.interested,
    ci.self_registered
  FROM public.competition_interest ci
  LEFT JOIN public.user_profiles up ON up.id = ci.user_id
  LEFT JOIN public.child_profiles cp ON cp.id = ci.user_id
  WHERE ci.competition_id = p_competition_id
    AND (ci.interested = true OR ci.self_registered = true)
  ORDER BY 2 ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_competition_participants(uuid) TO authenticated;

-- ============================================================================
-- 8) Bucket pubblico 'event-posters' — locandine eventi. Lettura pubblica
--    (anche senza login, per l'anteprima sul sito), scrittura solo admin.
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'event-posters',
  'event-posters',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS event_posters_public_read ON storage.objects;
CREATE POLICY event_posters_public_read
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'event-posters');

DROP POLICY IF EXISTS event_posters_admin_write ON storage.objects;
CREATE POLICY event_posters_admin_write
  ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'event-posters' AND public.is_admin_from_auth())
  WITH CHECK (bucket_id = 'event-posters' AND public.is_admin_from_auth());

-- ============================================================================
-- 9) Bucket privato 'competition-sources' — foto dei calendari gare caricati
--    dall'admin. Solo admin legge/scrive; l'edge function
--    competition-calendar-read la legge con la service role.
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'competition-sources',
  'competition-sources',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS competition_sources_admin_only ON storage.objects;
CREATE POLICY competition_sources_admin_only
  ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'competition-sources' AND public.is_admin_from_auth())
  WITH CHECK (bucket_id = 'competition-sources' AND public.is_admin_from_auth());
