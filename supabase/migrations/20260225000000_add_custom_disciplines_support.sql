-- Migration: Add custom disciplines table for user-defined disciplines
-- This allows admins to create new disciplines without modifying the ENUM

-- Create custom_disciplines table
CREATE TABLE IF NOT EXISTS public.custom_disciplines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT,
  color_hex TEXT DEFAULT '#757575',
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add RLS policies
ALTER TABLE public.custom_disciplines ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read custom disciplines
CREATE POLICY "Allow authenticated users to read custom disciplines"
  ON public.custom_disciplines
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow admins to insert custom disciplines
CREATE POLICY "Allow admins to insert custom disciplines"
  ON public.custom_disciplines
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'principal_admin', 'instructor_admin')
    )
  );

-- Allow admins to update custom disciplines
CREATE POLICY "Allow admins to update custom disciplines"
  ON public.custom_disciplines
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'principal_admin', 'instructor_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'principal_admin', 'instructor_admin')
    )
  );

-- Allow principal admins to delete custom disciplines
CREATE POLICY "Allow principal admins to delete custom disciplines"
  ON public.custom_disciplines
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
      AND role = 'principal_admin'
    )
  );

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_custom_disciplines_name ON public.custom_disciplines(name);
CREATE INDEX IF NOT EXISTS idx_custom_disciplines_is_active ON public.custom_disciplines(is_active);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_custom_disciplines_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_custom_disciplines_updated_at_trigger
  BEFORE UPDATE ON public.custom_disciplines
  FOR EACH ROW
  EXECUTE FUNCTION update_custom_disciplines_updated_at();

-- Function to get all disciplines (both ENUM and custom)
CREATE OR REPLACE FUNCTION get_all_available_disciplines()
RETURNS TABLE (
  discipline_id TEXT,
  discipline_name TEXT,
  display_name TEXT,
  color_hex TEXT,
  is_custom BOOLEAN
) AS $$
BEGIN
  -- Return ENUM disciplines
  RETURN QUERY
  SELECT 
    unnest(enum_range(NULL::discipline_type))::TEXT as discipline_id,
    unnest(enum_range(NULL::discipline_type))::TEXT as discipline_name,
    CASE unnest(enum_range(NULL::discipline_type))::TEXT
      WHEN 'bjj' THEN 'BJJ'
      WHEN 'mma' THEN 'MMA'
      WHEN 'sambo' THEN 'SAMBO'
      WHEN 'grappling' THEN 'Grappling'
      WHEN 'fitness' THEN 'Prep. Atletica'
      WHEN 'prep_atletica' THEN 'Prep. Atletica'
      WHEN 'Preparazione Atletica' THEN 'Prep. Atletica'
      ELSE unnest(enum_range(NULL::discipline_type))::TEXT
    END as display_name,
    CASE unnest(enum_range(NULL::discipline_type))::TEXT
      WHEN 'bjj' THEN '#2196F3'
      WHEN 'mma' THEN '#FF5722'
      WHEN 'sambo' THEN '#4CAF50'
      WHEN 'grappling' THEN '#9C27B0'
      WHEN 'fitness' THEN '#FFC107'
      WHEN 'prep_atletica' THEN '#FFC107'
      WHEN 'Preparazione Atletica' THEN '#FFC107'
      ELSE '#757575'
    END as color_hex,
    false as is_custom;

  -- Return custom disciplines
  RETURN QUERY
  SELECT 
    cd.id::TEXT as discipline_id,
    cd.name as discipline_name,
    cd.display_name,
    cd.color_hex,
    true as is_custom
  FROM public.custom_disciplines cd
  WHERE cd.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_all_available_disciplines() TO authenticated;