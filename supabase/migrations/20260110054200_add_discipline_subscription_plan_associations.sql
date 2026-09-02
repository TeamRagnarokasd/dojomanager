-- Migration: Add discipline-subscription plan associations
-- Purpose: Allow admins to manually associate subscription plans to disciplines
-- This enables dynamic linking when creating new disciplines instead of hardcoded logic

-- Create junction table to link disciplines (via enum) to subscription plans
CREATE TABLE IF NOT EXISTS public.discipline_subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discipline public.discipline_type NOT NULL,
    subscription_plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure unique combination of discipline and plan
    UNIQUE(discipline, subscription_plan_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_discipline_subscription_plans_discipline 
    ON public.discipline_subscription_plans(discipline);
CREATE INDEX IF NOT EXISTS idx_discipline_subscription_plans_subscription_plan_id 
    ON public.discipline_subscription_plans(subscription_plan_id);

-- Enable RLS
ALTER TABLE public.discipline_subscription_plans ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Public read, Admin write
CREATE POLICY "public_can_read_discipline_subscription_plans"
    ON public.discipline_subscription_plans
    FOR SELECT
    TO public
    USING (true);

CREATE POLICY "admins_manage_discipline_subscription_plans"
    ON public.discipline_subscription_plans
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

-- Add comment for documentation
COMMENT ON TABLE public.discipline_subscription_plans IS 
    'Junction table linking disciplines to subscription plans. Allows admins to configure which plans apply to which disciplines.';

-- Helper function to get subscription plans for a discipline
CREATE OR REPLACE FUNCTION public.get_subscription_plans_for_discipline(
    p_discipline public.discipline_type
)
RETURNS TABLE(
    subscription_plan_id UUID,
    plan_name TEXT,
    plan_type TEXT,
    price DECIMAL(10,2),
    description TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT 
        sp.id,
        sp.name,
        sp.plan_type::TEXT,
        sp.price,
        sp.description
    FROM public.discipline_subscription_plans dsp
    JOIN public.subscription_plans sp ON dsp.subscription_plan_id = sp.id
    WHERE dsp.discipline = p_discipline
    AND sp.is_active = true
    ORDER BY sp.price ASC;
$$;

-- Helper function to get disciplines for a subscription plan
CREATE OR REPLACE FUNCTION public.get_disciplines_for_subscription_plan(
    p_subscription_plan_id UUID
)
RETURNS TABLE(
    discipline public.discipline_type
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT dsp.discipline
    FROM public.discipline_subscription_plans dsp
    WHERE dsp.subscription_plan_id = p_subscription_plan_id;
$$;

