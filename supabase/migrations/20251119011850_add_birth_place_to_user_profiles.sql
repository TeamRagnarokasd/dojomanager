-- Location: supabase/migrations/20251119011850_add_birth_place_to_user_profiles.sql
-- Schema Analysis: Existing user_profiles table with personal info fields
-- Integration Type: Extension - Adding birth_place field to existing table
-- Dependencies: user_profiles table (existing)

-- Add birth_place column to existing user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN birth_place TEXT;

-- Add index for the new column to improve query performance
CREATE INDEX idx_user_profiles_birth_place ON public.user_profiles(birth_place);

-- Add comment to document the new column
COMMENT ON COLUMN public.user_profiles.birth_place IS 'Luogo di nascita dell''utente - può essere modificato dall''utente';