-- Migration: Add profile_photo_url to child_profiles table
ALTER TABLE public.child_profiles
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

-- Allow admins to update child profiles (for photo upload from admin screen)
DROP POLICY IF EXISTS "admins_update_child_profiles" ON public.child_profiles;
CREATE POLICY "admins_update_child_profiles"
ON public.child_profiles
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin')
    )
);
