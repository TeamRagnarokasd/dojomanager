-- Migration: Add member belts/strips table and attendance stats support
-- Timestamp: 20260702000000

-- 1. Create belt color enum
DROP TYPE IF EXISTS public.belt_color CASCADE;
CREATE TYPE public.belt_color AS ENUM (
  'white', 'yellow', 'orange', 'green', 'blue', 'purple', 'brown', 'black'
);

-- 2. Create member_belts table
CREATE TABLE IF NOT EXISTS public.member_belts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  discipline TEXT NOT NULL,
  belt_color public.belt_color NOT NULL DEFAULT 'white'::public.belt_color,
  strips INTEGER NOT NULL DEFAULT 0 CHECK (strips >= 0 AND strips <= 4),
  assigned_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Unique constraint: one belt per user per discipline
CREATE UNIQUE INDEX IF NOT EXISTS idx_member_belts_user_discipline
  ON public.member_belts (user_id, discipline);

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_member_belts_user_id ON public.member_belts(user_id);
CREATE INDEX IF NOT EXISTS idx_member_belts_assigned_by ON public.member_belts(assigned_by);

-- 5. Enable RLS
ALTER TABLE public.member_belts ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
DROP POLICY IF EXISTS "instructors_manage_belts" ON public.member_belts;
CREATE POLICY "instructors_manage_belts"
ON public.member_belts
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 7. Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_member_belts_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_member_belts_updated_at ON public.member_belts;
CREATE TRIGGER trg_member_belts_updated_at
  BEFORE UPDATE ON public.member_belts
  FOR EACH ROW EXECUTE FUNCTION public.update_member_belts_updated_at();
