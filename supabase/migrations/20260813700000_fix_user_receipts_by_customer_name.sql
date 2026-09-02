-- Migration: Fix user payment history to show receipts by customer_name match
-- The admin creates receipts with customer_name = user's full_name
-- This function fetches those receipts for the user using SECURITY DEFINER to bypass RLS

-- Function: get_receipts_for_user
-- Returns all non_fiscal_receipts where customer_name matches the user's full_name
-- OR where batch_transaction_id matches one of the user's payment_confirmations
CREATE OR REPLACE FUNCTION public.get_receipts_for_user(user_uuid UUID)
RETURNS TABLE(
  id UUID,
  receipt_number TEXT,
  issue_date DATE,
  customer_name TEXT,
  customer_tax_code TEXT,
  customer_address TEXT,
  description TEXT,
  amount NUMERIC,
  quantity INTEGER,
  unit_price NUMERIC,
  discount_percentage NUMERIC,
  vat_rate TEXT,
  vat_amount NUMERIC,
  payment_method TEXT,
  status TEXT,
  notes TEXT,
  fiscal_notes TEXT,
  batch_transaction_id TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_full_name TEXT;
BEGIN
  -- Get the user's full name
  SELECT up.full_name INTO user_full_name
  FROM public.user_profiles up
  WHERE up.id = user_uuid
  LIMIT 1;

  -- Return receipts matching by customer_name OR by batch_transaction_id via payment_confirmations
  RETURN QUERY
  SELECT
    r.id,
    r.receipt_number,
    r.issue_date,
    r.customer_name,
    r.customer_tax_code,
    r.customer_address,
    r.description,
    r.amount,
    r.quantity,
    r.unit_price,
    r.discount_percentage,
    r.vat_rate::TEXT,
    r.vat_amount,
    r.payment_method::TEXT,
    r.status,
    r.notes,
    r.fiscal_notes,
    r.batch_transaction_id,
    r.created_by,
    r.created_at,
    r.updated_at
  FROM public.non_fiscal_receipts r
  WHERE
    -- Match by customer_name (admin fills this with user's full name)
    (user_full_name IS NOT NULL AND r.customer_name ILIKE user_full_name)
    OR
    -- Match by batch_transaction_id linked to user's payment_confirmations
    (r.batch_transaction_id IS NOT NULL AND r.batch_transaction_id IN (
      SELECT pc.batch_transaction_id
      FROM public.payment_confirmations pc
      WHERE pc.user_id = user_uuid
        AND pc.batch_transaction_id IS NOT NULL
        AND pc.status = 'confirmed'
    ))
    OR
    -- Match by created_by = user_uuid (receipts created directly by the user)
    r.created_by = user_uuid
  ORDER BY r.issue_date DESC, r.created_at DESC;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_receipts_for_user(UUID) TO authenticated;

-- Also update the RLS policy on non_fiscal_receipts to allow users to read their own receipts
-- Drop old policies first
DROP POLICY IF EXISTS "users_read_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "admin_full_access_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_can_read_own_receipts" ON public.non_fiscal_receipts;

-- Admin full access
CREATE POLICY "admin_full_access_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid()
    AND (
      au.raw_user_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
      OR au.raw_app_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid()
    AND (
      au.raw_user_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
      OR au.raw_app_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
    )
  )
);

-- Users can read receipts that belong to them (by created_by or batch_transaction_id)
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
);
