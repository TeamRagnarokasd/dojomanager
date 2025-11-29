-- Location: supabase/migrations/20250907063000_add_missing_test_user_accounts.sql
-- Schema Analysis: user_profiles table exists with auth integration
-- Integration Type: addition - adding missing test accounts
-- Dependencies: existing user_profiles table, auth.users schema

-- Add missing test user accounts for login functionality
DO $$
DECLARE
    student_uuid UUID := gen_random_uuid();
    instructor_uuid UUID := gen_random_uuid();
    admin_uuid UUID := gen_random_uuid();
BEGIN
    -- Create missing auth.users records for test accounts
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        -- Student Test Account
        (student_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'studente@teamragnarok.com', crypt('student123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Mario Rossi"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        
        -- Instructor Test Account  
        (instructor_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'istruttore@teamragnarok.com', crypt('instructor123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Luca Bianchi"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        
        -- Admin Test Account
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@teamragnarok.com', crypt('admin123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Giuseppe Verdi"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null)
    ON CONFLICT (email) DO NOTHING;

    -- Create corresponding user_profiles records
    INSERT INTO public.user_profiles (
        id, email, full_name, role, status, phone, emergency_contact, 
        emergency_phone, medical_certificate_status, is_active
    ) VALUES
        -- Student Profile
        (student_uuid, 'studente@teamragnarok.com', 'Mario Rossi', 
         'student'::public.user_role, 'approved'::public.user_status,
         '+39 331 1234567', 'Anna Rossi', '+39 331 7654321', 'approved', true),
        
        -- Instructor Profile
        (instructor_uuid, 'istruttore@teamragnarok.com', 'Luca Bianchi',
         'instructor'::public.user_role, 'approved'::public.user_status,
         '+39 342 1234567', 'Maria Bianchi', '+39 342 7654321', 'approved', true),
        
        -- Admin Profile
        (admin_uuid, 'admin@teamragnarok.com', 'Giuseppe Verdi',
         'admin'::public.user_role, 'approved'::public.user_status,
         '+39 333 1234567', 'Francesca Verdi', '+39 333 7654321', 'approved', true)
    ON CONFLICT (email) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        phone = EXCLUDED.phone,
        emergency_contact = EXCLUDED.emergency_contact,
        emergency_phone = EXCLUDED.emergency_phone,
        medical_certificate_status = EXCLUDED.medical_certificate_status,
        is_active = EXCLUDED.is_active,
        updated_at = CURRENT_TIMESTAMP;

    RAISE NOTICE 'Successfully created test user accounts: studente@teamragnarok.com, istruttore@teamragnarok.com, admin@teamragnarok.com';

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error during user creation: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error (accounts may already exist): %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error during user creation: %', SQLERRM;
END $$;

-- Verify the accounts were created successfully
DO $$
DECLARE
    student_count INTEGER;
    instructor_count INTEGER;
    admin_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO student_count 
    FROM public.user_profiles 
    WHERE email = 'studente@teamragnarok.com';
    
    SELECT COUNT(*) INTO instructor_count 
    FROM public.user_profiles 
    WHERE email = 'istruttore@teamragnarok.com';
    
    SELECT COUNT(*) INTO admin_count 
    FROM public.user_profiles 
    WHERE email = 'admin@teamragnarok.com';
    
    RAISE NOTICE 'Verification - Student account: %, Instructor account: %, Admin account: %', 
        student_count, instructor_count, admin_count;
END $$;