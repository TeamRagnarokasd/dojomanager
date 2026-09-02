-- Migration: Add 'instructor_student' role support
-- This role allows a user to act as both instructor and student.
-- They appear in student lists for belt/strip assignment by headcoach,
-- and can switch between instructor dashboard and student home.

-- Update the get_role_dashboard_route function to handle instructor_student
-- (routes to instructor dashboard on first login, student can switch back)
CREATE OR REPLACE FUNCTION public.get_role_dashboard_route(user_role text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  CASE user_role
    WHEN 'principal_admin' THEN RETURN '/enhanced-admin-dashboard';
    WHEN 'admin' THEN RETURN '/enhanced-admin-dashboard';
    WHEN 'instructor_admin' THEN RETURN '/enhanced-admin-dashboard';
    WHEN 'instructor' THEN RETURN '/instructor-main-dashboard';
    WHEN 'instructor_student' THEN RETURN '/instructor-main-dashboard';
    WHEN 'student' THEN RETURN '/dashboard-home';
    WHEN 'member' THEN RETURN '/dashboard-home';
    ELSE RETURN '/dashboard-home';
  END CASE;
END;
$$;

-- Update is_admin_level_user to NOT include instructor_student
-- (instructor_student is not an admin)
CREATE OR REPLACE FUNCTION public.is_admin_level_user()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM public.user_profiles
  WHERE id = auth.uid();

  RETURN v_role IN ('admin', 'principal_admin', 'instructor_admin');
END;
$$;

-- Ensure RLS policies that check for student role also include instructor_student
-- so headcoach can see and assign belts/strips to instructor_student users.
-- The member_belts table should allow reads/writes for instructor_student users.

-- Allow instructor_student users to be seen in member_belts queries
-- (no schema change needed — the app queries user_profiles with inFilter)

-- Grant instructor_student the same booking/class access as students
-- (no schema change needed — booking eligibility checks subscription, not role)

-- Add a comment documenting the new role
COMMENT ON TABLE public.user_profiles IS 
  'User profiles. Roles: student, instructor, admin, principal_admin, instructor_admin (instructor+admin switch), instructor_student (instructor+student switch — visible in student lists for belt/strip assignment).';
