-- Migration: Fix organization_info RLS to allow receipt downloads for all authenticated users
-- Date: 2025-12-05 00:02:31
-- Purpose: Allow students to download their receipts by accessing organization info

-- 🎯 PROBLEM: Students cannot download receipts because they can't read organization_info table
-- 🎯 SOLUTION: Create a SECURITY DEFINER function that allows authenticated users to read org info for receipts

-- Step 1: Create a secure function to get organization info for receipt generation
CREATE OR REPLACE FUNCTION public.get_organization_info_for_receipts()
RETURNS TABLE (
  id uuid,
  name text,
  address text,
  tax_code text,
  phone text,
  email text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER -- This allows the function to bypass RLS
SET search_path = public
AS $$
BEGIN
  -- Return organization info (there should only be one row)
  RETURN QUERY
  SELECT 
    oi.id,
    oi.name,
    oi.address,
    oi.tax_code,
    oi.phone,
    oi.email,
    oi.created_at,
    oi.updated_at
  FROM organization_info oi
  LIMIT 1;
END;
$$;

-- Step 2: Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_organization_info_for_receipts() TO authenticated;

-- Step 3: Add comment explaining the function's purpose
COMMENT ON FUNCTION public.get_organization_info_for_receipts() IS 
'Allows authenticated users to retrieve organization information for receipt generation purposes. Uses SECURITY DEFINER to bypass RLS restrictions.';

-- Step 4: Add new RLS policy for authenticated users to read organization_info (read-only access)
CREATE POLICY "authenticated_users_can_read_organization_info_for_receipts"
ON organization_info
FOR SELECT
TO authenticated
USING (true);

-- Note: The existing admin_manage_organization_info policy still controls write access
-- This new policy only grants read access to all authenticated users