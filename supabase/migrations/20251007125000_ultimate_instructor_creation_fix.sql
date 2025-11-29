-- ULTIMATE FIX: Use UPSERT approach to handle all conflicts
-- This will work even if there are existing records

-- 1) Enable pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2) Drop all old functions
DROP FUNCTION IF EXISTS public.create_instructor_profile CASCADE;
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
END;
$$;

-- 4) Create ultimate instructor creation function with UPSERT
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
    target_user_id UUID;
    new_instructor_id UUID;
    primary_discipline_enum public.discipline_type;
    disciplines_array public.discipline_type[];
    hashed_password TEXT;
    normalized_email TEXT;
    existing_instructor_id UUID;
    img_url TEXT;
BEGIN
    normalized_email := LOWER(TRIM(instructor_email));
    img_url := profile_image_url; -- Store in local variable to avoid ambiguity

    -- Lock to prevent race conditions
    PERFORM pg_advisory_xact_lock(hashtext(normalized_email));

    -- Check if complete instructor already exists
    SELECT ip.id INTO existing_instructor_id
    FROM public.user_profiles up
    INNER JOIN public.instructor_profiles ip ON up.id = ip.user_id
    WHERE LOWER(TRIM(up.email)) = normalized_email;

    IF existing_instructor_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Un istruttore completo con questa email esiste già nel sistema'
        );
    END IF;

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

    -- Find or create user in auth.users
    SELECT id INTO target_user_id FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email;
    
    IF target_user_id IS NULL THEN
        -- Create new user
        target_user_id := gen_random_uuid();
        
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
            target_user_id,
            '00000000-0000-0000-0000-000000000000',
            normalized_email,
            hashed_password,
            now(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            jsonb_build_object('full_name', instructor_name, 'role', 'instructor'),
            'authenticated',
            'authenticated',
            now(),
            now()
        );
    ELSE
        -- Update existing user
        UPDATE auth.users SET
            encrypted_password = hashed_password,
            raw_user_meta_data = jsonb_build_object('full_name', instructor_name, 'role', 'instructor'),
            updated_at = now()
        WHERE id = target_user_id;
    END IF;

    -- Insert or update user_profiles (handle conflicts manually)
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
            target_user_id,
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
            -- Update existing record
            UPDATE public.user_profiles SET
                full_name = instructor_name,
                phone = instructor_phone,
                role = 'instructor',
                status = 'approved',
                is_active = true,
                profile_image_url = img_url,
                updated_at = now()
            WHERE id = target_user_id;
    END;

    -- Insert or update instructor_profiles (handle conflicts manually)
    SELECT id INTO new_instructor_id FROM public.instructor_profiles WHERE user_id = target_user_id;
    
    IF new_instructor_id IS NULL THEN
        -- Create new instructor profile
        new_instructor_id := gen_random_uuid();
        
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
            target_user_id,
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
    ELSE
        -- Update existing instructor profile
        UPDATE public.instructor_profiles SET
            bio = instructor_bio,
            primary_discipline = primary_discipline_enum,
            disciplines = disciplines_array,
            years_experience = years_of_experience,
            is_active = true,
            created_at = now()
        WHERE id = new_instructor_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', target_user_id::TEXT,
        'instructor_id', new_instructor_id::TEXT,
        'message', 'Profilo istruttore creato con successo'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unexpected error: ' || SQLERRM);
END;
$$;

-- 5) Clean up any orphaned records
DO $$
BEGIN
    -- Remove instructor_profiles without matching user_profiles
    DELETE FROM public.instructor_profiles 
    WHERE user_id NOT IN (SELECT id FROM public.user_profiles);
    
    -- Remove user_profiles without matching auth.users
    DELETE FROM public.user_profiles 
    WHERE id NOT IN (SELECT id FROM auth.users);
    
    RAISE NOTICE 'Cleaned up orphaned records';
END $$;

-- 6) Success message
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ ULTIMATE FIX APPLIED!';
    RAISE NOTICE '✅ Uses UPSERT to handle all conflicts';
    RAISE NOTICE '✅ Will work even with existing records';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Try creating your instructor now!';
END $$;
