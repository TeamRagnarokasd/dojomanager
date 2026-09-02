-- Fix: Admin cannot see all users in user_profiles list
-- Root cause: is_admin_from_auth() only checks auth.users metadata (raw_user_meta_data/raw_app_meta_data)
-- but most users were created without setting role in metadata.
-- The admin's role is stored in user_profiles.role, not in auth metadata.
-- Solution: Rewrite is_admin_from_auth() to also check user_profiles.role directly
-- (safe: uses auth.uid() lookup on user_profiles, no recursion since we look up by PK)

-- ============================================================================
-- 1. Fix is_admin_from_auth() to check BOTH auth metadata AND user_profiles.role
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid()
    AND (
        au.raw_user_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
        OR au.raw_app_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
    )
)
OR EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid()
    AND up.role IN (
        'admin'::public.user_role,
        'principal_admin'::public.user_role,
        'instructor_admin'::public.user_role
    )
)
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_from_auth() TO authenticated;

-- ============================================================================
-- 2. Recreate the admin SELECT policy to use the fixed function
-- ============================================================================
DROP POLICY IF EXISTS "admin_read_all_profiles" ON public.user_profiles;

CREATE POLICY "admin_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (public.is_admin_from_auth());

-- ============================================================================
-- 3. Ensure the own-profile policy still exists (fallback for non-admins)
-- ============================================================================
DROP POLICY IF EXISTS "users_can_view_own_profile" ON public.user_profiles;

CREATE POLICY "users_can_view_own_profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- ============================================================================
-- 4. Ensure instructor/public-role profiles remain readable by all members
--    (needed for instructor directory)
-- ============================================================================
DROP POLICY IF EXISTS "authenticated_read_instructor_profiles" ON public.user_profiles;

CREATE POLICY "authenticated_read_instructor_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (
    role IN (
        'instructor'::public.user_role,
        'instructor_admin'::public.user_role,
        'instructor_student'::public.user_role,
        'principal_admin'::public.user_role
    )
);
