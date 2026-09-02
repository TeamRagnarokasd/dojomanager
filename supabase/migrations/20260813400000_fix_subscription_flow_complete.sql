-- ============================================================
-- FIX: Complete subscription flow rewrite
-- 1. Add custom_plan_id to user_subscriptions (no FK to old subscription_plans)
-- 2. Cleanup orphan payment_confirmations with no custom_plan_id (Piano Sconosciuto)
-- 3. Cleanup orphan user_subscriptions with no valid plan reference
-- ============================================================

-- Step 1: Add custom_plan_id column to user_subscriptions if not present
ALTER TABLE public.user_subscriptions
ADD COLUMN IF NOT EXISTS custom_plan_id UUID REFERENCES public.custom_subscription_plans(id) ON DELETE SET NULL;

-- Step 2: Create index for fast lookup
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_custom_plan_id
  ON public.user_subscriptions(custom_plan_id);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id_active
  ON public.user_subscriptions(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_payment_confirmations_user_status
  ON public.payment_confirmations(user_id, status);

CREATE INDEX IF NOT EXISTS idx_payment_confirmations_custom_plan
  ON public.payment_confirmations(custom_plan_id);

-- Step 3: Cleanup old payment_confirmations that have NO custom_plan_id
-- (these are from the old hardcoded plans and cause "Piano Sconosciuto")
DO $$
BEGIN
  -- Delete non_fiscal_receipts linked to old payment_confirmations first
  DELETE FROM public.non_fiscal_receipts
  WHERE batch_transaction_id IN (
    SELECT batch_transaction_id
    FROM public.payment_confirmations
    WHERE custom_plan_id IS NULL
      AND batch_transaction_id IS NOT NULL
  );

  -- Delete old payment_confirmations with no custom_plan_id
  DELETE FROM public.payment_confirmations
  WHERE custom_plan_id IS NULL;

  RAISE NOTICE 'Cleanup of old plan purchases completed';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Cleanup encountered an issue: %', SQLERRM;
END $$;

-- Step 4: Cleanup user_subscriptions that reference subscription_plans (old table)
-- but have no corresponding custom_plan_id — these are orphaned
DO $$
BEGIN
  DELETE FROM public.user_subscriptions
  WHERE custom_plan_id IS NULL;

  RAISE NOTICE 'Cleanup of orphaned user_subscriptions completed';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'user_subscriptions cleanup encountered an issue: %', SQLERRM;
END $$;

-- Step 5: Backfill custom_plan_id in user_subscriptions from payment_confirmations
-- where the batch_transaction_id matches
DO $$
BEGIN
  UPDATE public.user_subscriptions us
  SET custom_plan_id = pc.custom_plan_id
  FROM public.payment_confirmations pc
  WHERE pc.user_id = us.user_id
    AND pc.custom_plan_id IS NOT NULL
    AND us.custom_plan_id IS NULL
    AND pc.status = 'confirmed';

  RAISE NOTICE 'Backfill of custom_plan_id in user_subscriptions completed';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Backfill encountered an issue: %', SQLERRM;
END $$;
