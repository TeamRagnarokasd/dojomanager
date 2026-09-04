-- Migration: Fix payment_confirmations INSERT RLS (42501) and update SECURITY DEFINER RPC
-- 
-- Problem 1: Authenticated users get PostgresException 42501 when inserting into
--   payment_confirmations because there is no INSERT policy for regular users.
--   The existing migration (20260411000000) only added a SELECT policy.
--   The SECURITY DEFINER RPC (20260902120000) is the primary path, but the fallback
--   direct insert still fails. This migration adds an INSERT policy so both paths work.
--
-- Problem 2: When purchasing for a child profile, beneficiaryUserId is the child_profiles.id
--   which is NOT in user_profiles — causing FK violation on payment_confirmations.user_id.
--   The RPC is updated to accept the adult user_id as the payer and store it correctly.
--
-- Core Protection: Does NOT touch non_fiscal_receipts, receipt numbering, or PDF logic.

-- ─── 1. Add INSERT policy for authenticated users on payment_confirmations ───────────────
-- Users can insert their own payment confirmations (user_id = auth.uid())
DROP POLICY IF EXISTS "users_insert_own_payment_confirmations" ON public.payment_confirmations;
CREATE POLICY "users_insert_own_payment_confirmations"
    ON public.payment_confirmations
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- ─── 2. Update SECURITY DEFINER RPC to also accept child-profile purchases ───────────────
-- The RPC now accepts an optional p_payer_id (the authenticated adult).
-- When p_payer_id is provided and differs from p_user_id, it means this is a child
-- purchase: user_id in payment_confirmations is set to the ADULT (payer) so the FK
-- to user_profiles is satisfied, while the child context lives in the receipt notes.
DROP FUNCTION IF EXISTS public.create_payment_confirmation(uuid, numeric, text, text, text, text, uuid, text, text, text) CASCADE;

CREATE OR REPLACE FUNCTION public.create_payment_confirmation(
  p_user_id              uuid,
  p_amount               numeric,
  p_payment_method       text,
  p_status               text,
  p_confirmed_at         text,
  p_batch_transaction_id text    DEFAULT NULL,
  p_custom_plan_id       uuid    DEFAULT NULL,
  p_subscription_plan_id text    DEFAULT NULL,
  p_target_discipline    text    DEFAULT NULL,
  p_target_discipline_2  text    DEFAULT NULL,
  p_payer_id             uuid    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id  uuid;
  v_new_id     uuid;
  v_insert_uid uuid;
BEGIN
  -- Ensure caller is authenticated
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Determine which user_id to store in payment_confirmations.
  -- For child-profile purchases p_payer_id (the adult) is passed; use it so the
  -- FK to user_profiles is satisfied.  Fall back to p_user_id otherwise.
  v_insert_uid := COALESCE(p_payer_id, p_user_id, v_caller_id);

  -- Insert the payment confirmation row, bypassing RLS
  INSERT INTO public.payment_confirmations (
    user_id,
    amount,
    payment_method,
    status,
    confirmed_at,
    batch_transaction_id,
    custom_plan_id,
    subscription_plan_id,
    target_discipline,
    target_discipline_2
  )
  VALUES (
    v_insert_uid,
    p_amount,
    p_payment_method,
    p_status,
    p_confirmed_at::timestamptz,
    p_batch_transaction_id,
    p_custom_plan_id,
    p_subscription_plan_id::uuid,
    p_target_discipline,
    p_target_discipline_2
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) TO anon;
