-- Fixed instructor creation function with corrected parameter ordering
-- File: 20241006223100_add_password_parameter_to_instructor_creation.sql

-- Drop existing function and recreate with proper parameter ordering
DROP FUNCTION IF EXISTS public.create_instructor_profile(text, text, text, text, text, text[], integer, text);

CREATE OR REPLACE FUNCTION public.create_instructor_profile(
    instructor_email text,
    instructor_name text,
    instructor_phone text,
    instructor_bio text,
    primary_discipline text,
    selected_disciplines text[],
    years_of_experience integer,
    instructor_password text DEFAULT NULL, -- FIXED: Moved to end with other defaults
    profile_image_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    new_user_id UUID;
    new_instructor_id UUID;
    primary_discipline_enum public.discipline_type;
    disciplines_array public.discipline_type[];
    hashed_password TEXT;
    normalized_email TEXT;
BEGIN
    -- Normalize email
    normalized_email := LOWER(TRIM(instructor_email));
    
    RAISE NOTICE '=== INSTRUCTOR CREATION: % ===', normalized_email;
    
    -- ========================================================================
    -- STEP 1: Check if email exists in EITHER table
    -- This is the ONLY check - done BEFORE generating UUIDs
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
    -- STEP 3: Generate NEW random UUIDs and handle password
    -- ========================================================================
    new_user_id := gen_random_uuid();
    new_instructor_id := gen_random_uuid();
    
    -- NEW: Use provided password or generate a random one
    IF instructor_password IS NOT NULL AND length(trim(instructor_password)) >= 6 THEN
        -- Hash the provided password using crypt function
        hashed_password := crypt(instructor_password, gen_salt('bf', 10));
        RAISE NOTICE 'Using provided password';
    ELSE
        -- Generate random password as fallback
        hashed_password := '$2a$10$' || md5(random()::text || clock_timestamp()::text);
        RAISE NOTICE 'Generated random password (no valid password provided)';
    END IF;
    
    RAISE NOTICE 'Generated new user_id: %', new_user_id;

    -- Validate disciplines
    BEGIN
        primary_discipline_enum := primary_discipline::public.discipline_type;
        disciplines_array := selected_disciplines::public.discipline_type[];
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida');
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
            hashed_password, -- NEW: Use properly hashed password
            now(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            jsonb_build_object('full_name', instructor_name),
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
            RETURN jsonb_build_object('success', false, 'error', SQLERRM);
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
            'approved'::public.user_status, -- Instructors are auto-approved
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
            RETURN jsonb_build_object('success', false, 'error', SQLERRM);
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
            RETURN jsonb_build_object('success', false, 'error', SQLERRM);
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
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.create_instructor_profile TO authenticated;

-- Add comment explaining the enhancement
COMMENT ON FUNCTION public.create_instructor_profile IS 'Enhanced function to create instructor profiles with custom password for immediate login access. The instructor can change their password later from their profile.';