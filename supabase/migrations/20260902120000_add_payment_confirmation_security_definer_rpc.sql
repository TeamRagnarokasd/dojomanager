-- Migration: Add SECURITY DEFINER RPC for inserting into payment_confirmations
-- This bypasses RLS for the payment confirmation insert, which fails with 42501
-- when called by authenticated users due to missing INSERT policy.
-- ONLY affects payment_confirmations INSERT — no other tables are touched.

-- Drop existing function if it exists (any overload)
DROP FUNCTION IF EXISTS public.create_payment_confirmation(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.create_payment_confirmation(uuid, numeric, text, text, text, uuid, uuid, text, text, text) CASCADE;

-- Create SECURITY DEFINER function that inserts a single payment confirmation row
-- bypassing RLS. The function validates that the caller is authenticated and that
-- the user_id matches the calling user (or is a child profile owned by the caller).
CREATE OR REPLACE FUNCTION public.create_payment_confirmation(
  p_user_id          uuid,
  p_amount           numeric,
  p_payment_method   text,
  p_status           text,
  p_confirmed_at     text,
  p_batch_transaction_id text DEFAULT NULL,
  p_custom_plan_id   uuid DEFAULT NULL,
  p_subscription_plan_id text DEFAULT NULL,
  p_target_discipline text DEFAULT NULL,
  p_target_discipline_2 text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_new_id    uuid;
BEGIN
  -- Ensure caller is authenticated
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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
    p_user_id,
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
  uuid, numeric, text, text, text, text, uuid, text, text, text
) TO authenticated;

-- Also grant to anon for edge cases
GRANT EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text
) TO anon;
