-- Add duration_months column to subscription_plans and custom_subscription_plans
-- This allows admins to specify 1, 2, or 3 month duration when creating monthly plans

-- Add to standard subscription_plans
ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS duration_months INTEGER NOT NULL DEFAULT 1;

-- Add to custom_subscription_plans
ALTER TABLE public.custom_subscription_plans
  ADD COLUMN IF NOT EXISTS duration_months INTEGER NOT NULL DEFAULT 1;

-- Update existing monthly plans to have duration_months = 1 (already the default, but explicit)
UPDATE public.subscription_plans
  SET duration_months = 1
  WHERE plan_type = 'monthly' AND duration_months IS NULL;

UPDATE public.custom_subscription_plans
  SET duration_months = 1
  WHERE duration_months IS NULL;
