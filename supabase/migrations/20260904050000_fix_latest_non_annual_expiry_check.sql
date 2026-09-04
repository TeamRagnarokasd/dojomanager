-- ============================================================
-- Fix get_user_subscription_dashboard: add expiry check to
-- latest_non_annual CTE so only non-expired plans are returned.
-- This makes badge, iscrizione and piano attuale consistent.
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
    WHERE (
      pc.beneficiary_profile_id = user_uuid
      OR (pc.beneficiary_profile_id IS NULL AND pc.user_id = user_uuid)
    )
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
      AND confirmed_at + (COALESCE(duration_months, 1) * INTERVAL '1 month') > NOW()
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
    COALESCE(lna.plan_name, '') AS current_plan_name,
    lna.confirmed_at AS current_plan_confirmed_at,
    COALESCE(lna.duration_months, 1) AS current_plan_duration_months,
    (lna.plan_name IS NOT NULL) AS has_active_subscription
  FROM annual_check ac
  LEFT JOIN latest_non_annual lna ON TRUE;
END;
$$;
