-- Migration: Fix payment_confirmations foreign key constraint
-- Problem: payment_confirmations.subscription_plan_id has a FK pointing to
--          subscription_plans, but the app stores IDs from custom_subscription_plans.
-- Fix: Drop the incorrect FK constraint so the column can hold custom plan IDs.
--      Add a separate custom_plan_id column with the correct FK reference.

-- Step 1: Drop the incorrect FK constraint
ALTER TABLE public.payment_confirmations
DROP CONSTRAINT IF EXISTS payment_confirmations_subscription_plan_id_fkey;

-- Step 2: Add a new custom_plan_id column that correctly references custom_subscription_plans
ALTER TABLE public.payment_confirmations
ADD COLUMN IF NOT EXISTS custom_plan_id UUID REFERENCES public.custom_subscription_plans(id) ON DELETE SET NULL;

-- Step 3: Migrate existing data — copy subscription_plan_id values to custom_plan_id
-- for rows where the subscription_plan_id matches a custom_subscription_plans id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'payment_confirmations'
          AND column_name = 'custom_plan_id'
    ) THEN
        UPDATE public.payment_confirmations pc
        SET custom_plan_id = pc.subscription_plan_id
        WHERE pc.subscription_plan_id IS NOT NULL
          AND EXISTS (
              SELECT 1 FROM public.custom_subscription_plans csp
              WHERE csp.id = pc.subscription_plan_id
          );
    END IF;
END $$;

-- Step 4: Add index for performance
CREATE INDEX IF NOT EXISTS idx_payment_confirmations_custom_plan_id
ON public.payment_confirmations(custom_plan_id);

COMMENT ON COLUMN public.payment_confirmations.custom_plan_id IS
'References the custom_subscription_plans plan purchased. Replaces the incorrect subscription_plan_id FK.';
