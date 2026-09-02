-- Migration: Ensure subscription_plans table has all standard plans
-- Purpose: Re-insert standard subscription plans if missing (idempotent)
-- This fixes the issue where admin edits were not persisted because
-- the subscription_plans table was empty and plans were only hardcoded in Flutter.

-- Ensure RLS is enabled and policies exist
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_can_read_subscription_plans_v2" ON public.subscription_plans;
CREATE POLICY "authenticated_can_read_subscription_plans_v2"
    ON public.subscription_plans
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "admins_manage_subscription_plans_v2" ON public.subscription_plans;
CREATE POLICY "admins_manage_subscription_plans_v2"
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

-- Ensure custom_subscription_plans RLS is enabled
ALTER TABLE public.custom_subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "principal_admin_manage_custom_plans_v2" ON public.custom_subscription_plans;
CREATE POLICY "principal_admin_manage_custom_plans_v2"
    ON public.custom_subscription_plans
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

-- Insert standard plans only if they don't already exist (by name)
INSERT INTO public.subscription_plans (
    name,
    price,
    plan_type,
    description,
    entry_count,
    is_active,
    sumup_url
)
SELECT v.name, v.price, v.plan_type, v.description, v.entry_count, v.is_active, v.sumup_url
FROM (
    VALUES
        ('Ingresso singolo',          10.00::numeric,  'single_entry'::subscription_plan_type, 'Un singolo accesso agli allenamenti, Nessuna data di scadenza, Perfetto per provare', 1,    TRUE, NULL::text),
        ('Pacchetto 10 ingressi',     80.00::numeric,  'multi_entry'::subscription_plan_type,  '10 ingressi agli allenamenti, Nessuna data di scadenza, Risparmio rispetto all ingresso singolo', 10, TRUE, 'https://pay.sumup.com/b2c/QR3160IO'),
        ('Corso Singolo',             60.00::numeric,  'monthly'::subscription_plan_type,      'Scelta tra MMA o BJJ ogni mese', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QHVYXRZR'),
        ('Corso Singolo (in convenzione)', 50.00::numeric, 'monthly'::subscription_plan_type, 'Scelta tra MMA o BJJ ogni mese, Tariffa agevolata in convenzione', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QPQ08OQA'),
        ('Doppio Corso',              95.00::numeric,  'monthly'::subscription_plan_type,      'Accesso a tutte le discipline, Allenamenti intensivi', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QZLJXISP'),
        ('Doppio corso (in convenzione)', 75.00::numeric, 'monthly'::subscription_plan_type,  'Accesso a tutte le discipline, Allenamenti intensivi, Tariffa agevolata in convenzione', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR42R0RH'),
        ('Preparazione Atletica',     30.00::numeric,  'monthly'::subscription_plan_type,      'Focus su condizionamento fisico, Allenamento personalizzato, Programmi specifici', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QU0R8I0A'),
        ('Corso Singolo + Preparazione', 90.00::numeric, 'monthly'::subscription_plan_type,   'Scelta tra MMA o BJJ ogni mese, Preparazione atletica completa', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QQ9F1KED'),
        ('Doppio Corso + Preparazione', 120.00::numeric, 'monthly'::subscription_plan_type,   'Tutte le discipline incluse, Piano di allenamento completo, Massima intensita', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR5I6ZO7'),
        ('Doppio corso + Prep. Atl. (in conv.)', 105.00::numeric, 'monthly'::subscription_plan_type, 'Tutte le discipline incluse, Piano di allenamento completo, Tariffa agevolata in convenzione', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QT4LT4XQ'),
        ('Iscrizione Annuale',        30.00::numeric,  'annual'::subscription_plan_type,       'Quota associativa annuale, Accesso agli eventi del team', NULL::integer, TRUE, 'https://pay.sumup.com/b2c/Q0ND0EKY')
) AS v(name, price, plan_type, description, entry_count, is_active, sumup_url)
WHERE NOT EXISTS (
    SELECT 1 FROM public.subscription_plans sp WHERE sp.name = v.name
);
