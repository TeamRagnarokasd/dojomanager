-- Location: supabase/migrations/20241001215500_fix_instructor_creation_primary_discipline_casting.sql
-- Schema Analysis: Existing instructor management system with discipline_type enum
-- Integration Type: Function modification to fix enum casting issue
-- Dependencies: instructor_profiles, user_profiles, discipline_type enum

-- Fix the create_instructor_profile function to properly handle discipline_type enum casting
CREATE OR REPLACE FUNCTION public.create_instructor_profile(
    instructor_email text, 
    instructor_name text, 
    instructor_phone text DEFAULT NULL::text, 
    instructor_bio text DEFAULT 'Nuovo istruttore del Team Ragnarok.'::text, 
    primary_discipline text DEFAULT 'bjj'::text, 
    selected_disciplines text[] DEFAULT ARRAY['bjj'::text], 
    years_of_experience integer DEFAULT 1, 
    profile_image_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    new_user_id UUID;
    result jsonb;
    validated_primary_discipline public.discipline_type;
    validated_disciplines public.discipline_type[];
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

    -- Validate and cast primary_discipline to enum
    BEGIN
        validated_primary_discipline := primary_discipline::public.discipline_type;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', format('Disciplina principale non valida: %s. Valori accettati: bjj, mma, sambo, grappling, fitness', primary_discipline)
            );
    END;

    -- Validate and cast selected_disciplines array to enum array
    BEGIN
        validated_disciplines := selected_disciplines::public.discipline_type[];
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', format('Una o più discipline selezionate non sono valide: %s. Valori accettati: bjj, mma, sambo, grappling, fitness', array_to_string(selected_disciplines, ', '))
            );
    END;

    -- Ensure primary discipline is included in selected disciplines
    IF NOT (validated_primary_discipline = ANY(validated_disciplines)) THEN
        validated_disciplines := array_append(validated_disciplines, validated_primary_discipline);
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

    -- Create instructor profile with properly cast enum values
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
        validated_primary_discipline,
        validated_disciplines,
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
            'primary_discipline', validated_primary_discipline::text,
            'disciplines', array_to_string(validated_disciplines::text[], ', ')
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
    WHEN not_null_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Campo obbligatorio mancante: %s', SQLERRM)
        );
    WHEN check_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Validazione fallita: %s', SQLERRM)
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Errore nella creazione del nuovo istruttore: %s', SQLERRM)
        );
END;
$function$;