-- Location: supabase/migrations/20250907071400_fix_test_user_credentials.sql
-- Schema Analysis: Existing user_profiles table with authentication system
-- Integration Type: Data correction/authentication fix
-- Dependencies: auth.users, public.user_profiles

-- Fix: Correct test user credentials and ensure proper student account exists

DO $$
DECLARE
    student_auth_id UUID := gen_random_uuid();
    instructor_auth_id UUID;
    admin_auth_id UUID;
BEGIN
    -- Get existing user IDs to update their roles correctly
    SELECT id INTO instructor_auth_id FROM public.user_profiles WHERE email = 'instructor@teamragnarok.com' LIMIT 1;
    SELECT id INTO admin_auth_id FROM public.user_profiles WHERE email = 'lutadordeeliteravenna@gmail.com' LIMIT 1;
    
    -- Fix: Update incorrect role assignment for instructor@teamragnarok.com
    UPDATE public.user_profiles 
    SET 
        role = 'instructor'::public.user_role,
        full_name = 'Marco Rossi - Istruttore',
        updated_at = CURRENT_TIMESTAMP
    WHERE email = 'instructor@teamragnarok.com';
    
    -- Create missing student test account with correct password
    -- ALWAYS include all fields for auth.users - required for signin to work
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (student_auth_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'studente@teamragnarok.com', crypt('student123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Mario Studente", "role": "student"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Update existing auth.users password for instructor to ensure consistency
    UPDATE auth.users 
    SET encrypted_password = crypt('instructor123', gen_salt('bf', 10))
    WHERE id = instructor_auth_id;
    
    -- Update existing auth.users password for admin to ensure consistency  
    UPDATE auth.users 
    SET encrypted_password = crypt('admin123', gen_salt('bf', 10))
    WHERE id = admin_auth_id;
    
    -- Create corresponding user_profile for student (trigger should handle this, but ensure it exists)
    INSERT INTO public.user_profiles (id, email, full_name, role, status, is_active, created_at, updated_at)
    VALUES (
        student_auth_id, 
        'studente@teamragnarok.com', 
        'Mario Studente', 
        'student'::public.user_role, 
        'approved'::public.user_status, 
        true, 
        CURRENT_TIMESTAMP, 
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        is_active = EXCLUDED.is_active,
        updated_at = CURRENT_TIMESTAMP;

    RAISE NOTICE 'Test user credentials fixed successfully';
    RAISE NOTICE 'Student account: studente@teamragnarok.com / student123';
    RAISE NOTICE 'Instructor account: instructor@teamragnarok.com / instructor123'; 
    RAISE NOTICE 'Admin account: lutadordeeliteravenna@gmail.com / admin123';
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error during user creation: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'User already exists, skipping creation: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error during user setup: %', SQLERRM;
END $$;

-- Create function to verify test account setup
CREATE OR REPLACE FUNCTION public.verify_test_accounts()
RETURNS TABLE(
    email TEXT,
    role TEXT,
    auth_exists BOOLEAN,
    profile_exists BOOLEAN,
    status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(up.email, au.email) as email,
        COALESCE(up.role::TEXT, 'no_profile') as role,
        (au.id IS NOT NULL) as auth_exists,
        (up.id IS NOT NULL) as profile_exists,
        COALESCE(up.status::TEXT, 'no_profile') as status
    FROM auth.users au
    FULL OUTER JOIN public.user_profiles up ON au.id = up.id
    WHERE au.email IN ('studente@teamragnarok.com', 'instructor@teamragnarok.com', 'lutadordeeliteravenna@gmail.com')
       OR up.email IN ('studente@teamragnarok.com', 'instructor@teamragnarok.com', 'lutadordeeliteravenna@gmail.com')
    ORDER BY email;
END;
$$;