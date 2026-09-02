-- Migration: Fix "permission denied for table users" on non_fiscal_receipts
-- Root cause: RLS policies were using SELECT FROM auth.users directly,
-- which is not accessible to the authenticated role.
-- Fix: Use user_profiles table (public schema) to check admin role instead.

-- Step 1: Create a SECURITY DEFINER helper function that checks admin role
-- via user_profiles (accessible to authenticated) instead of auth.users (not accessible)
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
  )
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

-- Step 2: Drop ALL existing policies on non_fiscal_receipts to start clean
DROP POLICY IF EXISTS "admin_full_access_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_read_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_can_read_own_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_view_own_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_can_view_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_admin_all" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_select" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_insert" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_delete" ON public.non_fiscal_receipts;

-- Step 3: Admin full access policy — uses is_admin_user() (no auth.users reference)
CREATE POLICY "admin_full_access_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR ALL
TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- Step 4: Users can SELECT receipts that belong to them:
--   (a) created_by = their user id, OR
--   (b) linked via batch_transaction_id to one of their confirmed payment_confirmations, OR
--   (c) customer_name matches their full_name in user_profiles
CREATE POLICY "users_read_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid()
  OR (
    batch_transaction_id IS NOT NULL
    AND batch_transaction_id IN (
      SELECT pc.batch_transaction_id
      FROM public.payment_confirmations pc
      WHERE pc.user_id = auth.uid()
        AND pc.batch_transaction_id IS NOT NULL
        AND pc.status = 'confirmed'
    )
  )
  OR (
    customer_name IS NOT NULL
    AND customer_name ILIKE (
      SELECT up.full_name
      FROM public.user_profiles up
      WHERE up.id = auth.uid()
      LIMIT 1
    )
  )
);

-- Step 5: Users can DELETE receipts they created (for user-profile delete button)
CREATE POLICY "users_delete_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR DELETE
TO authenticated
USING (
  created_by = auth.uid()
  OR public.is_admin_user()
  OR (
    batch_transaction_id IS NOT NULL
    AND batch_transaction_id IN (
      SELECT pc.batch_transaction_id
      FROM public.payment_confirmations pc
      WHERE pc.user_id = auth.uid()
        AND pc.batch_transaction_id IS NOT NULL
        AND pc.status = 'confirmed'
    )
  )
);
