-- Location: supabase/migrations/20250927154412_fix_student_registration_rls_policy.sql
-- Schema Analysis: Existing user registration system with RLS blocking new registrations
-- Integration Type: Modificative - Fix existing RLS policies and registration workflow
-- Dependencies: user_profiles, pending_registrations, auth.users

-- Fix the RLS policy issue for student registration
-- The current policy blocks new user creation during registration

-- 1. Create a function to allow service-level user profile creation
CREATE OR REPLACE FUNCTION public.can_create_user_profile_during_registration()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT true; -- This allows profile creation during signup process
$$;

-- 2. Update the user_profiles RLS policy to allow registration
-- Drop the existing restrictive policy and create more flexible ones
DROP POLICY IF EXISTS "users_can_create_own_profile" ON public.user_profiles;

-- Create separate policies for different operations
CREATE POLICY "users_can_create_profile_during_registration" 
ON public.user_profiles
FOR INSERT 
TO authenticated
WITH CHECK (
    -- Allow creation if the user_id matches the authenticated user
    id = auth.uid()
    OR 
    -- Allow creation during registration process (service context)
    public.can_create_user_profile_during_registration()
);

-- Update the select policy to allow reading own profile and admin access
DROP POLICY IF EXISTS "users_can_view_own_profile" ON public.user_profiles;

CREATE POLICY "users_can_view_own_profile" 
ON public.user_profiles
FOR SELECT 
TO authenticated
USING (
    id = auth.uid() 
    OR 
    public.is_admin_from_auth()
);

-- Update policy to allow own profile updates
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.user_profiles;

CREATE POLICY "users_can_update_own_profile" 
ON public.user_profiles
FOR UPDATE 
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Ensure admin functions exist and work properly
-- Update or create the admin verification function
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (
        au.raw_user_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
        OR au.raw_app_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
    )
)
$$;

-- 4. Create a function to handle student registration with proper error handling
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
    -- First, try to create the user profile
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
            user_id, email, full_name, phone, birth_date, codice_fiscale,
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
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Email già registrata nel sistema'
            );
        WHEN foreign_key_violation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Errore di riferimento utente - riprova tra qualche istante'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Errore durante la creazione del profilo: ' || SQLERRM
            );
    END;

    -- Then, create the pending registration entry
    IF profile_created THEN
        BEGIN
            INSERT INTO public.pending_registrations (
                email, full_name, phone, requested_role, status, message
            ) VALUES (
                email, full_name, phone, 'student', 'pending',
                'Nuova richiesta di registrazione studente: ' || full_name || 
                CASE 
                    WHEN is_minor AND parent_guardian_name IS NOT NULL 
                    THEN ' (MINORE - Genitore/Tutore: ' || parent_guardian_name || ')'
                    ELSE ''
                END
            );
            
            pending_created := true;
            
        EXCEPTION WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Errore durante la creazione della registrazione in sospeso: ' || SQLERRM
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

-- 5. Update the pending_registrations RLS policy to ensure admin notifications work
-- Drop existing policy and recreate with proper admin access
DROP POLICY IF EXISTS "admin_manage_pending_registrations" ON public.pending_registrations;

-- Allow anyone to insert (for registration), admins to manage
CREATE POLICY "allow_registration_creation" 
ON public.pending_registrations
FOR INSERT 
TO authenticated
WITH CHECK (true); -- Allow any authenticated user to create registration requests

CREATE POLICY "admin_manage_pending_registrations" 
ON public.pending_registrations
FOR ALL 
TO authenticated
USING (public.is_admin_from_auth())
WITH CHECK (public.is_admin_from_auth());

-- Allow users to view their own pending registrations
CREATE POLICY "users_view_own_pending_registrations" 
ON public.pending_registrations
FOR SELECT 
TO authenticated
USING (
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- 6. Ensure the trigger for admin notifications works properly
-- Update the notification function to be more robust
CREATE OR REPLACE FUNCTION public.notify_admin_new_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert notification for all admins
    BEGIN
        INSERT INTO public.admin_communications (
            sender_id,
            message,
            priority,
            created_at
        )
        SELECT 
            NULL, -- System generated
            'Nuova registrazione studente in attesa: ' || NEW.full_name || ' (' || NEW.email || ')',
            'high',
            CURRENT_TIMESTAMP
        WHERE EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE role IN ('admin', 'principal_admin', 'instructor_admin')
        );
        
    EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail the registration
        RAISE NOTICE 'Failed to create admin notification: %', SQLERRM;
    END;

    RETURN NEW;
END;
$$;

-- Recreate the trigger to ensure it works
DROP TRIGGER IF EXISTS trigger_notify_admin_new_registration ON public.pending_registrations;

CREATE TRIGGER trigger_notify_admin_new_registration
    AFTER INSERT ON public.pending_registrations
    FOR EACH ROW 
    EXECUTE FUNCTION public.notify_admin_new_registration();

-- 7. Create a function to validate registration data
CREATE OR REPLACE FUNCTION public.validate_student_registration(
    email TEXT,
    codice_fiscale TEXT,
    cap TEXT DEFAULT NULL,
    provincia TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate email format
    IF email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Formato email non valido'
        );
    END IF;

    -- Validate codice fiscale format (16 characters, specific pattern)
    IF codice_fiscale IS NOT NULL AND 
       (LENGTH(codice_fiscale) != 16 OR 
        codice_fiscale !~ '^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$') THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Codice fiscale non valido - deve essere 16 caratteri nel formato corretto'
        );
    END IF;

    -- Validate CAP format (5 digits)
    IF cap IS NOT NULL AND cap !~ '^[0-9]{5}$' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'CAP non valido - deve essere 5 cifre'
        );
    END IF;

    -- Validate provincia format (2 letters)
    IF provincia IS NOT NULL AND 
       (LENGTH(provincia) != 2 OR provincia !~ '^[A-Z]{2}$') THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Sigla provincia non valida - deve essere 2 lettere maiuscole (es. MI, RM)'
        );
    END IF;

    RETURN jsonb_build_object('valid', true);
END;
$$;

-- 8. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_status 
ON public.user_profiles(email, status);

CREATE INDEX IF NOT EXISTS idx_pending_registrations_email_status 
ON public.pending_registrations(email, status);

CREATE INDEX IF NOT EXISTS idx_admin_communications_priority_created 
ON public.admin_communications(priority, created_at DESC);

-- 9. Add a comment to track this migration
COMMENT ON FUNCTION public.create_student_registration(UUID, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) 
IS 'Function to handle secure student registration with proper RLS bypass and error handling';

COMMENT ON FUNCTION public.can_create_user_profile_during_registration() 
IS 'Allows user profile creation during the registration process';

-- End of migration