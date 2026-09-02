-- Add is_convenzione boolean column to custom_subscription_plans
ALTER TABLE public.custom_subscription_plans
ADD COLUMN IF NOT EXISTS is_convenzione BOOLEAN NOT NULL DEFAULT false;

-- Index for fast filtering
CREATE INDEX IF NOT EXISTS idx_custom_subscription_plans_is_convenzione
ON public.custom_subscription_plans(is_convenzione);
