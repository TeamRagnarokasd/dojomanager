-- Location: supabase/migrations/20250830210000_admin_verification_functions.sql
-- Purpose: Create database functions for admin verification and emergency reset
-- Dependencies: user_profiles table, auth.users table

-- Function to ensure principal admin exists
CREATE OR REPLACE FUNCTION public.ensure_principal_admin_exists(
    admin_email TEXT,
    admin_password TEXT,
    admin_name TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_uuid UUID;
    profile_exists BOOLEAN;
BEGIN
    -- Check if admin already exists in user_profiles
    SELECT EXISTS(
        SELECT 1 FROM public.user_profiles 
        WHERE email = admin_email AND role = 'principal_admin'::public.user_role
    ) INTO profile_exists;

    IF profile_exists THEN
        RAISE NOTICE 'Principal admin already exists: %', admin_email;
        RETURN TRUE;
    END IF;

    -- Check if auth user exists
    SELECT id INTO admin_uuid 
    FROM auth.users 
    WHERE email = admin_email
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
            admin_email,                                  -- email
            crypt(admin_password, gen_salt('bf', 10)),   -- encrypted_password
            now(),                                        -- email_confirmed_at
            now(),                                        -- created_at
            now(),                                        -- updated_at
            format('{"full_name": "%s"}', admin_name)::jsonb,  -- raw_user_meta_data
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

        RAISE NOTICE 'Created auth user for principal admin: %', admin_email;
    ELSE
        -- Update existing user password
        UPDATE auth.users 
        SET encrypted_password = crypt(admin_password, gen_salt('bf', 10)),
            updated_at = now(),
            email_confirmed_at = COALESCE(email_confirmed_at, now())
        WHERE id = admin_uuid;

        RAISE NOTICE 'Updated auth user password for: %', admin_email;
    END IF;

    -- Create or update user profile
    INSERT INTO public.user_profiles (
        id, email, full_name, role, is_active, created_at, updated_at
    ) VALUES (
        admin_uuid,
        admin_email,
        admin_name,
        'principal_admin'::public.user_role,
        true,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        role = 'principal_admin'::public.user_role,
        is_active = true,
        full_name = admin_name,
        updated_at = now();

    RAISE NOTICE 'Created/updated user profile for principal admin: %', admin_email;
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error ensuring principal admin exists: %', SQLERRM;
        RETURN FALSE;
END $$;

-- Function for emergency admin reset
CREATE OR REPLACE FUNCTION public.emergency_admin_reset(
    admin_email TEXT,
    admin_password TEXT,
    admin_name TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_uuid UUID;
    auth_user_exists BOOLEAN;
BEGIN
    RAISE NOTICE 'Starting emergency admin reset for: %', admin_email;

    -- Get or create auth user
    SELECT id INTO admin_uuid 
    FROM auth.users 
    WHERE email = admin_email
    LIMIT 1;

    IF admin_uuid IS NULL THEN
        -- Create new auth user
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
            admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 
            'authenticated', admin_email, crypt(admin_password, gen_salt('bf', 10)), 
            now(), now(), now(), format('{"full_name": "%s"}', admin_name)::jsonb, 
            '{"provider": "email", "providers": ["email"]}'::jsonb, false, false, 
            '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        );
        
        RAISE NOTICE 'Created new auth user with ID: %', admin_uuid;
    ELSE
        -- Force update existing auth user
        UPDATE auth.users 
        SET encrypted_password = crypt(admin_password, gen_salt('bf', 10)),
            updated_at = now(),
            email_confirmed_at = now(),
            raw_user_meta_data = format('{"full_name": "%s"}', admin_name)::jsonb
        WHERE id = admin_uuid;
        
        RAISE NOTICE 'Updated existing auth user with ID: %', admin_uuid;
    END IF;

    -- Force create/update user profile
    INSERT INTO public.user_profiles (
        id, email, full_name, role, is_active, created_at, updated_at
    ) VALUES (
        admin_uuid, admin_email, admin_name, 'principal_admin'::public.user_role, 
        true, now(), now()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = admin_email,
        full_name = admin_name,
        role = 'principal_admin'::public.user_role,
        is_active = true,
        updated_at = now();

    -- Ensure no conflicting email in user_profiles
    UPDATE public.user_profiles 
    SET email = email || '_old_' || extract(epoch from now())
    WHERE email = admin_email AND id != admin_uuid;

    RAISE NOTICE 'Emergency admin reset completed successfully for: %', admin_email;
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Emergency admin reset failed: %', SQLERRM;
        RETURN FALSE;
END $$;

-- Function to get admin verification status
CREATE OR REPLACE FUNCTION public.get_admin_verification_status(
    admin_email TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB := '{}';
    profile_data JSONB;
    auth_data JSONB;
BEGIN
    -- Get profile data
    SELECT to_jsonb(up.*) INTO profile_data
    FROM public.user_profiles up
    WHERE up.email = admin_email
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
    WHERE au.email = admin_email
    LIMIT 1;

    -- Build result
    result := jsonb_build_object(
        'admin_email', admin_email,
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
            'admin_email', admin_email,
            'verified_at', now()
        );
END $$;

-- Ensure the principal admin exists on migration execution
SELECT public.ensure_principal_admin_exists(
    'lutadordeeliteravenna@gmail.com',
    'Magnus833cc',
    'Admin Principale Team Ragnarok'
);