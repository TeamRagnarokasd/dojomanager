-- Migration: Rewrite check_class_booking_eligibility from scratch
-- Root cause of previous failure: the function was joining payment_confirmations
-- on pc.subscription_plan_id = csp.id, but the correct column is pc.custom_plan_id.
-- Migration 20260813200000 added custom_plan_id as the dedicated FK to custom_subscription_plans,
-- but the eligibility function never used it.
--
-- Design principle: There is only ONE type of plan — plans created by the admin
-- in custom_subscription_plans. The old subscription_plans table is legacy and
-- must NOT be used for discipline-based booking eligibility checks.
-- All discipline associations are stored in discipline_custom_plan_associations.

CREATE OR REPLACE FUNCTION public.check_class_booking_eligibility(
    p_user_id uuid,
    p_schedule_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_class_discipline    TEXT;
    v_payment_record      RECORD;
    v_plan_linked         BOOLEAN;
BEGIN
    -- ── Get discipline of the requested class ──────────────────────────────
    SELECT discipline::TEXT INTO v_class_discipline
    FROM public.schedule_instances
    WHERE id = p_schedule_instance_id;

    IF v_class_discipline IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'reason',  'Classe non trovata.'
        );
    END IF;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 1: ENTRY-BASED PACKAGES (single_entry / multi_entry)
    -- These are legacy entry packs stored in user_subscriptions.
    -- Rule: entries_remaining > 0 is sufficient (no expiry check needed).
    -- ══════════════════════════════════════════════════════════════════════
    IF EXISTS (
        SELECT 1
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND sp.plan_type IN ('single_entry', 'multi_entry')
          AND us.entries_remaining > 0
    ) THEN
        RETURN jsonb_build_object(
            'allowed',      TRUE,
            'reason',       NULL,
            'booking_type', 'entry_based'
        );
    END IF;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 2: PAYMENT CONFIRMATIONS linked to CUSTOM PLANS
    -- Uses pc.custom_plan_id (the correct FK column added in migration 20260813200000).
    -- Checks discipline_custom_plan_associations for the discipline link.
    -- Annual plans are excluded — they are global prerequisites, not discipline-specific.
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_payment_record IN
        SELECT
            pc.id            AS confirmation_id,
            pc.custom_plan_id,
            csp.name         AS plan_name,
            pc.target_discipline
        FROM public.payment_confirmations pc
        JOIN public.custom_subscription_plans csp
          ON pc.custom_plan_id = csp.id
        WHERE pc.user_id = p_user_id
          AND pc.status IN ('confirmed', 'paid')
          AND (pc.expires_at IS NULL OR pc.expires_at > NOW())
          -- Exclude annual plans from discipline-specific checks
          AND LOWER(csp.name) NOT LIKE '%annuale%'
          AND LOWER(csp.name) NOT LIKE '%annual%'
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_linked := FALSE;

        -- Check if this custom plan is associated with the class discipline
        SELECT EXISTS (
            SELECT 1
            FROM public.discipline_custom_plan_associations dcpa
            WHERE dcpa.custom_plan_id = v_payment_record.custom_plan_id
              AND LOWER(dcpa.discipline_name) = LOWER(v_class_discipline)
        ) INTO v_plan_linked;

        IF v_plan_linked THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;

        -- Fallback: explicit target_discipline match on the payment confirmation
        IF LOWER(COALESCE(v_payment_record.target_discipline, '')) = LOWER(v_class_discipline) THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;

        -- Grappling is open to anyone with any valid non-annual custom plan payment
        IF LOWER(v_class_discipline) = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 3: PAYMENT CONFIRMATIONS with subscription_plan_id only
    -- (legacy rows where custom_plan_id was not yet populated)
    -- Try to match via discipline_custom_plan_associations using subscription_plan_id
    -- as a fallback in case the data migration in 20260813200000 was incomplete.
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_payment_record IN
        SELECT
            pc.id                  AS confirmation_id,
            pc.subscription_plan_id,
            pc.target_discipline,
            csp.id                 AS resolved_custom_plan_id,
            csp.name               AS plan_name
        FROM public.payment_confirmations pc
        JOIN public.custom_subscription_plans csp
          ON csp.id = pc.subscription_plan_id
        WHERE pc.user_id = p_user_id
          AND pc.status IN ('confirmed', 'paid')
          AND (pc.expires_at IS NULL OR pc.expires_at > NOW())
          AND pc.custom_plan_id IS NULL  -- only rows not yet migrated
          AND LOWER(csp.name) NOT LIKE '%annuale%'
          AND LOWER(csp.name) NOT LIKE '%annual%'
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_linked := FALSE;

        SELECT EXISTS (
            SELECT 1
            FROM public.discipline_custom_plan_associations dcpa
            WHERE dcpa.custom_plan_id = v_payment_record.resolved_custom_plan_id
              AND LOWER(dcpa.discipline_name) = LOWER(v_class_discipline)
        ) INTO v_plan_linked;

        IF v_plan_linked THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation_legacy',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;

        IF LOWER(COALESCE(v_payment_record.target_discipline, '')) = LOWER(v_class_discipline) THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation_legacy',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;

        IF LOWER(v_class_discipline) = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation_legacy',
                'plan_name',    v_payment_record.plan_name
            );
        END IF;
    END LOOP;

    -- ── No valid plan found ───────────────────────────────────────────────
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason',  'Nessun abbonamento valido per questa disciplina. Acquista un piano per prenotare.'
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in check_class_booking_eligibility: % %', SQLERRM, SQLSTATE;
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'reason',  'Errore durante la verifica dell''idoneità alla prenotazione.'
        );
END;
$function$;

-- Also backfill any payment_confirmations where custom_plan_id is still NULL
-- but subscription_plan_id matches a custom_subscription_plans row.
-- This ensures Priority 2 catches all rows going forward.
DO $$
BEGIN
    UPDATE public.payment_confirmations pc
    SET custom_plan_id = pc.subscription_plan_id
    WHERE pc.custom_plan_id IS NULL
      AND pc.subscription_plan_id IS NOT NULL
      AND EXISTS (
          SELECT 1 FROM public.custom_subscription_plans csp
          WHERE csp.id = pc.subscription_plan_id
      );
    RAISE NOTICE 'Backfilled custom_plan_id for % payment_confirmation rows',
        (SELECT COUNT(*) FROM public.payment_confirmations WHERE custom_plan_id IS NOT NULL);
END $$;

COMMENT ON FUNCTION public.check_class_booking_eligibility(uuid, uuid) IS
'Booking eligibility — single plan type (admin-created custom plans only).
1. Entry-based packages: entries_remaining > 0.
2. Payment confirmations via custom_plan_id → discipline_custom_plan_associations.
3. Legacy fallback: payment_confirmations where subscription_plan_id = custom_subscription_plans.id.
No distinction between "standard" and "custom" plans — only custom_subscription_plans is used.';
