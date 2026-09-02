-- Migration: Add medical certificate fields to child_profiles table
-- Mirrors the medical certificate logic used for adult users

ALTER TABLE public.child_profiles
ADD COLUMN IF NOT EXISTS medical_certificate_url TEXT,
ADD COLUMN IF NOT EXISTS medical_certificate_uploaded_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS medical_certificate_expiry_date DATE,
ADD COLUMN IF NOT EXISTS medical_certificate_pending BOOLEAN NOT NULL DEFAULT false;

-- Allow admins to update medical certificate fields on child profiles
DROP POLICY IF EXISTS "admins_update_child_profiles" ON public.child_profiles;
CREATE POLICY "admins_update_child_profiles"
ON public.child_profiles
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin', 'instructor', 'instructor_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin', 'instructor', 'instructor_admin')
    )
);
