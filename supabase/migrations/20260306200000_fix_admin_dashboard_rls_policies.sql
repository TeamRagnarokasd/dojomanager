-- Fix RLS policies for admin dashboard tables
-- Issues:
--   1. admin_activity_log has RLS enabled but zero policies → all access blocked
--   2. pending_registrations policy references auth.users directly → "permission denied for table users"
--   3. Ensure is_admin_from_auth() uses user_profiles (not auth.users)

-- ============================================================================
-- 1. Fix is_admin_from_auth() to use user_profiles instead of auth.users
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid()
    AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
    AND up.is_active = true
)
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_from_auth() TO authenticated;

-- ============================================================================
-- 2. Fix admin_activity_log: add missing RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "admins_read_activity_log" ON public.admin_activity_log;
DROP POLICY IF EXISTS "admins_insert_activity_log" ON public.admin_activity_log;

CREATE POLICY "admins_read_activity_log"
ON public.admin_activity_log
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'principal_admin', 'instructor_admin')
        AND is_active = true
    )
);

CREATE POLICY "admins_insert_activity_log"
ON public.admin_activity_log
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'principal_admin', 'instructor_admin')
        AND is_active = true
    )
);

-- ============================================================================
-- 3. Fix pending_registrations: replace auth.users reference with user_profiles
-- ============================================================================
DROP POLICY IF EXISTS "users_view_own_pending_registrations" ON public.pending_registrations;

CREATE POLICY "users_view_own_pending_registrations"
ON public.pending_registrations
FOR SELECT
TO authenticated
USING (
    email = (SELECT email FROM public.user_profiles WHERE id = auth.uid())
);

-- Ensure admin policy uses the fixed function
DROP POLICY IF EXISTS "admin_manage_pending_registrations" ON public.pending_registrations;

CREATE POLICY "admin_manage_pending_registrations"
ON public.pending_registrations
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'principal_admin', 'instructor_admin')
        AND is_active = true
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'principal_admin', 'instructor_admin')
        AND is_active = true
    )
);

-- Allow anonymous/new users to INSERT their own pending registration
DROP POLICY IF EXISTS "anyone_can_register" ON public.pending_registrations;

CREATE POLICY "anyone_can_register"
ON public.pending_registrations
FOR INSERT
TO authenticated
WITH CHECK (true);
