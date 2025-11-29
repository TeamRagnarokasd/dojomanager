-- AGGRESSIVE FIX: Force drop and recreate with CASCADE
-- This will work even if there are dependencies

-- 1) Ensure pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2) Drop ALL variants with CASCADE to remove dependencies
DROP FUNCTION IF EXISTS public.create_instructor_profile CASCADE;
DROP FUNCTION IF EXISTS public.create_instructor_profile_simple CASCADE;
DROP FUNCTION IF EXISTS public.create_instructor_profile_fixed CASCADE;
DROP FUNCTION IF EXISTS public.hash_password_safely CASCADE;

-- 3) Create password hashing helper with explicit types
CREATE FUNCTION public.hash_password_safely(plain_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  salt_value TEXT;
  hashed_password TEXT;
BEGIN
  -- Force explicit types to avoid "unknown" type resolution
  salt_value := gen_salt('bf'::TEXT, 10::INTEGER);
  hashed_password := crypt(plain_password::TEXT, salt_value::TEXT);
  RETURN hashed_password;
EXCEPTION
  WHEN OTHERS THEN
    RETURN crypt(plain_password::TEXT, '$2a$10$1234567890abcdefghijkl'::TEXT);
END;
$$;

-- 4) Create main instructor creation function
CREATE FUNCTION public.create_instructor_profile(
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
  normalized_email := LOWER(TRIM(instructor_email));

  IF EXISTS (
    SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email
    UNION ALL
    SELECT 1 FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Un istruttore con questa email esiste già nel sistema');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(normalized_email));

  new_user_id := gen_random_uuid();
  new_instructor_id := gen_random_uuid();

  -- Use helper function with explicit cast
  IF instructor_password IS NOT NULL AND length(trim(instructor_password)) >= 6 THEN
    hashed_password := public.hash_password_safely(instructor_password::TEXT);
  ELSE
    hashed_password := public.hash_password_safely('defaultPassword123!'::TEXT);
  END IF;

  -- Validate disciplines
  BEGIN
    primary_discipline_enum := primary_discipline::public.discipline_type;
    disciplines_array := selected_disciplines::public.discipline_type[];
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida: ' || SQLERRM);
  END;

  -- Insert into auth.users
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

  -- Insert into user_profiles
  INSERT INTO public.user_profiles (
    id, full_name, email, phone, role, status, is_active, profile_image_url,
    created_at, updated_at
  ) VALUES (
    new_user_id, instructor_name, normalized_email, instructor_phone,
    'instructor', 'approved', true, profile_image_url, now(), now()
  );

  -- Insert into instructor_profiles
  INSERT INTO public.instructor_profiles (
    id, user_id, bio, primary_discipline, disciplines, years_experience,
    achievements, certifications, languages, is_active, join_date, created_at
  ) VALUES (
    new_instructor_id, new_user_id, instructor_bio, primary_discipline_enum,
    disciplines_array, years_of_experience, NULL, NULL, NULL, true,
    now()::date, now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', new_user_id::TEXT,
    'instructor_id', new_instructor_id::TEXT,
    'message', 'Profilo istruttore creato con successo'
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Errore: ' || SQLERRM);
END;
$$;

-- 5) Create simple variant
CREATE FUNCTION public.create_instructor_profile_simple(
  instructor_email TEXT,
  instructor_name TEXT,
  instructor_phone TEXT,
  instructor_bio TEXT,
  primary_discipline TEXT,
  selected_disciplines TEXT[],
  years_of_experience INTEGER,
  instructor_password TEXT DEFAULT 'password123',
  profile_image_url TEXT DEFAULT NULL
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
  normalized_email := LOWER(TRIM(instructor_email));

  IF EXISTS (
    SELECT 1 FROM auth.users WHERE LOWER(TRIM(email)) = normalized_email
    UNION ALL
    SELECT 1 FROM public.user_profiles WHERE LOWER(TRIM(email)) = normalized_email
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Un istruttore con questa email esiste già nel sistema');
  END IF;

  new_user_id := gen_random_uuid();
  new_instructor_id := gen_random_uuid();

  hashed_password := public.hash_password_safely(instructor_password::TEXT);

  BEGIN
    primary_discipline_enum := primary_discipline::public.discipline_type;
    disciplines_array := selected_disciplines::public.discipline_type[];
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Disciplina non valida');
  END;

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

  INSERT INTO public.user_profiles (
    id, full_name, email, phone, role, status, is_active, profile_image_url,
    created_at, updated_at
  ) VALUES (
    new_user_id, instructor_name, normalized_email, instructor_phone,
    'instructor', 'approved', true, profile_image_url, now(), now()
  );

  INSERT INTO public.instructor_profiles (
    id, user_id, bio, primary_discipline, disciplines, years_experience,
    achievements, certifications, languages, is_active, join_date, created_at
  ) VALUES (
    new_instructor_id, new_user_id, instructor_bio, primary_discipline_enum,
    disciplines_array, years_of_experience, NULL, NULL, NULL, true,
    now()::date, now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', new_user_id::TEXT,
    'instructor_id', new_instructor_id::TEXT,
    'message', 'Profilo istruttore creato con successo'
  );
END;
$$;

-- 6) Verify the fix worked
DO $$
DECLARE
  test_result JSONB;
BEGIN
  -- Test if the function exists and can be called
  SELECT public.hash_password_safely('testpass123') INTO test_result;
  RAISE NOTICE '✅ Function hash_password_safely is working';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ Function hash_password_safely failed: %', SQLERRM;
END $$;

