-- ============================================================================
-- REGISTRATION SECURITY DEFINER RPCs
-- Purpose: Allow new users to save their profile and documents during
--          registration, bypassing RLS (which blocks them because they have
--          no active session yet or their session is brand-new).
-- IMPORTANT: These functions do NOT touch deletion logic, session persistence,
--            main auth flow, or user roles.
-- ============================================================================

-- Drop all existing overloads of these functions to avoid ambiguity errors
DROP FUNCTION IF EXISTS public.upsert_registration_profile CASCADE;
DROP FUNCTION IF EXISTS public.save_registration_document CASCADE;
DROP FUNCTION IF EXISTS public.create_pending_registration CASCADE;

-- ============================================================================
-- 1. upsert_registration_profile
--    Called right after signUp() to persist all personal data into user_profiles.
--    Uses INSERT ... ON CONFLICT DO UPDATE so it is safe to call even if a
--    partial profile already exists.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upsert_registration_profile(
    p_user_id            UUID,
    p_email              TEXT,
    p_full_name          TEXT,
    p_first_name         TEXT,
    p_last_name          TEXT,
    p_phone              TEXT,
    p_birth_date         DATE,
    p_birth_place        TEXT,
    p_codice_fiscale     TEXT,
    p_address_line       TEXT,
    p_city               TEXT,
    p_province           TEXT,
    p_cap                TEXT,
    p_emergency_contact  TEXT,
    p_emergency_phone    TEXT,
    p_is_minor           BOOLEAN DEFAULT false,
    p_parent_guardian_name               TEXT DEFAULT NULL,
    p_parent_guardian_surname            TEXT DEFAULT NULL,
    p_parent_guardian_codice_fiscale     TEXT DEFAULT NULL,
    p_parent_guardian_email              TEXT DEFAULT NULL,
    p_parent_guardian_phone              TEXT DEFAULT NULL,
    p_parent_guardian_relation           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (
        id,
        email,
        full_name,
        first_name,
        last_name,
        phone,
        birth_date,
        birth_place,
        codice_fiscale,
        address_line,
        city,
        province,
        cap,
        emergency_contact,
        emergency_phone,
        is_minor,
        role,
        status,
        parent_guardian_name,
        parent_guardian_surname,
        parent_guardian_codice_fiscale,
        parent_guardian_email,
        parent_guardian_phone,
        parent_guardian_relation,
        medical_certificate_status
    ) VALUES (
        p_user_id,
        LOWER(TRIM(p_email)),
        p_full_name,
        p_first_name,
        p_last_name,
        p_phone,
        p_birth_date,
        TRIM(p_birth_place),
        UPPER(TRIM(p_codice_fiscale)),
        p_address_line,
        p_city,
        UPPER(TRIM(p_province)),
        p_cap,
        p_emergency_contact,
        p_emergency_phone,
        p_is_minor,
        'student'::public.user_role,
        'pending'::public.user_status,
        CASE WHEN p_is_minor THEN p_parent_guardian_name ELSE NULL END,
        CASE WHEN p_is_minor THEN p_parent_guardian_surname ELSE NULL END,
        CASE WHEN p_is_minor THEN UPPER(TRIM(p_parent_guardian_codice_fiscale)) ELSE NULL END,
        CASE WHEN p_is_minor THEN p_parent_guardian_email ELSE NULL END,
        CASE WHEN p_is_minor THEN p_parent_guardian_phone ELSE NULL END,
        CASE WHEN p_is_minor THEN p_parent_guardian_relation ELSE NULL END,
        'pending'
    )
    ON CONFLICT (id) DO UPDATE SET
        email                           = EXCLUDED.email,
        full_name                       = EXCLUDED.full_name,
        first_name                      = EXCLUDED.first_name,
        last_name                       = EXCLUDED.last_name,
        phone                           = EXCLUDED.phone,
        birth_date                      = EXCLUDED.birth_date,
        birth_place                     = EXCLUDED.birth_place,
        codice_fiscale                  = EXCLUDED.codice_fiscale,
        address_line                    = EXCLUDED.address_line,
        city                            = EXCLUDED.city,
        province                        = EXCLUDED.province,
        cap                             = EXCLUDED.cap,
        emergency_contact               = EXCLUDED.emergency_contact,
        emergency_phone                 = EXCLUDED.emergency_phone,
        is_minor                        = EXCLUDED.is_minor,
        parent_guardian_name            = EXCLUDED.parent_guardian_name,
        parent_guardian_surname         = EXCLUDED.parent_guardian_surname,
        parent_guardian_codice_fiscale  = EXCLUDED.parent_guardian_codice_fiscale,
        parent_guardian_email           = EXCLUDED.parent_guardian_email,
        parent_guardian_phone           = EXCLUDED.parent_guardian_phone,
        parent_guardian_relation        = EXCLUDED.parent_guardian_relation,
        updated_at                      = NOW();

    RETURN jsonb_build_object('success', true);

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Email già registrata nel sistema.'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_registration_profile(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
    BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) TO anon, authenticated;

COMMENT ON FUNCTION public.upsert_registration_profile IS
'SECURITY DEFINER: Bypasses RLS to save user profile during initial registration. Safe: only inserts/updates the row matching p_user_id.';

-- ============================================================================
-- 2. save_registration_document
--    Called after the terms document is uploaded to storage, to insert the
--    metadata row into user_documents (which is also RLS-protected).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_registration_document(
    p_user_id       UUID,
    p_file_name     TEXT,
    p_file_url      TEXT,
    p_file_type     TEXT DEFAULT 'document',
    p_document_type TEXT DEFAULT 'terms_acceptance',
    p_document_label TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_documents (
        user_id,
        file_name,
        file_url,
        file_type,
        document_type,
        document_label
    ) VALUES (
        p_user_id,
        p_file_name,
        p_file_url,
        p_file_type,
        p_document_type,
        p_document_label
    );

    RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_registration_document(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT
) TO anon, authenticated;

COMMENT ON FUNCTION public.save_registration_document IS
'SECURITY DEFINER: Bypasses RLS to insert a document metadata row during registration. Only inserts rows for the provided user_id.';

-- ============================================================================
-- 3. create_pending_registration
--    Called to insert into pending_registrations during registration.
--    (Separate from the profile upsert so each step can be retried independently.)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_pending_registration(
    p_email         TEXT,
    p_full_name     TEXT,
    p_phone         TEXT DEFAULT NULL,
    p_message       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only insert if no pending registration already exists for this email
    INSERT INTO public.pending_registrations (
        email, full_name, phone, requested_role, status, message
    )
    SELECT
        LOWER(TRIM(p_email)),
        p_full_name,
        p_phone,
        'student',
        'pending',
        COALESCE(p_message, 'Nuova richiesta di registrazione studente: ' || p_full_name)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.pending_registrations
        WHERE email = LOWER(TRIM(p_email))
    );

    RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_pending_registration(TEXT, TEXT, TEXT, TEXT)
TO anon, authenticated;

COMMENT ON FUNCTION public.create_pending_registration IS
'SECURITY DEFINER: Bypasses RLS to insert a pending_registrations row during initial registration.';
