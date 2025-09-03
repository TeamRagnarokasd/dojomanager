-- Location: supabase/migrations/20250830200000_update_admin_credentials.sql
-- Schema Analysis: user_profiles table exists with proper auth structure
-- Integration Type: Update existing admin credentials
-- Dependencies: user_profiles table

-- Update existing admin user with real credentials
DO $$
DECLARE
    admin_uuid UUID;
BEGIN
    -- Check if principal admin user exists
    SELECT id INTO admin_uuid 
    FROM auth.users 
    WHERE email = 'lutadordeeliteravenna@gmail.com'
    LIMIT 1;

    IF admin_uuid IS NULL THEN
        -- Create new admin user in auth.users
        admin_uuid := gen_random_uuid();
        
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
            admin_uuid,                                   -- id
            '00000000-0000-0000-0000-000000000000',      -- instance_id
            'authenticated',                              -- aud
            'authenticated',                              -- role
            'lutadordeeliteravenna@gmail.com',           -- email
            crypt('Magnus833cc', gen_salt('bf', 10)),    -- encrypted_password
            now(),                                        -- email_confirmed_at
            now(),                                        -- created_at
            now(),                                        -- updated_at
            '{"full_name": "Admin Principale"}'::jsonb,  -- raw_user_meta_data
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

        -- Create corresponding user_profile
        INSERT INTO public.user_profiles (
            id, email, full_name, role, is_active, created_at, updated_at
        ) VALUES (
            admin_uuid,
            'lutadordeeliteravenna@gmail.com',
            'Admin Principale',
            'principal_admin'::public.user_role,
            true,
            now(),
            now()
        );

        RAISE NOTICE 'Created new principal admin user: lutadordeeliteravenna@gmail.com';
    ELSE
        -- Update existing user password
        UPDATE auth.users 
        SET encrypted_password = crypt('Magnus833cc', gen_salt('bf', 10)),
            updated_at = now()
        WHERE id = admin_uuid;

        -- Update user profile role if needed
        UPDATE public.user_profiles 
        SET role = 'principal_admin'::public.user_role,
            is_active = true,
            updated_at = now()
        WHERE id = admin_uuid;

        RAISE NOTICE 'Updated existing principal admin user credentials';
    END IF;

    -- Ensure other test users exist for development
    PERFORM create_test_user_if_not_exists(
        'studente@teamragnarok.com',
        'student123',
        'Studente Test',
        'student'::public.user_role
    );

    PERFORM create_test_user_if_not_exists(
        'instructor@teamragnarok.com',
        'instructor123',
        'Istruttore Test',
        'instructor'::public.user_role
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating admin credentials: %', SQLERRM;
END $$;

-- Helper function to create test users
CREATE OR REPLACE FUNCTION create_test_user_if_not_exists(
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
    -- Check if user exists
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = user_email
    LIMIT 1;

    IF user_uuid IS NULL THEN
        user_uuid := gen_random_uuid();
        
        -- Create auth user
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
            user_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 
            'authenticated', user_email, crypt(user_password, gen_salt('bf', 10)), 
            now(), now(), now(), format('{"full_name": "%s"}', user_full_name)::jsonb, 
            '{"provider": "email", "providers": ["email"]}'::jsonb, false, false, 
            '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        );

        -- Create user profile
        INSERT INTO public.user_profiles (
            id, email, full_name, role, is_active, created_at, updated_at
        ) VALUES (
            user_uuid, user_email, user_full_name, user_role, true, now(), now()
        );

        RAISE NOTICE 'Created test user: % with role %', user_email, user_role;
    END IF;
END $$;