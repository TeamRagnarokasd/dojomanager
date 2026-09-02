-- Migration: Add SECURITY DEFINER function to check annual registration
-- This function bypasses all RLS complexity and runs server-side.
-- It is the single source of truth for the enrollment gate.
-- Called via RPC from Flutter: PaymentService.checkHasAnnualRegistration()

-- Drop existing function if any previous version exists
DROP FUNCTION IF EXISTS public.check_user_has_annual_registration(UUID);

-- Create the function with SECURITY DEFINER so it bypasses RLS
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

  -- Check payment_confirmations for a confirmed annual registration
  -- Joins to custom_subscription_plans to verify the plan name
  SELECT EXISTS (
    SELECT 1
    FROM public.payment_confirmations pc
    JOIN public.custom_subscription_plans csp
      ON csp.id = pc.custom_plan_id
    WHERE pc.user_id = v_user_id
      AND pc.status = 'confirmed'
      AND pc.custom_plan_id IS NOT NULL
      AND (
        LOWER(csp.name) LIKE '%iscrizione annuale%'
        OR LOWER(csp.name) LIKE '%iscrizione%annuale%'
      )
  ) INTO v_has_annual;

  RETURN v_has_annual;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.check_user_has_annual_registration(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_user_has_annual_registration(UUID) TO anon;
