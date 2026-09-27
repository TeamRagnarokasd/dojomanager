-- Aggiunge la categoria 'k1' alle gare (public.competitions.category).
-- Già applicata al database: questa migrazione serve solo a tenere il
-- repository allineato.
--
-- Idempotente: rieseguibile senza errori.

ALTER TABLE public.competitions DROP CONSTRAINT IF EXISTS competitions_category_check;
ALTER TABLE public.competitions ADD CONSTRAINT competitions_category_check
  CHECK (category IN ('mma', 'bjj_grappling', 'sambo', 'k1'));
