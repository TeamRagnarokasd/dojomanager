-- ============================================================
-- CRITICAL FIX: check_user_has_annual_registration must use
-- beneficiary_profile_id, NOT user_id (payer).
--
-- Bug: The old function checked pc.user_id = v_user_id, which
-- means if the parent paid for the child, the parent was also
-- considered as having an annual registration. This allowed the
-- parent to bypass the enrollment gate.
--
-- Fix: Use the same beneficiary-aware filter as
-- get_user_subscription_dashboard:
--   beneficiary_profile_id = v_user_id
--   OR (beneficiary_profile_id IS NULL AND user_id = v_user_id)
--
-- The legacy fallback (IS NULL) only applies when the payment
-- has NO beneficiary set at all (old records before child
-- profiles existed). If beneficiary_profile_id IS explicitly
-- set to a child's ID, it NEVER counts for the parent.
-- ============================================================

DROP FUNCTION IF EXISTS public.check_user_has_annual_registration(UUID);

CREATE OR REPLACE FUNCTION public.check_user_has_annual_registration(
  p_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_has_annual BOOLEAN := FALSE;
BEGIN
  -- Use provided user_id or fall back to the calling user
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- STRICT BENEFICIARY CHECK:
  -- A payment counts for v_user_id ONLY if:
  --   1. beneficiary_profile_id = v_user_id  (explicitly assigned to this profile)
  --   2. OR beneficiary_profile_id IS NULL AND user_id = v_user_id
  --      (legacy row with no beneficiary set — payer is the beneficiary)
  --
  -- CRITICAL: If beneficiary_profile_id is set to someone ELSE's ID,
  -- this payment does NOT count for v_user_id, even if v_user_id is the payer.
  SELECT EXISTS (
    SELECT 1
    FROM public.payment_confirmations pc
    JOIN public.custom_subscription_plans csp
      ON csp.id = pc.custom_plan_id
    WHERE (
      pc.beneficiary_profile_id = v_user_id
      OR (pc.beneficiary_profile_id IS NULL AND pc.user_id = v_user_id)
    )
      AND pc.status = 'confirmed'
      AND pc.custom_plan_id IS NOT NULL
      AND (
        LOWER(csp.name) LIKE '%iscrizione annuale%'
        OR (LOWER(csp.name) LIKE '%iscrizione%' AND LOWER(csp.name) LIKE '%annuale%')
      )
  ) INTO v_has_annual;

  RETURN v_has_annual;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.check_user_has_annual_registration(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_user_has_annual_registration(UUID) TO anon;
