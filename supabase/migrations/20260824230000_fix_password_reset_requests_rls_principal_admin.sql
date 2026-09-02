-- Fix RLS policies for password_reset_requests to include 'principal_admin' role
-- The principal admin was excluded from SELECT/UPDATE policies, preventing notifications from appearing

-- Fix SELECT policy: include principal_admin
DROP POLICY IF EXISTS "admins_can_read_password_reset_requests" ON public.password_reset_requests;
CREATE POLICY "admins_can_read_password_reset_requests"
ON public.password_reset_requests
FOR SELECT
TO authenticated
USING (
    (auth.jwt() ->> 'role' = 'admin')
    OR EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role::TEXT IN ('admin', 'instructor_admin', 'principal_admin')
    )
);

-- Fix UPDATE policy: include principal_admin
DROP POLICY IF EXISTS "admins_can_update_password_reset_requests" ON public.password_reset_requests;
CREATE POLICY "admins_can_update_password_reset_requests"
ON public.password_reset_requests
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role::TEXT IN ('admin', 'instructor_admin', 'principal_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role::TEXT IN ('admin', 'instructor_admin', 'principal_admin')
    )
);
