-- Location: supabase/migrations/20251127235349_add_role_title_to_user_profiles.sql
-- Schema Analysis: Existing user_profiles table with role enum for system-level roles
-- Integration Type: Extension - Adding display role title field
-- Dependencies: user_profiles table

-- Add role_title field for display purposes (separate from system role)
-- This field shows titles like "Istruttore Fitness", "Coach", "HeadCoach", etc.
-- Default is null for students (automatically set to "Allievo" via Flutter UI)
-- Only admins can modify this field for other users

ALTER TABLE public.user_profiles
ADD COLUMN role_title TEXT;

-- Create index for role_title lookups
CREATE INDEX idx_user_profiles_role_title ON public.user_profiles(role_title);

-- Add comment to explain the difference between role and role_title
COMMENT ON COLUMN public.user_profiles.role IS 'System-level role for permissions (student, instructor, admin, etc.)';
COMMENT ON COLUMN public.user_profiles.role_title IS 'Display title shown before user name (e.g., "Istruttore Fitness", "Coach", "HeadCoach", "Presidente", "Segretaria")';

-- Update existing instructor users to have appropriate role_titles based on their profiles
-- This is a one-time data migration for existing users
DO $$
DECLARE
    instructor_record RECORD;
BEGIN
    -- Set role_title for existing instructors based on their instructor_profiles
    FOR instructor_record IN 
        SELECT up.id, up.full_name, ip.primary_discipline
        FROM public.user_profiles up
        JOIN public.instructor_profiles ip ON up.id = ip.user_id
        WHERE up.role = 'instructor'
    LOOP
        -- Default title based on primary discipline
        UPDATE public.user_profiles
        SET role_title = CASE 
            WHEN instructor_record.primary_discipline = 'fitness' THEN 'Istruttore Fitness'
            ELSE 'Istruttore'
        END
        WHERE id = instructor_record.id AND role_title IS NULL;
    END LOOP;
    
    -- Set "Allievo" for students who don't have a role_title
    UPDATE public.user_profiles
    SET role_title = 'Allievo'
    WHERE role = 'student' AND role_title IS NULL;
    
    RAISE NOTICE 'Role titles initialized for existing users';
END $$;

-- Create function to check if user is admin (for role_title modification)
CREATE OR REPLACE FUNCTION public.is_admin_level_for_role_management()
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

-- Update RLS policy for user_profiles to allow admins to modify role_title of other users
-- Drop existing policy that might restrict updates
DROP POLICY IF EXISTS "users_update_own_user_profiles" ON public.user_profiles;

-- Create new policy allowing users to update own profile (except role_title)
CREATE POLICY "users_update_own_basic_info"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (
    id = auth.uid() AND 
    -- Prevent users from changing their own role_title
    (role_title IS NOT DISTINCT FROM (SELECT role_title FROM public.user_profiles WHERE id = auth.uid()))
);

-- Create policy allowing admins to update any user's role_title
CREATE POLICY "admins_update_user_role_titles"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (public.is_admin_level_for_role_management())
WITH CHECK (public.is_admin_level_for_role_management());

-- Add trigger to automatically set role_title for new students
CREATE OR REPLACE FUNCTION public.set_default_role_title()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If role_title is not set and role is student, set it to "Allievo"
    IF NEW.role_title IS NULL AND NEW.role = 'student' THEN
        NEW.role_title := 'Allievo';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER set_default_role_title_trigger
BEFORE INSERT ON public.user_profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_default_role_title();