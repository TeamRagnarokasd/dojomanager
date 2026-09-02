-- Migration: Remove user DELETE permission on non_fiscal_receipts
-- Only admins should be able to delete receipts.
-- Users must NOT have the ability to delete receipts under any circumstance.

-- Drop the policy that allowed users to delete their own receipts
DROP POLICY IF EXISTS "users_delete_own_non_fiscal_receipts" ON public.non_fiscal_receipts;

-- Confirm: admin_full_access_non_fiscal_receipts (FOR ALL) already covers admin DELETE.
-- No new policies needed — admin retains full access via existing policy.
