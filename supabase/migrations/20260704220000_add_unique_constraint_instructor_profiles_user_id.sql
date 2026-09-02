-- Fix: Add unique constraint on instructor_profiles.user_id
-- This is required for the upsert with onConflict: 'user_id' to work correctly.
-- Without this constraint, PostgreSQL throws:
--   "there is no unique or exclusion constraint matching the ON CONFLICT specification"

CREATE UNIQUE INDEX IF NOT EXISTS idx_instructor_profiles_user_id_unique
    ON public.instructor_profiles (user_id);
