-- 🎯 MISSION: Risolvere il conflitto di function overloading per create_instructor_profile
-- 📋 PROBLEMA: PostgrestException PGRST203 - due funzioni in conflitto con firme diverse
-- ✅ SOLUZIONE: Drop entrambe le funzioni e crearne una sola con validazione interna

-- 🗑️ DROP: Rimuovi entrambe le funzioni conflittuali
DROP FUNCTION IF EXISTS public.create_instructor_profile(text, text, text, text, text, text[], integer, text);
DROP FUNCTION IF EXISTS public.create_instructor_profile(text, text, text, text, public.discipline_type, public.discipline_type[], integer, text);

-- 🛠️ CREATE: Funzione unificata che accetta text e valida internamente
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
    validated_primary_discipline public.discipline_type;
    validated_disciplines public.discipline_type[];
    discipline_item text;
    valid_disciplines text[] := ARRAY['bjj', 'mma', 'sambo', 'grappling', 'fitness'];
BEGIN
    -- 🔐 SECURITY: Verifica privilegi admin
    IF NOT public.is_admin_level_user() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Solo gli amministratori possono creare nuovi istruttori'
        );
    END IF;

    -- 📧 EMAIL CHECK: Verifica unicità email
    IF EXISTS (SELECT 1 FROM public.user_profiles WHERE email = instructor_email) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Un utente con questa email esiste già nel sistema'
        );
    END IF;

    -- ✅ VALIDATION: Valida disciplina principale
    IF primary_discipline IS NULL OR primary_discipline = '' THEN
        primary_discipline := 'bjj';
    END IF;

    IF NOT (primary_discipline = ANY(valid_disciplines)) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Disciplina principale non valida: "%s". Valori accettati: %s', 
                primary_discipline, array_to_string(valid_disciplines, ', '))
        );
    END IF;

    -- 🎯 CAST: Disciplina principale validata
    validated_primary_discipline := primary_discipline::public.discipline_type;

    -- ✅ VALIDATION: Valida array discipline
    IF selected_disciplines IS NULL OR array_length(selected_disciplines, 1) IS NULL THEN
        selected_disciplines := ARRAY[primary_discipline];
    END IF;

    -- Verifica ogni disciplina nell'array
    FOREACH discipline_item IN ARRAY selected_disciplines LOOP
        IF NOT (discipline_item = ANY(valid_disciplines)) THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', format('Disciplina non valida nell''array: "%s". Valori accettati: %s', 
                    discipline_item, array_to_string(valid_disciplines, ', '))
            );
        END IF;
    END LOOP;

    -- 🎯 CAST: Array discipline validate
    validated_disciplines := selected_disciplines::public.discipline_type[];

    -- 🔄 ENSURE: La disciplina principale è inclusa nell'array
    IF NOT (validated_primary_discipline = ANY(validated_disciplines)) THEN
        validated_disciplines := array_append(validated_disciplines, validated_primary_discipline);
    END IF;

    -- 🆕 UUID: Genera ID per il nuovo istruttore
    new_user_id := gen_random_uuid();

    -- 👤 USER PROFILE: Crea profilo utente
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

    -- 🥋 INSTRUCTOR PROFILE: Crea profilo istruttore con enum validati
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

    -- 📝 ADMIN LOG: Registra attività amministrativa
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

    -- ✅ SUCCESS: Ritorna risultato positivo
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
    WHEN invalid_text_representation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Valore non valido per il tipo enum discipline_type'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Errore nella creazione del nuovo istruttore: %s', SQLERRM)
        );
END;
$function$;

-- 🔄 SCHEMA REFRESH: Notifica PostgREST del cambiamento
NOTIFY pgrst, 'reload schema';

-- 📝 COMMENT: Documenta la funzione
COMMENT ON FUNCTION public.create_instructor_profile IS 
'Funzione unificata per la creazione di profili istruttore. Risolve il conflitto di overloading accettando parametri text e validando internamente i tipi enum discipline_type.';