-- Location: supabase/migrations/20250831020000_fix_test_user_credentials.sql
-- Schema Analysis: user_profiles table exists with proper auth structure
-- Integration Type: Fix existing test user credentials for login
-- Dependencies: user_profiles table, auth.users table

-- Function to create or update test user with proper credentials
CREATE OR REPLACE FUNCTION public.create_or_update_test_user(
    user_email TEXT,
    user_password TEXT,
    user_full_name TEXT,
    user_role public.user_role
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
BEGIN
    -- Check if user exists in auth.users
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = user_email
    LIMIT 1;

    IF user_uuid IS NULL THEN
        -- Create new user
        user_uuid := gen_random_uuid();
        
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, encrypted_password, 
            email_confirmed_at, created_at, updated_at, raw_user_meta_data, 
            raw_app_meta_data, is_sso_user, is_anonymous, confirmation_token, 
            confirmation_sent_at, recovery_token, recovery_sent_at, 
            email_change_token_new, email_change, email_change_sent_at, 
            email_change_token_current, email_change_confirm_status,
            reauthentication_token, reauthentication_sent_at, phone, 
            phone_change, phone_change_token, phone_change_sent_at
        ) VALUES (
            user_uuid,                                    -- id
            '00000000-0000-0000-0000-000000000000',      -- instance_id
            'authenticated',                              -- aud
            'authenticated',                              -- role
            user_email,                                   -- email
            crypt(user_password, gen_salt('bf', 10)),    -- encrypted_password
            now(),                                        -- email_confirmed_at
            now(),                                        -- created_at
            now(),                                        -- updated_at
            format('{"full_name": "%s"}', user_full_name)::jsonb, -- raw_user_meta_data
            '{"provider": "email", "providers": ["email"]}'::jsonb, -- raw_app_meta_data
            false,                                        -- is_sso_user
            false,                                        -- is_anonymous
            '',                                          -- confirmation_token
            null,                                        -- confirmation_sent_at
            '',                                          -- recovery_token
            null,                                        -- recovery_sent_at
            '',                                          -- email_change_token_new
            '',                                          -- email_change
            null,                                        -- email_change_sent_at
            '',                                          -- email_change_token_current
            0,                                           -- email_change_confirm_status
            '',                                          -- reauthentication_token
            null,                                        -- reauthentication_sent_at
            null,                                        -- phone
            '',                                          -- phone_change
            '',                                          -- phone_change_token
            null                                         -- phone_change_sent_at
        );

        RAISE NOTICE 'Created auth user for: %', user_email;
    ELSE
        -- Update existing user password and confirm email
        UPDATE auth.users 
        SET encrypted_password = crypt(user_password, gen_salt('bf', 10)),
            updated_at = now(),
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            raw_user_meta_data = format('{"full_name": "%s"}', user_full_name)::jsonb
        WHERE id = user_uuid;

        RAISE NOTICE 'Updated auth user credentials for: %', user_email;
    END IF;

    -- Create or update user profile
    INSERT INTO public.user_profiles (
        id, email, full_name, role, is_active, created_at, updated_at
    ) VALUES (
        user_uuid,
        user_email,
        user_full_name,
        user_role,
        true,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = user_email,
        full_name = user_full_name,
        role = user_role,
        is_active = true,
        updated_at = now();

    RAISE NOTICE 'Created/updated user profile for: % with role: %', user_email, user_role;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating/updating test user %: %', user_email, SQLERRM;
END $$;

-- Reset all test user credentials
DO $$
BEGIN
    -- Reset principal admin credentials
    PERFORM public.create_or_update_test_user(
        'lutadordeeliteravenna@gmail.com',
        'Magnus833cc',
        'Admin Principale Team Ragnarok',
        'principal_admin'::public.user_role
    );

    -- Reset student test credentials
    PERFORM public.create_or_update_test_user(
        'studente@teamragnarok.com',
        'student123',
        'Andrea Studente',
        'student'::public.user_role
    );

    -- Reset instructor test credentials
    PERFORM public.create_or_update_test_user(
        'instructor@teamragnarok.com',
        'instructor123',
        'Marco Istruttore',
        'instructor'::public.user_role
    );

    RAISE NOTICE 'All test user credentials have been reset successfully';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error resetting test user credentials: %', SQLERRM;
END $$;

-- Clean up any duplicate user_profiles entries
DELETE FROM public.user_profiles 
WHERE id NOT IN (
    SELECT DISTINCT id FROM auth.users
);

-- Ensure no email duplicates in user_profiles
WITH duplicate_emails AS (
    SELECT email, MIN(created_at) as first_created
    FROM public.user_profiles
    GROUP BY email
    HAVING COUNT(*) > 1
)
DELETE FROM public.user_profiles up
WHERE EXISTS (
    SELECT 1 FROM duplicate_emails de
    WHERE de.email = up.email
    AND up.created_at > de.first_created
);

-- Verify test users were created successfully
DO $$
DECLARE
    admin_exists BOOLEAN;
    student_exists BOOLEAN;
    instructor_exists BOOLEAN;
BEGIN
    -- Check admin exists
    SELECT EXISTS(
        SELECT 1 FROM auth.users au
        JOIN public.user_profiles up ON au.id = up.id
        WHERE au.email = 'lutadordeeliteravenna@gmail.com'
        AND up.role = 'principal_admin'
        AND au.email_confirmed_at IS NOT NULL
    ) INTO admin_exists;

    -- Check student exists
    SELECT EXISTS(
        SELECT 1 FROM auth.users au
        JOIN public.user_profiles up ON au.id = up.id
        WHERE au.email = 'studente@teamragnarok.com'
        AND up.role = 'student'
        AND au.email_confirmed_at IS NOT NULL
    ) INTO student_exists;

    -- Check instructor exists
    SELECT EXISTS(
        SELECT 1 FROM auth.users au
        JOIN public.user_profiles up ON au.id = up.id
        WHERE au.email = 'instructor@teamragnarok.com'
        AND up.role = 'instructor'
        AND au.email_confirmed_at IS NOT NULL
    ) INTO instructor_exists;

    IF admin_exists AND student_exists AND instructor_exists THEN
        RAISE NOTICE '✅ SUCCESS: All test users verified successfully';
        RAISE NOTICE '✅ Admin: lutadordeeliteravenna@gmail.com / Magnus833cc';
        RAISE NOTICE '✅ Student: studente@teamragnarok.com / student123';
        RAISE NOTICE '✅ Instructor: instructor@teamragnarok.com / instructor123';
    ELSE
        RAISE NOTICE '❌ WARNING: Some test users may not be properly configured';
        RAISE NOTICE 'Admin exists: %, Student exists: %, Instructor exists: %', 
                     admin_exists, student_exists, instructor_exists;
    END IF;
END $$;

-- Drop the helper function after use
DROP FUNCTION IF EXISTS public.create_or_update_test_user(TEXT, TEXT, TEXT, public.user_role);