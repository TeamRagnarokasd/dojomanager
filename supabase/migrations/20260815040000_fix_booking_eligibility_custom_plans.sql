-- Migration: Fix booking eligibility to check discipline_custom_plan_associations
-- Root cause: check_class_booking_eligibility only checked discipline_subscription_plans
-- (which links standard subscription_plans to disciplines), but custom plans like
-- "Corso BJJ" are stored in custom_subscription_plans and their discipline associations
-- are stored in discipline_custom_plan_associations. The function never checked this table,
-- causing users with valid custom plan purchases to be denied booking access.

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
    -- PRIORITY 1: ENTRY-BASED SUBSCRIPTIONS (single_entry / multi_entry)
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
    -- PRIORITY 2: PAYMENT CONFIRMATIONS (single purchases / monthly plans)
    -- Checks BOTH standard discipline_subscription_plans AND
    -- discipline_custom_plan_associations for custom plans.
    -- Annual plans are EXCLUDED from this check.
    -- ══════════════════════════════════════════════════════════════════════
    FOR v_payment_record IN
        SELECT
            pc.target_discipline,
            pc.subscription_plan_id,
            COALESCE(sp.name, csp.name)          AS plan_name,
            COALESCE(sp.plan_type::TEXT, 'custom') AS plan_type,
            sp.id                                  AS standard_plan_id,
            csp.id                                 AS custom_plan_id
        FROM public.payment_confirmations pc
        LEFT JOIN public.subscription_plans sp
               ON pc.subscription_plan_id = sp.id
        LEFT JOIN public.custom_subscription_plans csp
               ON pc.subscription_plan_id = csp.id
        WHERE pc.user_id = p_user_id
          AND pc.status IN ('confirmed', 'paid')
          AND (pc.expires_at IS NULL OR pc.expires_at > NOW())
          -- Exclude annual plans from direct discipline checks
          AND COALESCE(sp.plan_type::TEXT, 'custom') <> 'annual'
        ORDER BY pc.created_at DESC
    LOOP
        v_plan_name         := COALESCE(v_payment_record.plan_name, '');
        v_target_discipline := COALESCE(v_payment_record.target_discipline, '');
        v_is_doppio         := public.is_corso_doppio_plan(v_plan_name);

        v_plan_linked := FALSE;

        -- ── Check standard discipline_subscription_plans ──────────────────
        IF v_discipline_enum IS NOT NULL AND v_payment_record.standard_plan_id IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.discipline_subscription_plans dsp
                WHERE dsp.discipline = v_discipline_enum
                  AND dsp.subscription_plan_id = v_payment_record.standard_plan_id
            ) INTO v_plan_linked;
        END IF;

        -- ── Check discipline_custom_plan_associations (FIX for custom plans) ──
        IF NOT v_plan_linked AND v_payment_record.custom_plan_id IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.discipline_custom_plan_associations dcpa
                WHERE LOWER(dcpa.discipline_name) = LOWER(v_class_discipline)
                  AND dcpa.custom_plan_id = v_payment_record.custom_plan_id
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
    -- PRIORITY 3: ACTIVE MONTHLY SUBSCRIPTIONS (standard plans)
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
        RAISE NOTICE 'Error in check_class_booking_eligibility: %', SQLERRM;
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'reason',  'Errore durante la verifica dell''idoneità alla prenotazione.'
        );
END;
$function$;

COMMENT ON FUNCTION public.check_class_booking_eligibility(uuid, uuid) IS
'Booking eligibility check with support for both standard and custom subscription plans:
1. Entry-based packages (single_entry / multi_entry): only entries_remaining > 0 checked.
2. Payment confirmations: checks discipline_subscription_plans for standard plans AND
   discipline_custom_plan_associations for custom plans (e.g. Corso BJJ, Corso MMA).
3. Active monthly subscriptions: checks discipline_subscription_plans for standard plans.
Annual plans are excluded from direct discipline checks (they are global prerequisites).';
