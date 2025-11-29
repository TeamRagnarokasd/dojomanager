-- FINAL FIX: Completely replace the problematic create_student_registration function
-- This removes ALL unnecessary checks and makes registration simple

CREATE OR REPLACE FUNCTION public.create_student_registration(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT DEFAULT NULL,
    birth_date DATE DEFAULT NULL,
    codice_fiscale TEXT DEFAULT NULL,
    address_line TEXT DEFAULT NULL,
    city TEXT DEFAULT NULL,
    province TEXT DEFAULT NULL,
    cap TEXT DEFAULT NULL,
    emergency_contact TEXT DEFAULT NULL,
    emergency_phone TEXT DEFAULT NULL,
    is_minor BOOLEAN DEFAULT false,
    parent_guardian_name TEXT DEFAULT NULL,
    parent_guardian_surname TEXT DEFAULT NULL,
    parent_guardian_codice_fiscale TEXT DEFAULT NULL,
    parent_guardian_email TEXT DEFAULT NULL,
    parent_guardian_phone TEXT DEFAULT NULL,
    parent_guardian_relation TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    profile_created BOOLEAN := false;
    pending_created BOOLEAN := false;
BEGIN
    -- SIMPLE: Just try to create the user profile
    -- Let unique constraints handle duplicates naturally
    BEGIN
        INSERT INTO public.user_profiles (
            id, email, full_name, phone, birth_date, codice_fiscale,
            address_line, city, province, cap, emergency_contact, 
            emergency_phone, is_minor, role, status,
            parent_guardian_name, parent_guardian_surname,
            parent_guardian_codice_fiscale, parent_guardian_email,
            parent_guardian_phone, parent_guardian_relation,
            medical_certificate_status
        ) VALUES (
            user_id, LOWER(TRIM(email)), full_name, phone, birth_date, codice_fiscale,
            address_line, city, province, cap, emergency_contact,
            emergency_phone, is_minor, 'student'::public.user_role, 'pending'::public.user_status,
            parent_guardian_name, parent_guardian_surname,
            parent_guardian_codice_fiscale, parent_guardian_email,
            parent_guardian_phone, parent_guardian_relation,
            'pending'
        );
        
        profile_created := true;
        
    EXCEPTION 
        WHEN unique_violation THEN
            -- If email already exists, return a simple error
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Email già registrata nel sistema. Se sei già un utente, prova ad accedere invece di registrarti.'
            );
        WHEN OTHERS THEN
            -- For any other error, return the actual error
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Errore durante la creazione del profilo: ' || SQLERRM
            );
    END;

    -- Create the pending registration entry
    IF profile_created THEN
        BEGIN
            INSERT INTO public.pending_registrations (
                email, full_name, phone, requested_role, status, message
            ) VALUES (
                LOWER(TRIM(email)), full_name, phone, 'student', 'pending',
                'Nuova richiesta di registrazione studente: ' || full_name || 
                CASE 
                    WHEN is_minor AND parent_guardian_name IS NOT NULL 
                    THEN ' (MINORE - Genitore/Tutore: ' || parent_guardian_name || ')'
                    ELSE ''
                END
            );
            
            pending_created := true;
            
        EXCEPTION WHEN OTHERS THEN
            -- If pending registration fails, still return success since profile was created
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Profilo creato con successo. Errore nella creazione della registrazione in sospeso: ' || SQLERRM
            );
        END;
    END IF;

    -- Return success if both operations completed
    IF profile_created AND pending_created THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Registrazione completata con successo. La richiesta è in attesa di approvazione da parte dell''amministratore.'
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Errore imprevisto durante il processo di registrazione'
        );
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Errore generale durante la registrazione: ' || SQLERRM
    );
END;
$$;

-- Add comment to track this final fix
COMMENT ON FUNCTION public.create_student_registration(UUID, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) 
IS 'FINAL FIX: Completely simplified registration function. No unnecessary checks, just insert and let constraints handle duplicates.';
