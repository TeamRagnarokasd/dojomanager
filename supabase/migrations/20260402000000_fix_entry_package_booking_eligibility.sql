-- Migration: Fix booking eligibility for entry-based packages purchased via payment_confirmations
-- Root cause: When a user buys a "10 ingressi" (multi_entry) package via SumUp/external payment,
-- it is stored in payment_confirmations (not user_subscriptions). The previous function only
-- checked user_subscriptions for entry-based packages, so confirmed entry packages were missed.
-- Additionally, payment_confirmations.expires_at defaults to NOW()+24h (for pending payment
-- window), which is irrelevant for entry packages — only entries_remaining matters.
--
-- Fix: Add a new PRIORITY 0 check that looks for entry-based plans in payment_confirmations
-- (status='confirmed'/'paid') and checks user_subscriptions.entries_remaining > 0 for the
-- linked subscription plan. Also keep the existing user_subscriptions direct check.

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
    -- When a user buys a multi_entry/single_entry plan via external payment
    -- (SumUp, Satispay, etc.), a payment_confirmation record is created AND
    -- a user_subscriptions record is created with entries_remaining.
    -- We check payment_confirmations (confirmed/paid) + user_subscriptions
    -- entries_remaining > 0, completely bypassing expires_at.
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

        -- Fallback: if no user_subscriptions row exists yet but payment is confirmed,
        -- check if there's any active entry subscription for this user regardless of plan
        -- (handles edge case where subscription was created without linking to payment)
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
    -- PRIORITY 1: ENTRY-BASED SUBSCRIPTIONS directly in user_subscriptions
    -- Rule: bypass expiry check — only require entries_remaining > 0
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
    -- Rule: plan must be explicitly associated with the discipline via
    --       discipline_subscription_plans table (or match via legacy rules).
    -- Annual plans are EXCLUDED. Entry-based plans already handled above.
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
          -- ✅ RULE 1: Exclude annual plans from direct discipline checks
          AND COALESCE(sp.plan_type, '') <> 'annual'
          -- ✅ Entry-based already handled in PRIORITY 0/1 above
          AND COALESCE(sp.plan_type::TEXT, '') NOT IN ('single_entry', 'multi_entry')
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_name         := COALESCE(v_payment_record.plan_name, '');
        v_target_discipline := COALESCE(v_payment_record.target_discipline, '');
        v_is_doppio         := public.is_corso_doppio_plan(v_plan_name);

        -- ── Check if this plan is explicitly associated with the discipline ──
        v_plan_linked := FALSE;
        IF v_discipline_enum IS NOT NULL AND v_payment_record.plan_id IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.discipline_subscription_plans dsp
                WHERE dsp.discipline = v_discipline_enum
                  AND dsp.subscription_plan_id = v_payment_record.plan_id
            ) INTO v_plan_linked;
        END IF;

        -- ── Allow if plan is explicitly linked to this discipline ─────────
        IF v_plan_linked THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        -- ── Legacy fallback rules (kept for backward compatibility) ───────

        -- Grappling: accessible to everyone with any valid non-annual payment
        IF v_class_discipline = 'grappling' THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        -- Direct target_discipline match
        IF v_target_discipline = v_class_discipline THEN
            RETURN jsonb_build_object(
                'allowed',      TRUE,
                'reason',       NULL,
                'booking_type', 'payment_confirmation'
            );
        END IF;

        -- Preparazione Atletica via plan name
        IF v_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        -- Corso Doppio gives access to MMA, BJJ, Sambo, Grappling
        IF v_is_doppio THEN
            IF v_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        -- target_discipline='MMA' → MMA + Grappling
        IF UPPER(v_target_discipline) = 'MMA' THEN
            IF v_class_discipline IN ('mma', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        -- target_discipline='BJJ' → BJJ + Grappling
        IF UPPER(v_target_discipline) = 'BJJ' THEN
            IF v_class_discipline IN ('bjj', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'payment_confirmation'
                );
            END IF;
        END IF;

        -- target_discipline='Sambo' → Sambo + Grappling
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
    -- Rule: plan must be explicitly associated with the discipline.
    -- Annual plans are EXCLUDED.
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
          -- ✅ RULE 1: Exclude annual plans
          AND sp.plan_type NOT IN ('annual', 'single_entry', 'multi_entry')
          AND (us.expires_at IS NULL OR us.expires_at > NOW())
        ORDER BY us.created_at DESC
    LOOP
        v_plan_name := COALESCE(v_subscription_record.plan_name, '');
        v_is_doppio := public.is_corso_doppio_plan(v_plan_name);

        -- ── Check explicit discipline association ─────────────────────────
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

        -- Legacy: Corso Doppio
        IF v_is_doppio THEN
            IF v_class_discipline IN ('mma', 'bjj', 'sambo', 'grappling') THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'subscription'
                );
            END IF;
        END IF;

        -- Legacy: Preparazione Atletica
        IF v_class_discipline = 'fitness' THEN
            IF LOWER(v_plan_name) LIKE '%preparazione%' OR LOWER(v_plan_name) LIKE '%prep.%' THEN
                RETURN jsonb_build_object(
                    'allowed',      TRUE,
                    'reason',       NULL,
                    'booking_type', 'subscription'
                );
            END IF;
        END IF;

        -- Legacy: Grappling open to all
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
'Booking eligibility check with four priority levels:
0. Entry-based packages via payment_confirmations (confirmed/paid) — checks entries_remaining > 0,
   completely bypasses expires_at (entry packages have no time expiry).
1. Entry-based subscriptions directly in user_subscriptions — same rule.
2. Monthly plans / payment_confirmations: must be explicitly associated with
   the discipline via discipline_subscription_plans table.
3. Active monthly subscriptions: must be explicitly associated with the discipline.
Annual plans (plan_type=annual) are global prerequisites and are NEVER used
as direct discipline associations.';
