-- Migration: Fix subscription_plans RLS and restore missing plan data
-- Purpose: 
--   1. Add RLS SELECT policy so authenticated users can read subscription plans
--   2. Re-insert subscription plans that are missing from the database
--   3. Fix discipline_subscription_plans to support custom disciplines (text-based)

-- ============================================================================
-- 1. Fix RLS on subscription_plans: add public read policy
-- ============================================================================
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_can_read_subscription_plans" ON public.subscription_plans;
CREATE POLICY "authenticated_can_read_subscription_plans"
    ON public.subscription_plans
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "admins_manage_subscription_plans" ON public.subscription_plans;
CREATE POLICY "admins_manage_subscription_plans"
    ON public.subscription_plans
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    );

-- ============================================================================
-- 2. Re-insert missing subscription plans (idempotent via ON CONFLICT)
-- ============================================================================
INSERT INTO public.subscription_plans (
    name,
    price,
    plan_type,
    description,
    entry_count,
    is_active,
    sumup_url
)
SELECT * FROM (
    VALUES
        ('Corso Singolo', 60.00::numeric, 'monthly'::subscription_plan_type,
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QHVYXRZR'),

        ('Corso Singolo (in convenzione)', 50.00::numeric, 'monthly'::subscription_plan_type,
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi - Tariffa agevolata in convenzione',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QPQ08OQA'),

        ('Doppio corso (in convenzione)', 75.00::numeric, 'monthly'::subscription_plan_type,
         'Accesso a tutte le discipline (BJJ, MMA, Grappling, Sambo) - Tariffa agevolata in convenzione',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR42R0RH'),

        ('Doppio Corso', 95.00::numeric, 'monthly'::subscription_plan_type,
         'Accesso a tutte le discipline (BJJ, MMA, Grappling, Sambo)',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QZLJXISP'),

        ('Preparazione Atletica', 30.00::numeric, 'monthly'::subscription_plan_type,
         'Focus su condizionamento fisico, Allenamento personalizzato, Programmi specifici',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QU0R8I0A'),

        ('Corso Singolo + Preparazione', 90.00::numeric, 'monthly'::subscription_plan_type,
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi, Preparazione atletica completa',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QQ9F1KED'),

        ('Doppio Corso + Preparazione', 120.00::numeric, 'monthly'::subscription_plan_type,
         'Tutte le discipline incluse (BJJ, MMA, Grappling, Sambo, Prep. Atletica), Piano di allenamento completo',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR5I6ZO7'),

        ('Doppio corso + Prep. Atl. (in conv.)', 105.00::numeric, 'monthly'::subscription_plan_type,
         'Tutte le discipline incluse (BJJ, MMA, Grappling, Sambo, Prep. Atletica) - Tariffa agevolata in convenzione',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QT4LT4XQ'),

        ('Iscrizione Annuale', 30.00::numeric, 'annual'::subscription_plan_type,
         'Quota associativa annuale, Accesso agli eventi del team',
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/Q0ND0EKY'),

        ('Ingresso Singolo', 10.00::numeric, 'single_entry'::subscription_plan_type,
         'Accesso a una singola lezione',
         1, TRUE, NULL),

        ('Pacchetto 10 Ingressi', 80.00::numeric, 'multi_entry'::subscription_plan_type,
         'Pacchetto da 10 ingressi a scelta tra le discipline disponibili',
         10, TRUE, NULL)
) AS new_plans(name, price, plan_type, description, entry_count, is_active, sumup_url)
WHERE NOT EXISTS (
    SELECT 1 FROM public.subscription_plans sp
    WHERE sp.name = new_plans.name
);

-- ============================================================================
-- 3. Add RLS policy for custom_subscription_plans (public read)
-- ============================================================================
ALTER TABLE public.custom_subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_can_read_custom_subscription_plans" ON public.custom_subscription_plans;
CREATE POLICY "authenticated_can_read_custom_subscription_plans"
    ON public.custom_subscription_plans
    FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================================
-- 4. Create a text-based discipline_subscription_plans_custom table
--    to support custom disciplines (which are not in the discipline_type ENUM)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.discipline_subscription_plans_custom (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discipline_name TEXT NOT NULL,
    subscription_plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(discipline_name, subscription_plan_id)
);

CREATE INDEX IF NOT EXISTS idx_dsp_custom_discipline_name
    ON public.discipline_subscription_plans_custom(discipline_name);

CREATE INDEX IF NOT EXISTS idx_dsp_custom_subscription_plan_id
    ON public.discipline_subscription_plans_custom(subscription_plan_id);

ALTER TABLE public.discipline_subscription_plans_custom ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_can_read_discipline_subscription_plans_custom" ON public.discipline_subscription_plans_custom;
CREATE POLICY "public_can_read_discipline_subscription_plans_custom"
    ON public.discipline_subscription_plans_custom
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "admins_manage_discipline_subscription_plans_custom" ON public.discipline_subscription_plans_custom;
CREATE POLICY "admins_manage_discipline_subscription_plans_custom"
    ON public.discipline_subscription_plans_custom
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    );

COMMENT ON TABLE public.discipline_subscription_plans_custom IS
    'Junction table linking custom disciplines (by name) to subscription plans.';
