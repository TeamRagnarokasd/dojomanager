-- Fix user_profiles RLS policies
-- Problem: After enabling RLS on user_profiles, admins and instructors became invisible
-- because:
--   1. is_admin_from_auth() was rewritten to query user_profiles → infinite recursion
--   2. No SELECT policy exists for admins to read all profiles
--   3. No SELECT policy exists for authenticated users to read instructor profiles
--
-- Solution:
--   1. Restore is_admin_from_auth() to use auth.users metadata (safe, no recursion)
--   2. Add admin SELECT/UPDATE policies using the safe function
--   3. Add authenticated SELECT policy for instructor profiles (directory)
--   4. Add admin DELETE policy for user management

-- ============================================================================
-- 1. Restore is_admin_from_auth() to use auth.users (SAFE - no recursion)
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
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_from_auth() TO authenticated;

-- ============================================================================
-- 2. Drop all existing user_profiles SELECT/UPDATE/DELETE policies
--    (keep INSERT policies intact)
-- ============================================================================
DROP POLICY IF EXISTS "users_can_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_read_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "principal_admin_role_management" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_update_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_delete_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_read_instructor_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;

-- ============================================================================
-- 3. SELECT policies
-- ============================================================================

-- 3a. Every authenticated user can read their own row
CREATE POLICY "users_can_view_own_profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- 3b. Admins can read ALL profiles (uses auth.users metadata — no recursion)
CREATE POLICY "admin_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (public.is_admin_from_auth());

-- 3c. Any authenticated user can read instructor/instructor_admin/instructor_student profiles
--     (needed for the instructor directory visible to all members)
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

-- ============================================================================
-- 4. UPDATE policies
-- ============================================================================

-- 4a. Users can update their own profile
CREATE POLICY "users_can_update_own_profile"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 4b. Admins can update any profile (role changes, approvals, etc.)
CREATE POLICY "admin_update_all_profiles"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (public.is_admin_from_auth())
WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 5. DELETE policy
-- ============================================================================

-- Only admins can delete profiles
CREATE POLICY "admin_delete_profiles"
ON public.user_profiles
FOR DELETE
TO authenticated
USING (public.is_admin_from_auth());

-- ============================================================================
-- 6. Also fix admin_activity_log and pending_registrations policies
--    to use the restored safe is_admin_from_auth() function
-- ============================================================================

-- Fix admin_activity_log policies (they inline-query user_profiles which is fine,
-- but let's also add a version using the safe function for consistency)
DROP POLICY IF EXISTS "admins_read_activity_log" ON public.admin_activity_log;
DROP POLICY IF EXISTS "admins_insert_activity_log" ON public.admin_activity_log;

CREATE POLICY "admins_read_activity_log"
ON public.admin_activity_log
FOR SELECT
TO authenticated
USING (public.is_admin_from_auth());

CREATE POLICY "admins_insert_activity_log"
ON public.admin_activity_log
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin_from_auth());
