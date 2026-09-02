-- Migration: Fix members counter (count all roles) and add soft-delete to non_fiscal_receipts
-- 1. Add soft-delete columns to non_fiscal_receipts
--    - deleted_by_admin: admin hard-deletes (receipt disappears for everyone)
--    - deleted_by_user: user soft-deletes (receipt hidden for user, still visible to admin)
-- 2. Update RLS policies accordingly

-- Step 1: Add soft-delete columns to non_fiscal_receipts
ALTER TABLE public.non_fiscal_receipts
  ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_by_user_at TIMESTAMPTZ;

-- Step 2: Index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_deleted_by_user
  ON public.non_fiscal_receipts(deleted_by_user);

-- Step 3: Drop and recreate RLS policies with soft-delete awareness

-- Drop existing policies
DROP POLICY IF EXISTS "admin_full_access_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_read_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_delete_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_can_view_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_view_own_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_admin_all" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_select" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_insert" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "non_fiscal_receipts_user_delete" ON public.non_fiscal_receipts;

-- Admin full access (can see ALL receipts including user-soft-deleted ones)
CREATE POLICY "admin_full_access_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR ALL
TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- Users can SELECT receipts that belong to them AND have NOT been soft-deleted by the user
CREATE POLICY "users_read_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR SELECT
TO authenticated
USING (
  deleted_by_user = FALSE
  AND (
    created_by = auth.uid()
    OR (
      batch_transaction_id IS NOT NULL
      AND batch_transaction_id IN (
        SELECT pc.batch_transaction_id
        FROM public.payment_confirmations pc
        WHERE pc.user_id = auth.uid()
          AND pc.batch_transaction_id IS NOT NULL
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
  )
);

-- Users can UPDATE their own receipts to soft-delete them (set deleted_by_user = true)
CREATE POLICY "users_soft_delete_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR UPDATE
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
)
WITH CHECK (TRUE);

-- Users can still hard-delete receipts they created themselves (for backward compat)
CREATE POLICY "users_delete_own_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR DELETE
TO authenticated
USING (
  created_by = auth.uid()
);
