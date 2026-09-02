-- Migration: Add password_reset_requests table
-- Users can request password reset by providing email + birth date
-- Admin receives a notification in the dashboard

CREATE TABLE IF NOT EXISTS public.password_reset_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    user_full_name TEXT NOT NULL,
    requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'pending',
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_password_reset_requests_user_id
    ON public.password_reset_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_password_reset_requests_status
    ON public.password_reset_requests(status);

CREATE INDEX IF NOT EXISTS idx_password_reset_requests_requested_at
    ON public.password_reset_requests(requested_at DESC);

ALTER TABLE public.password_reset_requests ENABLE ROW LEVEL SECURITY;

-- Anyone (even unauthenticated) can insert a reset request
DROP POLICY IF EXISTS "anyone_can_insert_password_reset_requests" ON public.password_reset_requests;
CREATE POLICY "anyone_can_insert_password_reset_requests"
ON public.password_reset_requests
FOR INSERT
TO public
WITH CHECK (true);

-- Admins can read all requests (using auth metadata to avoid recursion)
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
        AND up.role IN ('admin', 'instructor_admin')
    )
);

-- Admins can update (mark as resolved)
DROP POLICY IF EXISTS "admins_can_update_password_reset_requests" ON public.password_reset_requests;
CREATE POLICY "admins_can_update_password_reset_requests"
ON public.password_reset_requests
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'instructor_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'instructor_admin')
    )
);
