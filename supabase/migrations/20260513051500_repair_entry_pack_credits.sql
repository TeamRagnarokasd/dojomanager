-- Migration: Repair entry-based user_subscriptions broken by the
-- italian_receipt_service.activateSubscriptionForUser bug.
--
-- Root cause (now fixed in code): when an admin issued a receipt to activate
-- a Pack / Input Credit plan for a member, the user_subscriptions row was
-- inserted WITHOUT entries_remaining / entries_total. The columns default to
-- 0 (see 20250902131000_entry_based_subscription_plans.sql), so the booking
-- eligibility check (entries_remaining > 0) refused every booking attempt
-- even though the receipt and payment_confirmation looked correct.
--
-- This migration retroactively backfills entries_remaining / entries_total
-- for every active entry-based subscription that was created with zero
-- credits, using the plan's entry_count. It also clears the spurious
-- 365-day expires_at that was set on entry packs (they should not time-out
-- — only the credit countdown applies).
--
-- The fix is intentionally conservative:
--   * only touches rows where entries_total = 0 (i.e. never initialised),
--   * only touches active rows,
--   * never decreases an existing positive entries_remaining.

-- ── multi_entry packs (e.g. "Pacchetto 10 ingressi") ─────────────────────
UPDATE public.user_subscriptions us
SET entries_total     = COALESCE(sp.entry_count, 0),
    entries_remaining = GREATEST(
        COALESCE(us.entries_remaining, 0),
        COALESCE(sp.entry_count, 0)
    ),
    expires_at        = NULL,
    updated_at        = CURRENT_TIMESTAMP
FROM public.subscription_plans sp
WHERE us.subscription_plan_id = sp.id
  AND sp.plan_type = 'multi_entry'
  AND us.is_active = true
  AND COALESCE(us.entries_total, 0) = 0
  AND COALESCE(sp.entry_count, 0) > 0;

-- ── single_entry passes (1-credit single class) ──────────────────────────
UPDATE public.user_subscriptions us
SET entries_total     = 1,
    entries_remaining = GREATEST(COALESCE(us.entries_remaining, 0), 1),
    expires_at        = NULL,
    updated_at        = CURRENT_TIMESTAMP
FROM public.subscription_plans sp
WHERE us.subscription_plan_id = sp.id
  AND sp.plan_type = 'single_entry'
  AND us.is_active = true
  AND COALESCE(us.entries_total, 0) = 0;

-- ── Sanity log ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_multi  INTEGER;
    v_single INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_multi
    FROM public.user_subscriptions us
    JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
    WHERE sp.plan_type = 'multi_entry'
      AND us.is_active = true
      AND us.entries_remaining > 0;

    SELECT COUNT(*) INTO v_single
    FROM public.user_subscriptions us
    JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
    WHERE sp.plan_type = 'single_entry'
      AND us.is_active = true
      AND us.entries_remaining > 0;

    RAISE NOTICE 'Entry-pack repair complete: % active multi_entry / % active single_entry rows now have remaining credits.', v_multi, v_single;
END
$$;
