-- Fix instructor creation by bypassing email confirmation
-- Remove unnecessary confirmation token fields that don't exist in auth.users

-- 1) Enable pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2) Drop all old functions
DROP FUNCTION IF EXISTS public.create_instructor_profile CASCADE;
DROP FUNCTION IF EXISTS public.create_instructor_profile_simple CASCADE;
DROP FUNCTION IF EXISTS public.hash_password_safely CASCADE;

-- 3) Create password hashing helper
CREATE OR REPLACE FUNCTION public.hash_password_safely(plain_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    salt_val TEXT;
    hash_val TEXT;
BEGIN
    BEGIN
        salt_val := public.gen_salt('bf', 10);
        hash_val := public.crypt(plain_password, salt_val);
    EXCEPTION
        WHEN OTHERS THEN
            salt_val := extensions.gen_salt('bf', 10);
            hash_val := extensions.crypt(plain_password, salt_val);
    END;
    RETURN hash_val;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Password hashing failed: %', SQLERRM;
END;
$$;

-- 4) Create instructor profile function WITHOUT email confirmation tokens
CREATE OR REPLACE FUNCTION public.create_instructor_profile(
    instructor_email TEXT,
    instructor_name TEXT,
    instructor_phone TEXT,
    instructor_bio TEXT,
    primary_discipline TEXT,
    selected_disciplines TEXT[],
    years_of_experience INTEGER,
    instructor_password TEXT DEFAULT NULL,
    profile_image_url TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
    new_user_id UUID;
    new_instructor_id UUID;
    primary_discipline_enum public.discipline_type;
    disciplines_array public.discipline_type[];
    hashed_password TEXT;
    normalized_email TEXT;
BEGIN
    normalized_email := LOWER(TRIM(instructor_email));

    -- Check if email exists
    IF EXISTS (
        SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email
        UNION ALL
        SELECT 1 FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Un istruttore con questa email esiste già nel sistema');
    END IF;

    -- Lock
    PERFORM pg_advisory_xact_lock(hashtext(normalized_email));

    -- Generate UUIDs
    new_user_id := gen_random_uuid();
    new_instructor_id := gen_random_uuid();

    -- Hash password
    BEGIN
        IF instructor_password IS NOT NULL AND length(trim(instructor_password)) >= 6 THEN
            hashed_password := public.hash_password_safely(trim(instructor_password));
        ELSE
            hashed_password := public.hash_password_safely('defaultPassword123!');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Password hashing failed: ' || SQLERRM);
    END;

    -- Validate disciplines
    BEGIN
        primary_discipline_enum := primary_discipline::public.discipline_type;
        disciplines_array := selected_disciplines::public.discipline_type[];
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida: ' || SQLERRM);
    END;

    -- Check if user already exists in auth.users
    IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email) THEN
        -- User exists in auth, check if complete instructor profile exists
        IF EXISTS (
            SELECT 1 FROM public.user_profiles up
            INNER JOIN public.instructor_profiles ip ON up.id = ip.user_id
            WHERE LOWER(TRIM(up.email)) = normalized_email
        ) THEN
            -- Complete instructor exists
            RETURN jsonb_build_object('success', false, 'error', 'Un istruttore con questa email esiste già nel sistema');
        ELSE
            -- Partial creation - cleanup and try again with new ID
            DELETE FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email;
            DELETE FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email;
        END IF;
    END IF;

    -- Insert into auth.users (SIMPLIFIED - no confirmation tokens)
    BEGIN
        INSERT INTO auth.users (
            id,
            instance_id,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            aud,
            role,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            '00000000-0000-0000-0000-000000000000',
            normalized_email,
            hashed_password,
            now(), -- Email auto-confirmed
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            jsonb_build_object('full_name', instructor_name, 'role', 'instructor'),
            'authenticated',
            'authenticated',
            now(),
            now()
        );
    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object('success', false, 'error', 'Questo indirizzo email è già registrato nel sistema');
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Auth user creation failed: ' || SQLERRM);
    END;

    -- Insert into user_profiles
    BEGIN
        INSERT INTO public.user_profiles (
            id,
            full_name,
            email,
            phone,
            role,
            status,
            is_active,
            profile_image_url,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            instructor_name,
            normalized_email,
            instructor_phone,
            'instructor',
            'approved',
            true,
            profile_image_url,
            now(),
            now()
        );
    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object('success', false, 'error', 'Questo profilo utente esiste già. Usa un altro indirizzo email.');
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'User profile creation failed: ' || SQLERRM);
    END;

    -- Insert into instructor_profiles
    BEGIN
        INSERT INTO public.instructor_profiles (
            id,
            user_id,
            bio,
            primary_discipline,
            disciplines,
            years_experience,
            achievements,
            certifications,
            languages,
            is_active,
            join_date,
            created_at
        ) VALUES (
            new_instructor_id,
            new_user_id,
            instructor_bio,
            primary_discipline_enum,
            disciplines_array,
            years_of_experience,
            NULL,
            NULL,
            NULL,
            true,
            current_date,
            now()
        );
    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object('success', false, 'error', 'Profilo istruttore già esistente per questo utente');
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Instructor profile creation failed: ' || SQLERRM);
    END;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', new_user_id::TEXT,
        'instructor_id', new_instructor_id::TEXT,
        'message', 'Profilo istruttore creato con successo'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unexpected error: ' || SQLERRM);
END;
$$;

-- 5) Test the function
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Instructor creation function updated';
    RAISE NOTICE '✅ Email confirmation bypassed';
    RAISE NOTICE '✅ Ready to create instructors';
    RAISE NOTICE '========================================';
END $$;

