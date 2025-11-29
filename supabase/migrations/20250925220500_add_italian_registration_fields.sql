-- Location: supabase/migrations/20250925220500_add_italian_registration_fields.sql
-- Schema Analysis: Existing user_profiles table with basic fields (birth_date, emergency_contact, phone)
-- Integration Type: MODIFICATIVE - Adding missing Italian registration fields
-- Dependencies: user_profiles table (existing)

-- Add missing Italian registration fields to existing user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS codice_fiscale TEXT,
ADD COLUMN IF NOT EXISTS address_line TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS province TEXT,
ADD COLUMN IF NOT EXISTS cap TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_name TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_surname TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_codice_fiscale TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_email TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_phone TEXT,
ADD COLUMN IF NOT EXISTS parent_guardian_relation TEXT,
ADD COLUMN IF NOT EXISTS is_minor BOOLEAN DEFAULT false;

-- Add index for codice_fiscale for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_codice_fiscale ON public.user_profiles(codice_fiscale);

-- Add index for cap for location-based queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_cap ON public.user_profiles(cap);