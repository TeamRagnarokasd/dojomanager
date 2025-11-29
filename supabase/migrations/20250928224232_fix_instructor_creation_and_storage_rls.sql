-- Fix instructor creation and storage RLS policies
-- Schema Analysis: Existing instructor system with user_profiles and instructor_profiles tables
-- Integration Type: Fix storage RLS policies and provide better instructor creation method
-- Dependencies: user_profiles, instructor_profiles, storage.objects

-- 1. Create function for admin role checking using user_profiles
CREATE OR REPLACE FUNCTION public.is_admin_level_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
    AND up.is_active = true
    AND up.status = 'approved'
)
$$;

-- 2. Create function to handle instructor creation without admin API
CREATE OR REPLACE FUNCTION public.create_instructor_profile(
    instructor_email TEXT,
    instructor_name TEXT,
    instructor_phone TEXT DEFAULT NULL,
    instructor_bio TEXT DEFAULT 'Nuovo istruttore del Team Ragnarok.',
    primary_discipline discipline_type DEFAULT 'bjj',
    selected_disciplines discipline_type[] DEFAULT ARRAY['bjj'::discipline_type],
    years_of_experience INTEGER DEFAULT 1,
    profile_image_url TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id UUID;
    result jsonb;
BEGIN
    -- Check if current user has admin privileges
    IF NOT public.is_admin_level_user() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Solo gli amministratori possono creare nuovi istruttori'
        );
    END IF;

    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM public.user_profiles WHERE email = instructor_email) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Un utente con questa email esiste già nel sistema'
        );
    END IF;

    -- Generate new UUID for the instructor
    new_user_id := gen_random_uuid();

    -- Create user profile directly (without auth.admin.createUser)
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
        instructor_email,
        instructor_phone,
        'instructor'::public.user_role,
        'approved'::public.user_status,
        true,
        profile_image_url,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );

    -- Create instructor profile
    INSERT INTO public.instructor_profiles (
        user_id,
        bio,
        primary_discipline,
        disciplines,
        specializations,
        years_experience,
        achievements,
        certifications,
        languages,
        profile_image_url,
        is_active,
        join_date,
        created_at,
        updated_at
    ) VALUES (
        new_user_id,
        instructor_bio,
        primary_discipline,
        selected_disciplines,
        ARRAY[]::TEXT[],
        years_of_experience,
        ARRAY[]::TEXT[],
        ARRAY[]::TEXT[],
        ARRAY['Italiano'],
        profile_image_url,
        true,
        CURRENT_DATE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );

    -- Log admin activity
    INSERT INTO public.admin_activity_log (
        admin_id,
        action_type,
        target_user_id,
        details,
        created_at
    ) VALUES (
        auth.uid(),
        'instructor_created',
        new_user_id,
        jsonb_build_object(
            'instructor_name', instructor_name,
            'instructor_email', instructor_email,
            'primary_discipline', primary_discipline
        ),
        CURRENT_TIMESTAMP
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', new_user_id,
        'message', 'Istruttore creato con successo! L''istruttore dovrà registrarsi autonomamente per completare l''account.'
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Un istruttore con questa email esiste già nel sistema'
        );
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Errore nella creazione del profilo utente. Verifica che tutti i dati siano corretti.'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Errore nella creazione del nuovo istruttore: %s', SQLERRM)
        );
END;
$$;

-- 3. Fix storage RLS policies for instructor-images bucket
-- Drop existing problematic policies if they exist
DROP POLICY IF EXISTS "instructor_images_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "instructor_images_insert_policy" ON storage.objects;
DROP POLICY IF EXISTS "instructor_images_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "instructor_images_delete_policy" ON storage.objects;

-- Create proper RLS policies for instructor-images bucket
CREATE POLICY "instructor_images_select_policy"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
);

CREATE POLICY "instructor_images_insert_policy"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'instructor-images'
    AND public.is_admin_level_user()
);

CREATE POLICY "instructor_images_update_policy"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
)
WITH CHECK (
    bucket_id = 'instructor-images'
    AND public.is_admin_level_user()
);

CREATE POLICY "instructor_images_delete_policy"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
);

-- 4. Fix profile-images bucket policies for instructor profiles  
-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "profile_images_instructor_select" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_instructor_insert" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_instructor_update" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_instructor_delete" ON storage.objects;

-- Create additional policies for profile-images bucket for instructors
CREATE POLICY "profile_images_instructor_select"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
        OR (storage.foldername(name))[1] = 'instructors'
    )
);

CREATE POLICY "profile_images_instructor_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
);

CREATE POLICY "profile_images_instructor_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
)
WITH CHECK (
    bucket_id = 'profile-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
);

CREATE POLICY "profile_images_instructor_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (
        owner = auth.uid()
        OR public.is_admin_level_user()
    )
);

-- 5. Create helper function to check if user is instructor or admin
CREATE OR REPLACE FUNCTION public.can_manage_instructor_images()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    AND up.is_active = true
    AND up.status = 'approved'
)
$$;

-- 6. Create function to safely upload instructor image
CREATE OR REPLACE FUNCTION public.upload_instructor_image(
    instructor_id UUID,
    image_path TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    image_url TEXT;
BEGIN
    -- Check permissions
    IF NOT (public.is_admin_level_user() OR auth.uid() = instructor_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Non hai i permessi per caricare questa immagine'
        );
    END IF;

    -- Check if instructor exists
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = instructor_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Istruttore non trovato'
        );
    END IF;

    -- Update profile image URL
    UPDATE public.user_profiles 
    SET 
        profile_image_url = image_path,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = instructor_id;

    -- Also update instructor_profiles if exists
    UPDATE public.instructor_profiles 
    SET 
        profile_image_url = image_path,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = instructor_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Immagine caricata con successo',
        'image_url', image_path
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Errore nel caricamento dell''immagine: %s', SQLERRM)
        );
END;
$$;

COMMENT ON FUNCTION public.create_instructor_profile IS 'Creates instructor profile without requiring Supabase admin API access';
COMMENT ON FUNCTION public.is_admin_level_user IS 'Checks if current user has admin privileges for instructor management';
COMMENT ON FUNCTION public.can_manage_instructor_images IS 'Checks if user can manage instructor images';
COMMENT ON FUNCTION public.upload_instructor_image IS 'Safely uploads instructor profile image with proper permissions';