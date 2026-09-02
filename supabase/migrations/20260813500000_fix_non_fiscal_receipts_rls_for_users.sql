-- Fix: Allow users to read non_fiscal_receipts linked to their payment_confirmations
-- Root cause: receipts are created by admin (created_by = admin_id), so users
-- cannot see them with the existing created_by = auth.uid() policy.
-- Solution: add a SELECT policy that allows users to read receipts whose
-- batch_transaction_id matches one of their confirmed payment_confirmations.

-- 1. Helper function: check if a receipt belongs to the current user
--    via their payment_confirmations (linked by batch_transaction_id)
CREATE OR REPLACE FUNCTION public.receipt_belongs_to_current_user(receipt_batch_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.payment_confirmations pc
    WHERE pc.user_id = auth.uid()
      AND pc.batch_transaction_id = receipt_batch_id
      AND pc.status = 'confirmed'
  )
$$;

-- 2. Drop existing user-facing SELECT policy if any, then recreate
DROP POLICY IF EXISTS "users_can_view_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_view_own_receipts" ON public.non_fiscal_receipts;

-- 3. New SELECT policy: user can read a receipt if:
--    (a) they created it (created_by = auth.uid()), OR
--    (b) it is linked to one of their confirmed payment_confirmations via batch_transaction_id
DROP POLICY IF EXISTS "users_read_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
CREATE POLICY "users_read_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid()
  OR (
    batch_transaction_id IS NOT NULL
    AND public.receipt_belongs_to_current_user(batch_transaction_id)
  )
);
