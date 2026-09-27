-- ============================================================================
-- Modalità di visualizzazione della locandina su competitions: "riempi"
-- (sfondo scheda, BoxFit.cover con punto di fuoco verticale regolabile) o
-- "intera" (locandina intera, BoxFit.contain, senza ritaglio).
--
-- Nota: questo file non è stato ancora applicato al database — va eseguito
-- manualmente prima che le nuove colonne siano disponibili in produzione.
-- ============================================================================
ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS poster_display_mode text NOT NULL DEFAULT 'riempi'
    CHECK (poster_display_mode IN ('riempi', 'intera'));

ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS poster_focus_y numeric NOT NULL DEFAULT 0.5
    CHECK (poster_focus_y >= 0 AND poster_focus_y <= 1);
