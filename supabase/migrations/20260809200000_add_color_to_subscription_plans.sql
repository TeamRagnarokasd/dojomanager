-- Add color column to custom_subscription_plans and subscription_plans
-- Stores the plan card color as an integer (ARGB hex value)

ALTER TABLE public.custom_subscription_plans
  ADD COLUMN IF NOT EXISTS color BIGINT DEFAULT NULL;

ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS color BIGINT DEFAULT NULL;

COMMENT ON COLUMN public.custom_subscription_plans.color IS 'Card color as ARGB integer (e.g. 0xFFFF5722). NULL = auto-computed from name.';
COMMENT ON COLUMN public.subscription_plans.color IS 'Card color as ARGB integer (e.g. 0xFFD32F2F). NULL = auto-computed from price/type.';
