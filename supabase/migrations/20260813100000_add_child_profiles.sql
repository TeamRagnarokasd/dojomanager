-- Migration: Child/Minor Profiles linked to Adult Guardian
-- Adds child_profiles table, active_profile tracking, discount logic, and admin stats function

-- 1. Create child_profiles table
CREATE TABLE IF NOT EXISTS public.child_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guardian_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    birth_date DATE,
    birth_place TEXT,
    tax_code TEXT,
    codice_fiscale TEXT,
    phone TEXT,
    email TEXT,
    address_line TEXT,
    city TEXT,
    province TEXT,
    cap TEXT,
    gender TEXT,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    medical_notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Add active_child_profile_id to user_profiles (which child profile is currently active, NULL = adult profile)
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS active_child_profile_id UUID REFERENCES public.child_profiles(id) ON DELETE SET NULL;

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_child_profiles_guardian_id ON public.child_profiles(guardian_id);
CREATE INDEX IF NOT EXISTS idx_child_profiles_is_active ON public.child_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active_child ON public.user_profiles(active_child_profile_id);

-- 4. Enable RLS on child_profiles
ALTER TABLE public.child_profiles ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for child_profiles
DROP POLICY IF EXISTS "guardians_manage_own_children" ON public.child_profiles;
CREATE POLICY "guardians_manage_own_children"
ON public.child_profiles
FOR ALL
TO authenticated
USING (guardian_id = auth.uid())
WITH CHECK (guardian_id = auth.uid());

-- Admins can view all child profiles
DROP POLICY IF EXISTS "admins_view_all_child_profiles" ON public.child_profiles;
CREATE POLICY "admins_view_all_child_profiles"
ON public.child_profiles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin', 'instructor', 'instructor_admin')
    )
);

-- 6. Function: check if adult guardian has an active (non-annual) subscription
CREATE OR REPLACE FUNCTION public.guardian_has_active_subscription(guardian_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1
    FROM public.user_subscriptions us
    JOIN public.custom_subscription_plans csp ON us.subscription_plan_id = csp.id
    WHERE us.user_id = guardian_uuid
      AND us.is_active = true
      AND (us.expires_at IS NULL OR us.expires_at > now())
      AND (LOWER(csp.name) NOT LIKE '%iscrizione%' AND LOWER(csp.name) NOT LIKE '%annuale%')
      AND (csp.entry_count IS NULL OR csp.entry_count > 1)
)
$$;

-- 7. Function: get active member count for admin stats (excludes guardian-only adults)
CREATE OR REPLACE FUNCTION public.get_active_member_count()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Count users who have at least one active non-annual subscription
    -- OR who have an active annual registration (iscrizione)
    -- Guardians who ONLY have children enrolled (no personal subscription) are NOT counted
    SELECT COUNT(DISTINCT up.id) INTO v_count
    FROM public.user_profiles up
    WHERE up.is_active = true
      AND up.role = 'student'
      AND EXISTS (
          SELECT 1
          FROM public.user_subscriptions us
          WHERE us.user_id = up.id
            AND us.is_active = true
            AND (us.expires_at IS NULL OR us.expires_at > now())
      );
    RETURN COALESCE(v_count, 0);
END;
$$;

-- 8. Function: get active child member count for admin stats
CREATE OR REPLACE FUNCTION public.get_active_child_member_count()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Count child profiles that have at least one active subscription
    SELECT COUNT(DISTINCT cp.id) INTO v_count
    FROM public.child_profiles cp
    WHERE cp.is_active = true
      AND EXISTS (
          SELECT 1
          FROM public.user_subscriptions us
          WHERE us.user_id = cp.id
            AND us.is_active = true
            AND (us.expires_at IS NULL OR us.expires_at > now())
      );
    RETURN COALESCE(v_count, 0);
END;
$$;

-- 9. Trigger to update updated_at on child_profiles
CREATE OR REPLACE FUNCTION public.update_child_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_child_profiles_updated_at ON public.child_profiles;
CREATE TRIGGER trg_child_profiles_updated_at
BEFORE UPDATE ON public.child_profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_child_profiles_updated_at();
