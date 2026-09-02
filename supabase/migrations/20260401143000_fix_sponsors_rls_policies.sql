-- Location: supabase/migrations/20260401143000_fix_sponsors_rls_policies.sql
-- Fix: Add missing RLS policies for sponsors table to allow admin CRUD operations
-- and public read access for all authenticated users

-- Ensure RLS is enabled
ALTER TABLE public.sponsors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "sponsors_public_read" ON public.sponsors;
DROP POLICY IF EXISTS "sponsors_admin_all" ON public.sponsors;
DROP POLICY IF EXISTS "admins_manage_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "authenticated_read_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "admin_insert_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "admin_update_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "admin_delete_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "public_read_active_sponsors" ON public.sponsors;
DROP POLICY IF EXISTS "sponsors_select_policy" ON public.sponsors;
DROP POLICY IF EXISTS "sponsors_insert_policy" ON public.sponsors;
DROP POLICY IF EXISTS "sponsors_update_policy" ON public.sponsors;
DROP POLICY IF EXISTS "sponsors_delete_policy" ON public.sponsors;

-- Create helper function to check if user is admin (queries user_profiles, safe for non-user tables)
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid()
    AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
)
$$;

-- Policy 1: All authenticated users can read active sponsors (for user dashboard)
CREATE POLICY "sponsors_select_policy"
ON public.sponsors
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Admins can insert new sponsors
CREATE POLICY "sponsors_insert_policy"
ON public.sponsors
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin_user());

-- Policy 3: Admins can update sponsors
CREATE POLICY "sponsors_update_policy"
ON public.sponsors
FOR UPDATE
TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- Policy 4: Admins can delete sponsors
CREATE POLICY "sponsors_delete_policy"
ON public.sponsors
FOR DELETE
TO authenticated
USING (public.is_admin_user());
