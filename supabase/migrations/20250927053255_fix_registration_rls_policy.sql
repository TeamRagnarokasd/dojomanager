-- Fix RLS policy for user registration and admin approval workflow
-- Schema Analysis: user_profiles table exists with current RLS policies
-- Integration Type: Modification of existing RLS policies
-- Dependencies: user_profiles, pending_registrations, admin_activity_log

-- 1. Drop existing problematic policies
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_read_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "principal_admin_role_management" ON public.user_profiles;

-- 2. Create registration-friendly RLS policies for user_profiles
-- Pattern 3: Operation-specific policies for better control

-- Allow users to create their own profile during registration
CREATE POLICY "users_can_create_own_profile"
ON public.user_profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Allow users to view and update their own profile
CREATE POLICY "users_can_view_own_profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

CREATE POLICY "users_can_update_own_profile"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Allow admins to view all profiles
CREATE POLICY "admin_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (public.is_admin_from_auth());

-- Allow principal admins to manage roles and approve users
CREATE POLICY "principal_admin_role_management"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (public.is_admin_from_auth())
WITH CHECK (public.is_admin_from_auth());

-- 3. Create function to check admin status from auth metadata (safe pattern)
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (au.raw_user_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin')
         OR au.raw_app_meta_data->>'role' IN ('admin', 'principal_admin', 'instructor_admin'))
)
$$;

-- 4. Create function to approve user registration
CREATE OR REPLACE FUNCTION public.approve_user_registration(
    user_email TEXT,
    admin_comment TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_user_id UUID;
    admin_user_id UUID := auth.uid();
BEGIN
    -- Check if current user is admin
    IF NOT public.is_admin_from_auth() THEN
        RAISE EXCEPTION 'Accesso negato: solo gli amministratori possono approvare le registrazioni';
    END IF;

    -- Get user ID by email
    SELECT id INTO target_user_id
    FROM public.user_profiles
    WHERE email = user_email AND status = 'pending'::public.user_status;

    IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'Utente non trovato o già approvato';
    END IF;

    -- Update user status to approved
    UPDATE public.user_profiles
    SET 
        status = 'approved'::public.user_status,
        approved_by = admin_user_id,
        approved_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = target_user_id;

    -- Update pending registration status
    UPDATE public.pending_registrations
    SET 
        status = 'approved',
        reviewed_by = admin_user_id,
        reviewed_at = CURRENT_TIMESTAMP
    WHERE email = user_email;

    -- Log admin activity
    INSERT INTO public.admin_activity_log (
        admin_id,
        target_user_id,
        action_type,
        description
    ) VALUES (
        admin_user_id,
        target_user_id,
        'USER_APPROVED',
        COALESCE('Utente approvato: ' || admin_comment, 'Utente approvato dall''amministratore')
    );

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Errore durante l''approvazione: %', SQLERRM;
END;
$$;

-- 5. Create function to reject user registration
CREATE OR REPLACE FUNCTION public.reject_user_registration(
    user_email TEXT,
    rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_user_id UUID;
    admin_user_id UUID := auth.uid();
BEGIN
    -- Check if current user is admin
    IF NOT public.is_admin_from_auth() THEN
        RAISE EXCEPTION 'Accesso negato: solo gli amministratori possono rifiutare le registrazioni';
    END IF;

    -- Get user ID by email
    SELECT id INTO target_user_id
    FROM public.user_profiles
    WHERE email = user_email AND status = 'pending'::public.user_status;

    IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'Utente non trovato o già processato';
    END IF;

    -- Update user status to rejected
    UPDATE public.user_profiles
    SET 
        status = 'rejected'::public.user_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = target_user_id;

    -- Update pending registration status
    UPDATE public.pending_registrations
    SET 
        status = 'rejected',
        reviewed_by = admin_user_id,
        reviewed_at = CURRENT_TIMESTAMP,
        message = COALESCE(rejection_reason, 'Registrazione rifiutata dall''amministratore')
    WHERE email = user_email;

    -- Log admin activity
    INSERT INTO public.admin_activity_log (
        admin_id,
        target_user_id,
        action_type,
        description
    ) VALUES (
        admin_user_id,
        target_user_id,
        'USER_REJECTED',
        COALESCE('Utente rifiutato: ' || rejection_reason, 'Utente rifiutato dall''amministratore')
    );

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Errore durante il rifiuto: %', SQLERRM;
END;
$$;

-- 6. Create function to get pending registrations for admins
CREATE OR REPLACE FUNCTION public.get_pending_registrations()
RETURNS TABLE (
    id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ,
    message TEXT,
    user_status TEXT,
    is_minor BOOLEAN,
    medical_cert_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if current user is admin
    IF NOT public.is_admin_from_auth() THEN
        RAISE EXCEPTION 'Accesso negato: solo gli amministratori possono visualizzare le registrazioni pendenti';
    END IF;

    RETURN QUERY
    SELECT 
        pr.id,
        pr.email,
        pr.full_name,
        pr.phone,
        pr.created_at,
        pr.message,
        up.status::TEXT,
        up.is_minor,
        up.medical_certificate_status
    FROM public.pending_registrations pr
    JOIN public.user_profiles up ON pr.email = up.email
    WHERE pr.status = 'pending'
    AND up.status = 'pending'::public.user_status
    ORDER BY pr.created_at ASC;
END;
$$;

-- 7. Create notification trigger for new registrations
CREATE OR REPLACE FUNCTION public.notify_admin_new_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert notification for all admins
    INSERT INTO public.admin_communications (
        sender_id,
        message,
        priority,
        created_at
    )
    SELECT 
        NULL, -- System generated
        'Nuova registrazione in attesa di approvazione: ' || NEW.full_name || ' (' || NEW.email || ')',
        'high',
        CURRENT_TIMESTAMP
    WHERE EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE role IN ('admin', 'principal_admin', 'instructor_admin')
    );

    RETURN NEW;
END;
$$;

-- Create trigger for pending registration notifications
DROP TRIGGER IF EXISTS trigger_notify_admin_new_registration ON public.pending_registrations;
CREATE TRIGGER trigger_notify_admin_new_registration
    AFTER INSERT ON public.pending_registrations
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_admin_new_registration();

-- 8. Add priority column to admin_communications if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_communications' 
        AND column_name = 'priority'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.admin_communications 
        ADD COLUMN priority TEXT DEFAULT 'normal';
        
        CREATE INDEX idx_admin_communications_priority 
        ON public.admin_communications(priority);
    END IF;
END $$;