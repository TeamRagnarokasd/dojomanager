-- Add PEC column to organization_info table
-- Update get_organization_info_for_receipts to include pec field

ALTER TABLE public.organization_info
    ADD COLUMN IF NOT EXISTS pec TEXT;

-- Update the secure function to also return pec
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
  FROM organization_info oi
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_organization_info_for_receipts() TO authenticated;
