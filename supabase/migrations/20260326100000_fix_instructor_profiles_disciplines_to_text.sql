-- Migration: Convert instructor_profiles discipline columns from ENUM to TEXT
-- This fixes the "invalid input value for enum discipline_type" error when
-- saving custom disciplines (like K1) to instructor profiles.

-- Drop the GIN index on disciplines (uses ENUM type, must be recreated)
DROP INDEX IF EXISTS public.idx_instructor_profiles_disciplines;

-- Drop the btree index on primary_discipline (uses ENUM type, must be recreated)
DROP INDEX IF EXISTS public.idx_instructor_profiles_primary_discipline;

-- Convert primary_discipline from discipline_type ENUM to TEXT
ALTER TABLE public.instructor_profiles
  ALTER COLUMN primary_discipline TYPE TEXT USING primary_discipline::TEXT;

-- Convert disciplines from discipline_type[] ENUM array to TEXT[]
ALTER TABLE public.instructor_profiles
  ALTER COLUMN disciplines TYPE TEXT[] USING disciplines::TEXT[];

-- Recreate indexes with TEXT type
CREATE INDEX idx_instructor_profiles_primary_discipline ON public.instructor_profiles(primary_discipline);
CREATE INDEX idx_instructor_profiles_disciplines ON public.instructor_profiles USING GIN(disciplines);
