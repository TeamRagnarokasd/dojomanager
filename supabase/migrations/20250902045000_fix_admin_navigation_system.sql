-- Fix Admin Navigation System Migration
-- This migration fixes the function parameter mismatch and enhances the admin verification system

-- Fix the get_admin_verification_status function to handle both parameter types
CREATE OR REPLACE FUNCTION public.get_admin_verification_status(admin_email text DEFAULT NULL, user_uuid uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    result JSONB := '{}';
    profile_data JSONB;
    auth_data JSONB;
    target_email text;
    target_uuid uuid;
BEGIN
    -- Determine which parameter to use
    IF admin_email IS NOT NULL THEN
        target_email := admin_email;
        -- Get UUID from profile if needed
        SELECT id INTO target_uuid 
        FROM public.user_profiles 
        WHERE email = admin_email 
        LIMIT 1;
    ELSIF user_uuid IS NOT NULL THEN
        target_uuid := user_uuid;
        -- Get email from profile if needed
        SELECT email INTO target_email 
        FROM public.user_profiles 
        WHERE id = user_uuid 
        LIMIT 1;
    ELSE
        -- Use current authenticated user if available
        target_uuid := auth.uid();
        IF target_uuid IS NOT NULL THEN
            SELECT email INTO target_email 
            FROM public.user_profiles 
            WHERE id = target_uuid 
            LIMIT 1;
        END IF;
    END IF;

    -- If no target found, return error
    IF target_email IS NULL AND target_uuid IS NULL THEN
        RETURN jsonb_build_object(
            'error', 'No admin email or user UUID provided',
            'verified_at', now()
        );
    END IF;

    -- Get profile data
    SELECT to_jsonb(up.*) INTO profile_data
    FROM public.user_profiles up
    WHERE (up.email = target_email OR up.id = target_uuid)
    LIMIT 1;

    -- Get auth data (limited fields for security)
    SELECT jsonb_build_object(
        'id', au.id,
        'email', au.email,
        'created_at', au.created_at,
        'email_confirmed_at', au.email_confirmed_at,
        'updated_at', au.updated_at
    ) INTO auth_data
    FROM auth.users au
    WHERE (au.email = target_email OR au.id = target_uuid)
    LIMIT 1;

    -- Build result
    result := jsonb_build_object(
        'admin_email', COALESCE(target_email, profile_data->>'email'),
        'user_uuid', COALESCE(target_uuid, profile_data->>'id'),
        'profile_exists', profile_data IS NOT NULL,
        'auth_exists', auth_data IS NOT NULL,
        'profile_data', COALESCE(profile_data, '{}'::jsonb),
        'auth_data', COALESCE(auth_data, '{}'::jsonb),
        'verified_at', now()
    );

    RETURN result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'error', SQLERRM,
            'admin_email', target_email,
            'user_uuid', target_uuid,
            'verified_at', now()
        );
END $function$;

-- Create enhanced admin status check function
CREATE OR REPLACE FUNCTION public.get_current_user_admin_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_user_id uuid;
    user_profile RECORD;
    result jsonb;
BEGIN
    -- Get current authenticated user
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'authenticated', false,
            'role', 'guest',
            'is_admin', false,
            'is_principal_admin', false,
            'checked_at', now()
        );
    END IF;

    -- Get user profile
    SELECT * INTO user_profile
    FROM public.user_profiles
    WHERE id = current_user_id;

    IF user_profile IS NULL THEN
        RETURN jsonb_build_object(
            'authenticated', true,
            'profile_exists', false,
            'role', 'student',
            'is_admin', false,
            'is_principal_admin', false,
            'checked_at', now()
        );
    END IF;

    -- Build comprehensive result
    result := jsonb_build_object(
        'authenticated', true,
        'profile_exists', true,
        'user_id', current_user_id,
        'email', user_profile.email,
        'role', user_profile.role,
        'is_active', user_profile.is_active,
        'is_admin', user_profile.role IN ('admin', 'instructor_admin', 'principal_admin'),
        'is_principal_admin', user_profile.role = 'principal_admin' OR user_profile.email = 'lutadordeeliteravenna@gmail.com',
        'is_instructor', user_profile.role IN ('instructor', 'instructor_admin', 'principal_admin'),
        'full_name', user_profile.full_name,
        'checked_at', now()
    );

    RETURN result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'error', SQLERRM,
            'authenticated', current_user_id IS NOT NULL,
            'checked_at', now()
        );
END $function$;

-- Enhanced function to fix admin navigation issues
CREATE OR REPLACE FUNCTION public.ensure_admin_navigation_works()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    principal_admin_email text := 'lutadordeeliteravenna@gmail.com';
    admin_profile RECORD;
    auth_user RECORD;
BEGIN
    -- Check if principal admin profile exists
    SELECT * INTO admin_profile
    FROM public.user_profiles
    WHERE email = principal_admin_email;

    -- Check if auth user exists
    SELECT * INTO auth_user
    FROM auth.users
    WHERE email = principal_admin_email;

    -- If profile exists but role is wrong, fix it
    IF admin_profile IS NOT NULL THEN
        IF admin_profile.role != 'principal_admin' OR admin_profile.is_active != true THEN
            UPDATE public.user_profiles
            SET 
                role = 'principal_admin',
                is_active = true,
                updated_at = now()
            WHERE id = admin_profile.id;
            
            RAISE NOTICE 'Fixed principal admin profile role and status';
        END IF;
    END IF;

    -- Log admin activity if profile exists
    IF admin_profile IS NOT NULL THEN
        INSERT INTO public.admin_activity_log (
            admin_id,
            action_type,
            description
        ) VALUES (
            admin_profile.id,
            'SYSTEM_MAINTENANCE',
            'Admin navigation system verification and repair completed'
        );
    END IF;

    RETURN true;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Admin navigation fix failed: %', SQLERRM;
        RETURN false;
END $function$;

-- Run the admin navigation fix
SELECT public.ensure_admin_navigation_works();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.get_admin_verification_status(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_admin_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_admin_navigation_works() TO authenticated;

-- Create index for better performance on admin queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_role ON public.user_profiles(email, role) WHERE role IN ('admin', 'instructor_admin', 'principal_admin');
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_active ON public.user_profiles(role, is_active) WHERE is_active = true;

-- Insert a success log entry
INSERT INTO public.admin_activity_log (
    admin_id,
    action_type,
    description
) 
SELECT 
    id,
    'SYSTEM_UPGRADE',
    'Admin navigation system completely rebuilt and enhanced - migration 20250902045000'
FROM public.user_profiles 
WHERE email = 'lutadordeeliteravenna@gmail.com' 
AND role = 'principal_admin'
LIMIT 1;

COMMIT;