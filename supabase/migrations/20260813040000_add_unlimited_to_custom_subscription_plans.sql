-- Migration: Add is_unlimited and entry_count to custom_subscription_plans
-- Purpose: Allow admin to create plans with no time expiry (entry-based expiry only)
-- When is_unlimited = true: expires_at is NULL, subscription expires when entries run out

-- 1. Add is_unlimited flag
ALTER TABLE public.custom_subscription_plans
  ADD COLUMN IF NOT EXISTS is_unlimited BOOLEAN NOT NULL DEFAULT false;

-- 2. Add entry_count for unlimited plans (how many bookings are allowed)
--    NULL means truly unlimited (no entry limit either), positive integer = N bookings
ALTER TABLE public.custom_subscription_plans
  ADD COLUMN IF NOT EXISTS entry_count INTEGER DEFAULT NULL;

-- 3. Update booking eligibility function to handle custom unlimited plans
-- These plans are stored in payment_confirmations (custom plan) and user_subscriptions
-- The logic: if is_unlimited=true and entry_count IS NULL → never expires (pure unlimited)
--            if is_unlimited=true and entry_count > 0 → expires when entries_remaining = 0

-- Update check_class_booking_eligibility to also handle custom unlimited plans
-- via discipline_custom_plan_associations table

DROP FUNCTION IF EXISTS public.check_class_booking_eligibility(uuid, uuid);

CREATE OR REPLACE FUNCTION public.check_class_booking_eligibility(
    p_user_id uuid,
    p_schedule_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_payment_record      RECORD;
    v_plan_name           TEXT;
    v_is_doppio           BOOLEAN;
    v_subscription_record RECORD;
    v_class_discipline    TEXT;
    v_target_discipline   TEXT;
    v_discipline_enum     public.discipline_type;
    v_plan_linked         BOOLEAN;
    v_entries_remaining   INTEGER;
BEGIN
    -- ── Get discipline of the requested class ──────────────────────────────
    SELECT discipline::TEXT INTO v_class_discipline
    FROM public.schedule_instances
    WHERE id = p_schedule_instance_id;

    IF v_class_discipline IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'reason', 'Classe non trovata.'
        );
    END IF;

    -- Cast to enum for discipline_subscription_plans lookups (best-effort)
    BEGIN
        v_discipline_enum := v_class_discipline::public.discipline_type;
    EXCEPTION WHEN OTHERS THEN
        v_discipline_enum := NULL;
    END;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 0: ENTRY-BASED PACKAGES via payment_confirmations
    -- (standard subscription_plans with plan_type single_entry/multi_entry)
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_payment_record IN
        SELECT
            pc.id              AS payment_id,
            pc.subscription_plan_id,
            sp.plan_type,
            sp.name            AS plan_name,
            sp.id              AS plan_id
        FROM public.payment_confirmations pc
        JOIN public.subscription_plans sp ON pc.subscription_plan_id = sp.id
        WHERE pc.user_id = p_user_id
          AND pc.status IN ('confirmed', 'paid')
          AND sp.plan_type IN ('single_entry', 'multi_entry')
        ORDER BY pc.created_at DESC
    LOOP
        -- Find the linked user_subscription with entries remaining
        SELECT us.entries_remaining INTO v_entries_remaining
        FROM public.user_subscriptions us
        WHERE us.user_id = p_user_id
          AND us.subscription_plan_id = v_payment_record.plan_id
          AND us.is_active = true
          AND us.entries_remaining > 0
        ORDER BY us.created_at DESC
        LIMIT 1;

        IF v_entries_remaining IS NOT NULL AND v_entries_remaining > 0 THEN
            RETURN jsonb_build_object(
                'allowed',           TRUE,
                'reason',            NULL,
                'entries_remaining', v_entries_remaining,
                'plan_type',         v_payment_record.plan_type,
                'booking_type',      'entry_based'
            );
        END IF;

        -- Fallback: any active entry subscription for this user
        SELECT us.id AS subscription_id, us.entries_remaining INTO v_subscription_record
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp2 ON us.subscription_plan_id = sp2.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND sp2.plan_type IN ('single_entry', 'multi_entry')
          AND us.entries_remaining > 0
        ORDER BY us.created_at DESC
        LIMIT 1;

        IF v_subscription_record.subscription_id IS NOT NULL THEN
            RETURN jsonb_build_object(
                'allowed',           TRUE,
                'reason',            NULL,
                'entries_remaining', v_subscription_record.entries_remaining,
                'plan_type',         v_payment_record.plan_type,
                'booking_type',      'entry_based'
            );
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 0b: CUSTOM UNLIMITED PLANS (is_unlimited = true)
    -- These are custom plans created by admin with no time expiry.
    -- They expire only when entries_remaining = 0 (or never if entry_count IS NULL).
    -- Check via discipline_custom_plan_associations for discipline match.
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_subscription_record IN
        SELECT
            us.id                AS subscription_id,
            us.entries_remaining,
            us.entries_total,
            csp.name             AS plan_name,
            csp.entry_count      AS plan_entry_count,
            csp.is_unlimited,
            csp.id               AS custom_plan_id
        FROM public.user_subscriptions us
        JOIN public.custom_subscription_plans csp ON us.subscription_plan_id = csp.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND csp.is_unlimited = true
          -- No time expiry check — unlimited plans never expire by time
          -- Entry check: allow if entry_count IS NULL (truly unlimited) OR entries_remaining > 0
          AND (csp.entry_count IS NULL OR us.entries_remaining > 0)
        ORDER BY us.created_at DESC
    LOOP
        -- Check if this custom plan is associated with the requested discipline
        IF EXISTS (
            SELECT 1
            FROM public.discipline_custom_plan_associations dcpa
            WHERE dcpa.custom_plan_id = v_subscription_record.custom_plan_id
              AND dcpa.discipline_name = v_class_discipline
        ) THEN
            RETURN jsonb_build_object(
                'allowed',           TRUE,
                'reason',            NULL,
                'entries_remaining', v_subscription_record.entries_remaining,
                'plan_type',         'unlimited_custom',
                'booking_type',      'unlimited_custom'
            );
        END IF;

        -- Grappling is always accessible to anyone with a valid plan
        IF v_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',           TRUE,
                'reason',            NULL,
                'entries_remaining', v_subscription_record.entries_remaining,
                'plan_type',         'unlimited_custom',
                'booking_type',      'unlimited_custom'
            );
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 1: ENTRY-BASED SUBSCRIPTIONS directly in user_subscriptions
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_subscription_record IN
        SELECT
            us.id            AS subscription_id,
            us.entries_remaining,
            sp.plan_type,
            sp.name          AS plan_name
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND sp.plan_type IN ('single_entry', 'multi_entry')
          AND us.entries_remaining > 0
        ORDER BY us.created_at DESC
        LIMIT 1
    LOOP
        RETURN jsonb_build_object(
            'allowed',            TRUE,
            'reason',             NULL,
            'entries_remaining',  v_subscription_record.entries_remaining,
            'plan_type',          v_subscription_record.plan_type,
            'booking_type',       'entry_based',
            'subscription_id',    v_subscription_record.subscription_id::TEXT
        );
    END LOOP;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 2: PAYMENT CONFIRMATIONS (monthly plans)
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_payment_record IN
        SELECT
            pc.target_discipline,
            sp.name      AS plan_name,
            sp.plan_type AS plan_type,
            sp.id        AS plan_id
        FROM public.payment_confirmations pc
        LEFT JOIN public.subscription_plans sp ON pc.subscription_plan_id = sp.id
        WHERE pc.user_id = p_user_id
          AND pc.status IN ('confirmed', 'paid')
          AND (pc.expires_at IS NULL OR pc.expires_at > NOW())
          AND COALESCE(sp.plan_type, '') <> 'annual'
          AND COALESCE(sp.plan_type::TEXT, '') NOT IN ('single_entry', 'multi_entry')
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_name         := COALESCE(v_payment_record.plan_name, '');
        v_target_discipline := COALESCE(v_payment_record.target_discipline, '');
        v_is_doppio         := public.is_corso_doppio_plan(v_plan_name);

        v_plan_linked := FALSE;
        IF v_discipline_enum IS NOT NULL AND v_payment_record.plan_id IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.discipline_subscription_plans dsp
                WHERE dsp.discipline = v_discipline_enum
                  AND dsp.subscription_plan_id = v_payment_record.plan_id
            ) INTO v_plan_linked;
        END IF;

        IF v_plan_linked THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        IF v_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        IF v_target_discipline = v_class_discipline THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        IF v_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        IF v_is_doppio THEN
            IF v_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        IF UPPER(v_target_discipline) = 'MMA' THEN
            IF v_class_discipline IN ('mma', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        IF UPPER(v_target_discipline) = 'BJJ' THEN
            IF v_class_discipline IN ('bjj', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        IF v_target_discipline = 'Sambo' THEN
            IF v_class_discipline IN ('sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════════════════════
    -- PRIORITY 3: ACTIVE MONTHLY SUBSCRIPTIONS
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_subscription_record IN
        SELECT
            us.id            AS subscription_id,
            sp.plan_type,
            sp.name          AS plan_name,
            sp.id            AS plan_id
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
        WHERE us.user_id = p_user_id
          AND us.is_active = true
          AND sp.plan_type NOT IN ('annual', 'single_entry', 'multi_entry')
          AND (us.expires_at IS NULL OR us.expires_at > NOW())
        ORDER BY us.created_at DESC
    LOOP
        v_plan_name := COALESCE(v_subscription_record.plan_name, '');
        v_is_doppio := public.is_corso_doppio_plan(v_plan_name);

        v_plan_linked := FALSE;
        IF v_discipline_enum IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.discipline_subscription_plans dsp
                WHERE dsp.discipline = v_discipline_enum
                  AND dsp.subscription_plan_id = v_subscription_record.plan_id
            ) INTO v_plan_linked;
        END IF;

        IF v_plan_linked THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'subscription'
            );
        END IF;

        IF v_is_doppio THEN
            IF v_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'subscription'
                );
            END IF;
        END IF;

        IF v_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'subscription'
                );
            END IF;
        END IF;

        IF v_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'subscription'
            );
        END IF;
    END LOOP;

    -- ── No valid plan found ───────────────────────────────────────────────
    RETURN jsonb_build_object(
        'allowed', FALSE,
        'reason',  'Accesso negato: la tua iscrizione non include questa disciplina o è scaduta.'
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

COMMENT ON FUNCTION public.check_class_booking_eligibility(uuid, uuid) IS
'Booking eligibility check with priority levels:
0.  Entry-based packages via payment_confirmations (standard plans, single_entry/multi_entry).
0b. Custom unlimited plans (is_unlimited=true): no time expiry, expires when entries_remaining=0.
    Discipline match via discipline_custom_plan_associations table.
1.  Entry-based subscriptions directly in user_subscriptions.
2.  Monthly plans via payment_confirmations (must be associated with discipline).
3.  Active monthly subscriptions (must be associated with discipline).
Annual plans are global prerequisites and are NEVER used as direct discipline associations.';
