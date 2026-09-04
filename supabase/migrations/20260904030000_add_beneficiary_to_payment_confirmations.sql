-- Migration: Add beneficiary_profile_id and beneficiary_type to payment_confirmations
-- 
-- Purpose: Provide a structured reference to the actual beneficiary of each payment.
-- Previously, child purchases only stored the adult payer's user_id, with the child
-- reference living only as free text in non_fiscal_receipts.notes.
-- 
-- This migration:
--   1. Adds beneficiary_profile_id (uuid, nullable) — points to user_profiles.id for
--      adult purchases, or child_profiles.id for child purchases.
--   2. Adds beneficiary_type (text, nullable) — 'adult' or 'child'.
--   3. Backfills existing rows as beneficiary_type='adult', beneficiary_profile_id=user_id.
--   4. Drops and recreates create_payment_confirmation RPC with the two new parameters,
--      preserving ALL security patches from 20260904020000.
--
-- NOT touched: security patch logic (auth check, anon revoke), receipt numbering (MAX+1),
--   PDF generation/download, non_fiscal_receipts, buildMinorNote/notes field,
--   any other RPC/policy/trigger, admin receipts view.

-- ─── 1. Add new columns to payment_confirmations ─────────────────────────────
ALTER TABLE public.payment_confirmations
  ADD COLUMN IF NOT EXISTS beneficiary_profile_id uuid,
  ADD COLUMN IF NOT EXISTS beneficiary_type text;

-- ─── 2. Backfill existing rows: adult purchases ───────────────────────────────
-- All existing rows were adult purchases (child reference was only in notes text).
-- Set beneficiary_profile_id = user_id and beneficiary_type = 'adult'.
UPDATE public.payment_confirmations
SET
  beneficiary_profile_id = user_id,
  beneficiary_type = 'adult'
WHERE beneficiary_type IS NULL;

-- ─── 3. Index for efficient per-beneficiary queries ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_payment_confirmations_beneficiary_profile_id
  ON public.payment_confirmations (beneficiary_profile_id);

-- ─── 4. Drop and recreate create_payment_confirmation with new parameters ────
-- CASCADE safety: no triggers or views depend on this function (verified in
-- 20260904020000_security_patch_create_payment_confirmation.sql).
-- All security patches from 20260904020000 are preserved verbatim.
DROP FUNCTION IF EXISTS public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid
) CASCADE;

CREATE OR REPLACE FUNCTION public.create_payment_confirmation(
  p_user_id                uuid,
  p_amount                 numeric,
  p_payment_method         text,
  p_status                 text,
  p_confirmed_at           text,
  p_batch_transaction_id   text    DEFAULT NULL,
  p_custom_plan_id         uuid    DEFAULT NULL,
  p_subscription_plan_id   text    DEFAULT NULL,
  p_target_discipline      text    DEFAULT NULL,
  p_target_discipline_2    text    DEFAULT NULL,
  p_payer_id               uuid    DEFAULT NULL,
  p_beneficiary_profile_id uuid    DEFAULT NULL,
  p_beneficiary_type       text    DEFAULT NULL
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

  -- SECURITY PATCH 1 (preserved from 20260904020000):
  -- Caller must be either the payer (adult buying for a child) or the direct user.
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
    target_discipline_2,
    beneficiary_profile_id,
    beneficiary_type
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
    p_target_discipline_2,
    COALESCE(p_beneficiary_profile_id, v_insert_uid),
    COALESCE(p_beneficiary_type, 'adult')
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

-- Grant execute to authenticated users only
GRANT EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid, uuid, text
) TO authenticated;

-- SECURITY PATCH 2 (preserved from 20260904020000):
-- Revoke execute from anon role — defence-in-depth.
REVOKE EXECUTE ON FUNCTION public.create_payment_confirmation(
  uuid, numeric, text, text, text, text, uuid, text, text, text, uuid, uuid, text
) FROM anon;
