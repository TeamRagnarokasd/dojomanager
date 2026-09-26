-- "Chiedi a Claude (dati app)": chat AI di sola lettura riservata ad admin e
-- admin principale, per fare domande sui dati dell'app in linguaggio
-- naturale. Nessuna scrittura possibile lato database da questa funzione:
-- l'edge function admin-ask-claude apre una connessione Postgres separata e
-- la mette subito in modalità READ ONLY per l'intera sessione, qualunque
-- cosa succeda dopo. Questa migrazione crea solo la cronologia locale delle
-- domande/risposte e la funzione di controllo ruolo — NON va applicata
-- finché non revisionata.
--
-- Idempotente: rieseguibile senza errori.

-- ============================================================================
-- 1) is_admin_or_secretary_from_auth(): true solo per 'admin' o
--    'principal_admin' (esclude instructor_admin, a differenza delle
--    funzioni is_admin_* già esistenti nel progetto, che lo includono).
--    Nessuna funzione equivalente già presente — verificato tra tutte le
--    funzioni is_%() in public.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin_or_secretary_from_auth()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.role IN ('admin'::public.user_role, 'principal_admin'::public.user_role)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_or_secretary_from_auth() TO authenticated;

-- ============================================================================
-- 2) admin_ai_queries — cronologia locale nell'app delle domande/risposte.
--    Ogni admin legge/scrive solo le proprie righe; nessun accesso per gli
--    altri ruoli.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_ai_queries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  question text NOT NULL,
  answer text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_ai_queries_user
  ON public.admin_ai_queries (user_id, created_at DESC);

ALTER TABLE public.admin_ai_queries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_ai_queries_own_rows ON public.admin_ai_queries;
CREATE POLICY admin_ai_queries_own_rows
  ON public.admin_ai_queries FOR ALL TO authenticated
  USING (public.is_admin_or_secretary_from_auth() AND user_id = auth.uid())
  WITH CHECK (public.is_admin_or_secretary_from_auth() AND user_id = auth.uid());
