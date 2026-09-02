-- Migration: Add first_name and last_name columns to user_profiles table
-- Purpose: Split full_name into separate first and last name fields for better data management

-- Add new columns for first_name and last_name
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_first_name ON public.user_profiles(first_name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_name ON public.user_profiles(last_name);

-- Optional: Migrate existing full_name data to first_name and last_name
-- This assumes full_name format is "FirstName LastName"
-- Uncomment and run if you want to migrate existing data:
/*
UPDATE public.user_profiles
SET 
  first_name = SPLIT_PART(full_name, ' ', 1),
  last_name = CASE 
    WHEN ARRAY_LENGTH(STRING_TO_ARRAY(full_name, ' '), 1) > 1 
    THEN SUBSTRING(full_name FROM LENGTH(SPLIT_PART(full_name, ' ', 1)) + 2)
    ELSE ''
  END
WHERE full_name IS NOT NULL 
  AND (first_name IS NULL OR last_name IS NULL);
*/

-- Add comments for documentation
COMMENT ON COLUMN public.user_profiles.first_name IS 'User first name (nome)';
COMMENT ON COLUMN public.user_profiles.last_name IS 'User last name (cognome)';

-- Note: full_name column is kept for backward compatibility
-- Consider removing it in a future migration after ensuring all apps are updated