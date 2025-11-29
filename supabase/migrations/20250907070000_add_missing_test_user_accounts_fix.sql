-- Location: supabase/migrations/20250907070000_add_missing_test_user_accounts_fix.sql
-- Schema Analysis: Existing user_profiles table with principal admin user
-- Integration Type: Addition - Adding missing test user accounts
-- Dependencies: user_profiles table (existing)

-- Fix login issue by adding missing test accounts that match the UI expectations
DO $$
DECLARE
    student_uuid UUID := gen_random_uuid();
    instructor_uuid UUID := gen_random_uuid();
BEGIN
    -- Create missing auth users for test accounts with required fields
    -- **ALWAYS include all fields for auth.users** All of them even the null. Without it the user will not be able to signin.
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        -- Student test account  
        (student_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'studente@teamragnarok.com', crypt('teamragnarok2024', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Studente Test Team Ragnarok", "role": "student"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        -- Instructor test account
        (instructor_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'instructor@teamragnarok.com', crypt('teamragnarok2024', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Istruttore Test Team Ragnarok", "role": "instructor"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create corresponding user_profiles (will be auto-created by trigger, but ensuring they exist)
    INSERT INTO public.user_profiles (
        id, email, full_name, role, status, is_active, 
        phone, medical_certificate_status, created_at, updated_at
    ) VALUES
        (student_uuid, 'studente@teamragnarok.com', 'Studente Test Team Ragnarok', 'student'::user_role, 'approved'::user_status, true,
         '+39 320 123 4567', 'approved', now(), now()),
        (instructor_uuid, 'instructor@teamragnarok.com', 'Istruttore Test Team Ragnarok', 'instructor'::user_role, 'approved'::user_status, true,
         '+39 320 765 4321', 'approved', now(), now())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        is_active = EXCLUDED.is_active,
        phone = EXCLUDED.phone,
        medical_certificate_status = EXCLUDED.medical_certificate_status,
        updated_at = now();

    -- Log the creation
    RAISE NOTICE 'Successfully created test accounts: studente@teamragnarok.com and instructor@teamragnarok.com';
    RAISE NOTICE 'Default password for both accounts: teamragnarok2024';

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Test accounts already exist or email constraint violation: %', SQLERRM;
        -- Try to update existing profiles if auth users were created but profiles failed
        UPDATE public.user_profiles SET
            status = 'approved'::user_status,
            is_active = true,
            medical_certificate_status = 'approved',
            updated_at = now()
        WHERE email IN ('studente@teamragnarok.com', 'instructor@teamragnarok.com');
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error creating user profiles: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error creating test accounts: %', SQLERRM;
END $$;

-- Ensure the principal admin also has proper status
UPDATE public.user_profiles 
SET 
    status = 'approved'::user_status,
    is_active = true,
    medical_certificate_status = 'approved',
    updated_at = now()
WHERE email = 'lutadordeeliteravenna@gmail.com' AND status = 'pending'::user_status;

-- Create a verification function to check account setup
CREATE OR REPLACE FUNCTION public.verify_test_accounts_setup()
RETURNS TABLE(
    email TEXT,
    auth_exists BOOLEAN,
    profile_exists BOOLEAN,
    profile_status TEXT,
    is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
BEGIN
    RETURN QUERY
    SELECT 
        test_emails.email::TEXT,
        (au.id IS NOT NULL)::BOOLEAN as auth_exists,
        (up.id IS NOT NULL)::BOOLEAN as profile_exists,
        COALESCE(up.status::TEXT, 'not_found')::TEXT as profile_status,
        COALESCE(up.is_active, false)::BOOLEAN as is_active
    FROM (
        VALUES 
            ('studente@teamragnarok.com'::TEXT),
            ('instructor@teamragnarok.com'::TEXT),
            ('lutadordeeliteravenna@gmail.com'::TEXT)
    ) as test_emails(email)
    LEFT JOIN auth.users au ON au.email = test_emails.email
    LEFT JOIN public.user_profiles up ON up.email = test_emails.email;
END;
$func$;

-- Verify the setup
SELECT * FROM public.verify_test_accounts_setup();