-- Location: supabase/migrations/20260125000000_add_custom_subscription_plans.sql
-- Purpose: Add custom subscription plans table for admin-created plans
-- Integration: Extends existing subscription_plans system

-- 1. Create custom subscription plans table
CREATE TABLE IF NOT EXISTS public.custom_subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    external_url TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create indexes
CREATE INDEX idx_custom_subscription_plans_active ON public.custom_subscription_plans(is_active);
CREATE INDEX idx_custom_subscription_plans_created_by ON public.custom_subscription_plans(created_by);

-- 3. Enable RLS
ALTER TABLE public.custom_subscription_plans ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Public can read active custom plans
CREATE POLICY "public_can_read_custom_subscription_plans"
ON public.custom_subscription_plans
FOR SELECT
TO public
USING (is_active = true);

-- Only principal admin can manage custom plans
CREATE POLICY "principal_admin_manage_custom_plans"
ON public.custom_subscription_plans
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role = 'principal_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role = 'principal_admin'
    )
);

-- 5. Function to get all subscription plans (standard + custom)
CREATE OR REPLACE FUNCTION public.get_all_subscription_plans()
RETURNS TABLE (
    id UUID,
    name TEXT,
    price DECIMAL,
    url TEXT,
    plan_type TEXT,
    is_custom BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    -- Get standard plans
    SELECT 
        sp.id,
        sp.name,
        sp.price,
        sp.sumup_url as url,
        sp.plan_type::TEXT as plan_type,
        false as is_custom
    FROM public.subscription_plans sp
    WHERE sp.is_active = true
    
    UNION ALL
    
    -- Get custom plans
    SELECT 
        csp.id,
        csp.name,
        csp.amount as price,
        csp.external_url as url,
        'custom' as plan_type,
        true as is_custom
    FROM public.custom_subscription_plans csp
    WHERE csp.is_active = true
    
    ORDER BY is_custom, price;
$$;

-- 6. Add comment
COMMENT ON TABLE public.custom_subscription_plans IS 'Custom subscription plans created by principal admin with external payment links';