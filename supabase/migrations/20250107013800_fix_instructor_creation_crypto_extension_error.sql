-- Location: supabase/migrations/20250107013800_fix_instructor_creation_crypto_extension_error.sql
-- Schema Analysis: Fixing gen_random_bytes() error in instructor creation functions
-- Integration Type: Modification - Replace crypto dependency with compatible alternatives
-- Dependencies: user_profiles, instructor_profiles, auth.users

-- STEP 1: Replace the problematic create_instructor_profile function with crypto-safe version
CREATE OR REPLACE FUNCTION public.create_instructor_profile(
    instructor_email text, 
    instructor_name text, 
    instructor_phone text, 
    instructor_bio text, 
    primary_discipline text, 
    selected_disciplines text[], 
    years_of_experience integer, 
    instructor_password text DEFAULT NULL::text, 
    profile_image_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    new_user_id UUID;
    new_instructor_id UUID;
    primary_discipline_enum public.discipline_type;
    disciplines_array public.discipline_type[];
    hashed_password TEXT;
    normalized_email TEXT;
    salt_string TEXT;
BEGIN
    -- Normalize email
    normalized_email := LOWER(TRIM(instructor_email));
    
    RAISE NOTICE '=== INSTRUCTOR CREATION: % ===', normalized_email;
    
    -- ========================================================================
    -- STEP 1: Check if email exists in EITHER table
    -- ========================================================================
    IF EXISTS (
        SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email
        UNION ALL
        SELECT 1 FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email
    ) THEN
        RAISE NOTICE 'Email already exists';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Un istruttore con questa email esiste già nel sistema'
        );
    END IF;
    
    RAISE NOTICE 'Email available - proceeding';
    
    -- ========================================================================
    -- STEP 2: Acquire lock AFTER check
    -- ========================================================================
    PERFORM pg_advisory_xact_lock(hashtext(normalized_email));
    
    -- ========================================================================
    -- STEP 3: Generate NEW random UUIDs and handle password (CRYPTO-SAFE)
    -- ========================================================================
    new_user_id := gen_random_uuid();
    new_instructor_id := gen_random_uuid();
    
    -- FIXED: Use crypto-safe password hashing without gen_random_bytes()
    IF instructor_password IS NOT NULL AND length(trim(instructor_password)) >= 6 THEN
        -- Use gen_salt() with bcrypt for proper password hashing
        hashed_password := crypt(instructor_password, gen_salt('bf', 10));
        RAISE NOTICE 'Using provided password with bcrypt hashing';
    ELSE
        -- Generate a fallback hash using available functions
        salt_string := gen_salt('bf', 10);
        hashed_password := crypt('defaultPassword123!', salt_string);
        RAISE NOTICE 'Generated default password hash (password should be changed)';
    END IF;
    
    RAISE NOTICE 'Generated new user_id: %', new_user_id;

    -- Validate disciplines
    BEGIN
        primary_discipline_enum := primary_discipline::public.discipline_type;
        disciplines_array := selected_disciplines::public.discipline_type[];
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida: ' || SQLERRM);
    END;

    -- ========================================================================
    -- STEP 4: Insert into auth.users with proper password
    -- ========================================================================
    BEGIN
        RAISE NOTICE 'Inserting auth.users...';
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, aud, role,
            created_at, updated_at, confirmation_token, recovery_token,
            email_confirm_token, phone_confirm_token
        ) VALUES (
            new_user_id,
            '00000000-0000-0000-0000-000000000000',
            normalized_email,
            hashed_password,
            now(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            jsonb_build_object('full_name', instructor_name, 'role', 'instructor'),
            'authenticated',
            'authenticated',
            now(),
            now(),
            '',
            '',
            '',
            ''
        );
        RAISE NOTICE '✅ auth.users created';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '❌ Unique violation in auth.users';
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Un istruttore con questa email esiste già nel sistema'
            );
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Error in auth.users: %', SQLERRM;
            RETURN jsonb_build_object('success', false, 'error', 'Errore nella creazione utente: ' || SQLERRM);
    END;

    -- ========================================================================
    -- STEP 5: Insert into user_profiles with EXPLICIT 'instructor' role
    -- ========================================================================
    BEGIN
        RAISE NOTICE 'Inserting user_profiles with role=instructor...';
        INSERT INTO public.user_profiles (
            id,
            email,
            full_name,
            role,
            status,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            normalized_email,
            instructor_name,
            'instructor'::public.user_role,
            'approved'::public.user_status,
            true,
            now(),
            now()
        );
        RAISE NOTICE '✅ user_profiles created';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '❌ Unique violation in user_profiles';
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Un istruttore con questa email esiste già nel sistema'
            );
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Error in user_profiles: %', SQLERRM;
            RETURN jsonb_build_object('success', false, 'error', 'Errore nella creazione profilo: ' || SQLERRM);
    END;

    -- ========================================================================
    -- STEP 6: Insert into instructor_profiles
    -- ========================================================================
    BEGIN
        RAISE NOTICE 'Inserting instructor_profiles...';
        INSERT INTO public.instructor_profiles (
            id,
            user_id,
            bio,
            phone,
            primary_discipline,
            disciplines,
            years_experience,
            profile_image_url,
            is_active,
            join_date,
            created_at,
            updated_at
        ) VALUES (
            new_instructor_id,
            new_user_id,
            instructor_bio,
            instructor_phone,
            primary_discipline_enum,
            disciplines_array,
            years_of_experience,
            profile_image_url,
            true,
            CURRENT_DATE,
            now(),
            now()
        );
        RAISE NOTICE '✅ instructor_profiles created';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Error in instructor_profiles: %', SQLERRM;
            RETURN jsonb_build_object('success', false, 'error', 'Errore nella creazione profilo istruttore: ' || SQLERRM);
    END;

    RAISE NOTICE '=== ✅ SUCCESS - Instructor created with login access ===';
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', new_user_id::text,
        'instructor_id', new_instructor_id::text,
        'email', normalized_email,
        'role', 'instructor',
        'message', 'Istruttore creato con successo. Può ora accedere al sistema con la password fornita.'
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Unexpected error: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', 'Errore imprevisto: ' || SQLERRM);
END;
$function$;

-- STEP 2: Also update the simple function to be consistent
CREATE OR REPLACE FUNCTION public.create_instructor_profile_simple(
    instructor_email text, 
    instructor_name text, 
    instructor_phone text, 
    instructor_bio text, 
    primary_discipline text, 
    selected_disciplines text[], 
    years_of_experience integer, 
    instructor_password text DEFAULT 'password123'::text, 
    profile_image_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    new_user_id UUID;
    new_instructor_id UUID;
    primary_discipline_enum public.discipline_type;
    disciplines_array public.discipline_type[];
    normalized_email TEXT;
    hashed_password TEXT;
BEGIN
    -- Normalize email
    normalized_email := LOWER(TRIM(instructor_email));
    
    -- Check if email exists
    IF EXISTS (
        SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email
        UNION ALL
        SELECT 1 FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Un istruttore con questa email esiste già nel sistema'
        );
    END IF;
    
    -- Generate UUIDs
    new_user_id := gen_random_uuid();
    new_instructor_id := gen_random_uuid();

    -- Generate proper password hash using available crypto functions
    hashed_password := crypt(instructor_password, gen_salt('bf', 10));

    -- Validate disciplines
    BEGIN
        primary_discipline_enum := primary_discipline::public.discipline_type;
        disciplines_array := selected_disciplines::public.discipline_type[];
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida');
    END;

    -- Insert into auth.users with proper bcrypt hash
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, aud, role,
        created_at, updated_at, confirmation_token, recovery_token,
        email_confirm_token, phone_confirm_token
    ) VALUES (
        new_user_id,
        '00000000-0000-0000-0000-000000000000',
        normalized_email,
        hashed_password,
        now(),
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
        jsonb_build_object('full_name', instructor_name, 'role', 'instructor'),
        'authenticated',
        'authenticated',
        now(),
        now(),
        '', '', '', ''
    );

    -- Insert into user_profiles
    INSERT INTO public.user_profiles (
        id, email, full_name, role, status, is_active, created_at, updated_at
    ) VALUES (
        new_user_id, normalized_email, instructor_name,
        'instructor'::public.user_role, 'approved'::public.user_status,
        true, now(), now()
    );

    -- Insert into instructor_profiles
    INSERT INTO public.instructor_profiles (
        id, user_id, bio, phone, primary_discipline, disciplines, years_experience,
        profile_image_url, is_active, join_date, created_at, updated_at
    ) VALUES (
        new_instructor_id, new_user_id, instructor_bio, instructor_phone,
        primary_discipline_enum, disciplines_array, years_of_experience,
        profile_image_url, true, CURRENT_DATE, now(), now()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', new_user_id::text,
        'instructor_id', new_instructor_id::text,
        'email', normalized_email,
        'role', 'instructor',
        'message', 'Istruttore creato con successo!'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Errore: ' || SQLERRM);
END;
$function$;

-- STEP 3: Add a helper function for testing the fix
CREATE OR REPLACE FUNCTION public.test_crypto_functions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    test_salt TEXT;
    test_hash TEXT;
    test_result BOOLEAN;
BEGIN
    -- Test if crypto functions work
    BEGIN
        test_salt := gen_salt('bf', 10);
        test_hash := crypt('testpassword', test_salt);
        test_result := (crypt('testpassword', test_hash) = test_hash);
        
        RETURN jsonb_build_object(
            'crypto_available', true,
            'salt_generation', 'working',
            'password_hashing', 'working',
            'hash_verification', test_result,
            'message', 'Crypto functions sono disponibili e funzionanti'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'crypto_available', false,
                'error', SQLERRM,
                'message', 'Crypto functions non disponibili: ' || SQLERRM
            );
    END;
END;
$function$;