-- ============================================================
-- FIX: User payment history access - complete rewrite
-- Problem: Users cannot see their own payment history because:
--   1. non_fiscal_receipts RLS policy relies on batch_transaction_id matching
--      but admin-created receipts may have different batch_transaction_id
--   2. payment_confirmations RLS may silently block queries
--   3. getSubscriptionStatus still queries old subscription_plans table
-- Solution: SECURITY DEFINER functions that bypass RLS for user's own data
-- ============================================================

-- ============================================================
-- FUNCTION 1: Get all payment confirmations for a user (bypasses RLS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_payment_confirmations(user_uuid UUID)
RETURNS TABLE(
  id UUID,
  user_id UUID,
  custom_plan_id UUID,
  payment_method TEXT,
  amount NUMERIC,
  status TEXT,
  confirmed_at TIMESTAMPTZ,
  batch_transaction_id TEXT,
  external_payment_id TEXT,
  plan_name TEXT,
  plan_type TEXT,
  duration_months INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Only allow users to query their own data
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Allow user to query their own data, or admin to query any user
  IF auth.uid() != user_uuid THEN
    -- Check if caller is admin
    IF NOT EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.id = auth.uid()
      AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
    ) THEN
      RAISE EXCEPTION 'Access denied';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    pc.id,
    pc.user_id,
    pc.custom_plan_id,
    pc.payment_method::TEXT,
    pc.amount,
    pc.status,
    pc.confirmed_at,
    pc.batch_transaction_id,
    pc.external_payment_id,
    COALESCE(csp.name, 'Piano Sconosciuto') AS plan_name,
    COALESCE(csp.plan_type, 'other') AS plan_type,
    COALESCE(csp.duration_months, 1) AS duration_months
  FROM public.payment_confirmations pc
  LEFT JOIN public.custom_subscription_plans csp ON csp.id = pc.custom_plan_id
  WHERE pc.user_id = user_uuid
    AND pc.status = 'confirmed'
    AND pc.custom_plan_id IS NOT NULL
  ORDER BY pc.confirmed_at DESC;
END;
$$;

-- ============================================================
-- FUNCTION 2: Get all non_fiscal_receipts for a user (bypasses RLS)
-- Finds receipts by: created_by = user_id OR batch_transaction_id matches user's payments
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_receipts(user_uuid UUID)
RETURNS TABLE(
  id UUID,
  receipt_number TEXT,
  description TEXT,
  amount NUMERIC,
  payment_method TEXT,
  status TEXT,
  issue_date DATE,
  created_at TIMESTAMPTZ,
  batch_transaction_id TEXT,
  customer_name TEXT,
  customer_tax_code TEXT,
  notes TEXT,
  fiscal_notes TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Only allow users to query their own data
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Allow user to query their own data, or admin to query any user
  IF auth.uid() != user_uuid THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.id = auth.uid()
      AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
    ) THEN
      RAISE EXCEPTION 'Access denied';
    END IF;
  END IF;

  RETURN QUERY
  SELECT DISTINCT
    nfr.id,
    nfr.receipt_number,
    nfr.description,
    nfr.amount,
    nfr.payment_method::TEXT,
    nfr.status,
    nfr.issue_date,
    nfr.created_at,
    nfr.batch_transaction_id,
    nfr.customer_name,
    nfr.customer_tax_code,
    nfr.notes,
    nfr.fiscal_notes
  FROM public.non_fiscal_receipts nfr
  WHERE
    -- Receipt created directly for this user
    nfr.created_by = user_uuid
    OR
    -- Receipt linked via batch_transaction_id to user's payment_confirmations
    (
      nfr.batch_transaction_id IS NOT NULL
      AND nfr.batch_transaction_id IN (
        SELECT pc.batch_transaction_id
        FROM public.payment_confirmations pc
        WHERE pc.user_id = user_uuid
          AND pc.status = 'confirmed'
          AND pc.batch_transaction_id IS NOT NULL
      )
    )
    OR
    -- Receipt notes/fiscal_notes contain user's payment confirmation IDs
    (
      nfr.fiscal_notes IS NOT NULL
      AND nfr.fiscal_notes IN (
        SELECT 'Payment confirmation ID: ' || pc.id::TEXT
        FROM public.payment_confirmations pc
        WHERE pc.user_id = user_uuid
          AND pc.status = 'confirmed'
      )
    )
  ORDER BY nfr.created_at DESC;
END;
$$;

-- ============================================================
-- FUNCTION 3: Get subscription dashboard data for a user (bypasses RLS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_subscription_dashboard(user_uuid UUID)
RETURNS TABLE(
  has_annual_registration BOOLEAN,
  annual_expiry_date DATE,
  current_plan_name TEXT,
  current_plan_confirmed_at TIMESTAMPTZ,
  current_plan_duration_months INTEGER,
  has_active_subscription BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  IF auth.uid() != user_uuid THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.id = auth.uid()
      AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
    ) THEN
      RAISE EXCEPTION 'Access denied';
    END IF;
  END IF;

  RETURN QUERY
  WITH user_payments AS (
    SELECT
      pc.id,
      pc.confirmed_at,
      pc.custom_plan_id,
      csp.name AS plan_name,
      csp.duration_months,
      LOWER(csp.name) LIKE '%iscrizione%' OR LOWER(csp.name) LIKE '%annuale%' AS is_annual
    FROM public.payment_confirmations pc
    JOIN public.custom_subscription_plans csp ON csp.id = pc.custom_plan_id
    WHERE pc.user_id = user_uuid
      AND pc.status = 'confirmed'
      AND pc.custom_plan_id IS NOT NULL
    ORDER BY pc.confirmed_at DESC
  ),
  annual_check AS (
    SELECT
      COUNT(*) > 0 AS has_annual,
      MAX(confirmed_at) AS latest_annual_at
    FROM user_payments
    WHERE is_annual = TRUE
  ),
  latest_non_annual AS (
    SELECT plan_name, confirmed_at, duration_months
    FROM user_payments
    WHERE is_annual = FALSE
    ORDER BY confirmed_at DESC
    LIMIT 1
  )
  SELECT
    ac.has_annual,
    CASE
      WHEN ac.has_annual THEN
        CASE
          WHEN CURRENT_DATE <= DATE(EXTRACT(YEAR FROM CURRENT_DATE) || '-08-28')
          THEN DATE(EXTRACT(YEAR FROM CURRENT_DATE) || '-08-28')
          ELSE DATE((EXTRACT(YEAR FROM CURRENT_DATE) + 1)::INT || '-08-28')
        END
      ELSE NULL
    END AS annual_expiry_date,
    COALESCE(lna.plan_name, 'Nessun abbonamento attivo') AS current_plan_name,
    lna.confirmed_at AS current_plan_confirmed_at,
    COALESCE(lna.duration_months, 1) AS current_plan_duration_months,
    (lna.plan_name IS NOT NULL) AS has_active_subscription
  FROM annual_check ac
  LEFT JOIN latest_non_annual lna ON TRUE;
END;
$$;

-- ============================================================
-- Ensure RLS policies are correct on payment_confirmations
-- ============================================================
ALTER TABLE public.payment_confirmations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_payment_confirmations" ON public.payment_confirmations;
CREATE POLICY "users_read_own_payment_confirmations"
ON public.payment_confirmations
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- ============================================================
-- Ensure RLS policies are correct on non_fiscal_receipts
-- ============================================================
ALTER TABLE public.non_fiscal_receipts ENABLE ROW LEVEL SECURITY;

-- Drop all existing user-facing SELECT policies
DROP POLICY IF EXISTS "users_can_view_own_non_fiscal_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_view_own_receipts" ON public.non_fiscal_receipts;
DROP POLICY IF EXISTS "users_read_own_non_fiscal_receipts" ON public.non_fiscal_receipts;

-- Recreate the helper function (idempotent)
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

-- New comprehensive SELECT policy
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
