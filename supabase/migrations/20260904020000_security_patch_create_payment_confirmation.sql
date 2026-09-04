-- SECURITY PATCH: create_payment_confirmation RPC
--
-- Changes applied (3 only — nothing else touched):
--   1. Caller authorization check: caller must be p_payer_id OR p_user_id
--   2. REVOKE EXECUTE from anon role
--   3. CASCADE safety: this function has no dependent triggers or views —
--      DROP ... CASCADE is safe (verified by searching all migrations and
--      confirming no trigger/view references create_payment_confirmation).
--
-- NOT touched: receipt numbering (MAX+1), PDF generation/download,
--   non_fiscal_receipts, buildMinorNote/notes field, any other RPC/policy/trigger,
--   function parameter schema, frontend files.

-- ─── Drop and recreate with caller authorization check ───────────────────────
-- CASCADE safety note: no triggers or views depend on this function.
-- The only callers are authenticated Flutter clients via supabase.rpc().
DROP FUNCTION IF EXISTS public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) CASCADE;

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

  -- SECURITY PATCH 1: Caller authorization check.
  -- The caller must be either the payer (adult buying for a child) or the direct user.
  -- This prevents an authenticated user from creating payment confirmations on behalf
  -- of arbitrary other users.
  IF v_caller_id != COALESCE(p_payer_id, p_user_id) THEN
    RAISE EXCEPTION 'Not authorized to create confirmation for this user';
  END IF;

  -- Determine which user_id to store in payment_confirmations.
  -- For child-profile purchases p_payer_id (the adult) is passed; use it so the
  -- FK to user_profiles is satisfied. Fall back to p_user_id otherwise.
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

-- Grant execute to authenticated users only
GRANT EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) TO authenticated;

-- SECURITY PATCH 2: Revoke execute from anon role.
-- Unauthenticated callers are already rejected by the v_caller_id IS NULL check above,
-- but removing the grant is defence-in-depth.
REVOKE EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) FROM anon;
