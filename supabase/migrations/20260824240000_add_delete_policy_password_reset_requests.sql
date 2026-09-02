-- Add DELETE RLS policy for password_reset_requests table
-- Without this policy, admin delete calls were silently blocked by RLS,
-- causing the UI to show confirmation but records remaining in the database.

DROP POLICY IF EXISTS "admins_can_delete_password_reset_requests" ON public.password_reset_requests;
CREATE POLICY "admins_can_delete_password_reset_requests"
ON public.password_reset_requests
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role::TEXT IN ('admin', 'instructor_admin', 'principal_admin')
    )
);
