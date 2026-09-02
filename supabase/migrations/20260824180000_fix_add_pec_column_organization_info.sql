-- Fix: Add PEC column to organization_info table and recreate function with updated return type
-- DROP first to allow changing the return type (adding pec column)

ALTER TABLE public.organization_info
    ADD COLUMN IF NOT EXISTS pec TEXT;

-- Must DROP before recreating because return type changed (added pec)
DROP FUNCTION IF EXISTS public.get_organization_info_for_receipts();

CREATE OR REPLACE FUNCTION public.get_organization_info_for_receipts()
RETURNS TABLE (
  id uuid,
  name text,
  address text,
  tax_code text,
  phone text,
  email text,
  pec text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    oi.id,
    oi.name,
    oi.address,
    oi.tax_code,
    oi.phone,
    oi.email,
    oi.pec,
    oi.created_at,
    oi.updated_at
  FROM public.organization_info oi
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_organization_info_for_receipts() TO authenticated;
