-- Location: supabase/migrations/20250909020000_set_student_dashboard_home.sql
-- Schema Analysis: Existing comprehensive schema with user management, authentication, and routing
-- Integration Type: MODIFICATIVE - Update existing function to change student dashboard routing
-- Dependencies: Existing get_role_dashboard_route function, user_role enum, existing dashboard routes

-- Update the existing get_role_dashboard_route function to route students to dashboard-home
-- instead of enhanced-user-dashboard
CREATE OR REPLACE FUNCTION public.get_role_dashboard_route(user_role user_role)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
    SELECT CASE
        WHEN user_role IN ('principal_admin', 'admin') THEN '/enhanced-admin-dashboard'
        WHEN user_role IN ('instructor', 'instructor_admin') THEN '/enhanced-instructor-dashboard'
        WHEN user_role = 'student' THEN '/dashboard-home'
        ELSE '/dashboard-home'
    END;
$function$;

-- Add comment explaining the change
COMMENT ON FUNCTION public.get_role_dashboard_route(user_role) IS 'Updated to route students to dashboard-home instead of enhanced-user-dashboard. The dashboard-home contains the shop section and is now the unified homepage for students.';