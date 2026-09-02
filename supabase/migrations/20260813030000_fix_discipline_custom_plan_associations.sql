-- Migration: Fix discipline-custom-plan associations
-- Root cause: discipline_subscription_plans_custom references subscription_plans(id)
-- but the UI uses custom_subscription_plans (a completely different table).
-- Fix: Create a new junction table that correctly references custom_subscription_plans(id).

-- 1. Create the correct junction table for custom plans ↔ disciplines
CREATE TABLE IF NOT EXISTS public.discipline_custom_plan_associations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discipline_name TEXT NOT NULL,
    custom_plan_id UUID NOT NULL REFERENCES public.custom_subscription_plans(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(discipline_name, custom_plan_id)
);

CREATE INDEX IF NOT EXISTS idx_dcpa_discipline_name
    ON public.discipline_custom_plan_associations(discipline_name);

CREATE INDEX IF NOT EXISTS idx_dcpa_custom_plan_id
    ON public.discipline_custom_plan_associations(custom_plan_id);

-- 2. Enable RLS
ALTER TABLE public.discipline_custom_plan_associations ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
DROP POLICY IF EXISTS "authenticated_can_read_discipline_custom_plan_associations" ON public.discipline_custom_plan_associations;
CREATE POLICY "authenticated_can_read_discipline_custom_plan_associations"
    ON public.discipline_custom_plan_associations
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "admins_manage_discipline_custom_plan_associations" ON public.discipline_custom_plan_associations;
CREATE POLICY "admins_manage_discipline_custom_plan_associations"
    ON public.discipline_custom_plan_associations
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

COMMENT ON TABLE public.discipline_custom_plan_associations IS
    'Junction table linking disciplines (by name) to custom_subscription_plans. Correctly references custom_subscription_plans(id).';
