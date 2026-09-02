-- ============================================================
-- Cleanup: Remove purchases/receipts from old hardcoded plans
-- These are payment_confirmations where:
--   - custom_plan_id IS NULL (no link to custom_subscription_plans)
--   - subscription_plan_id references subscription_plans (old table)
--   - The plan no longer exists or is not in custom_subscription_plans
-- These appear as "Piano Sconosciuto" in the profile.
-- ============================================================

-- Step 1: Collect batch_transaction_ids of orphaned payment_confirmations
-- (those with no custom_plan_id and no valid subscription_plans reference,
--  OR those whose subscription_plan_id points to a plan that is not
--  mirrored in custom_subscription_plans)
DO $$
DECLARE
  orphaned_batch_ids TEXT[];
BEGIN
  -- Collect batch_transaction_ids from payment_confirmations that have
  -- no custom_plan_id (old flow) and whose subscription_plan_id either
  -- is NULL or references a plan whose name does NOT appear in custom_subscription_plans.
  SELECT ARRAY_AGG(DISTINCT pc.batch_transaction_id)
  INTO orphaned_batch_ids
  FROM payment_confirmations pc
  WHERE pc.custom_plan_id IS NULL
    AND pc.batch_transaction_id IS NOT NULL
    AND (
      pc.subscription_plan_id IS NULL
      OR NOT EXISTS (
        SELECT 1
        FROM subscription_plans sp
        JOIN custom_subscription_plans csp
          ON LOWER(TRIM(csp.name)) = LOWER(TRIM(sp.name))
        WHERE sp.id = pc.subscription_plan_id
      )
    );

  -- Step 2: Delete non_fiscal_receipts linked to those batch_transaction_ids
  IF orphaned_batch_ids IS NOT NULL AND array_length(orphaned_batch_ids, 1) > 0 THEN
    DELETE FROM non_fiscal_receipts
    WHERE batch_transaction_id = ANY(orphaned_batch_ids);

    RAISE NOTICE 'Deleted non_fiscal_receipts for % orphaned batch transactions', array_length(orphaned_batch_ids, 1);
  END IF;
END $$;

-- Step 3: Delete orphaned payment_confirmations directly
-- (custom_plan_id IS NULL AND subscription_plan_id not mirrored in custom_subscription_plans)
DELETE FROM payment_confirmations
WHERE custom_plan_id IS NULL
  AND (
    subscription_plan_id IS NULL
    OR NOT EXISTS (
      SELECT 1
      FROM subscription_plans sp
      JOIN custom_subscription_plans csp
        ON LOWER(TRIM(csp.name)) = LOWER(TRIM(sp.name))
      WHERE sp.id = payment_confirmations.subscription_plan_id
    )
  );

-- Step 4: Also delete non_fiscal_receipts that have no matching custom plan
-- (standalone receipts not linked to any payment_confirmation,
--  where the description doesn't match any custom_subscription_plans name)
-- These are receipts from the old entry-package system (e.g. "Pacchetto Ingressi")
-- that no longer have a corresponding plan in custom_subscription_plans.
DELETE FROM non_fiscal_receipts
WHERE id NOT IN (
  -- Keep receipts that are linked to a valid payment_confirmation
  SELECT DISTINCT nfr.id
  FROM non_fiscal_receipts nfr
  JOIN payment_confirmations pc
    ON pc.batch_transaction_id = nfr.batch_transaction_id
  WHERE pc.custom_plan_id IS NOT NULL
)
AND id NOT IN (
  -- Keep receipts whose description matches a custom plan name
  SELECT DISTINCT nfr.id
  FROM non_fiscal_receipts nfr
  JOIN custom_subscription_plans csp
    ON LOWER(nfr.description) LIKE '%' || LOWER(TRIM(csp.name)) || '%'
)
AND id NOT IN (
  -- Keep receipts that contain 'iscrizione annuale' (annual registration)
  SELECT id FROM non_fiscal_receipts
  WHERE LOWER(description) LIKE '%iscrizione annuale%'
);
