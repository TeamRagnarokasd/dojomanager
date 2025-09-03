-- Admin Management System Migration
-- Extends existing Team Ragnarok ASD system with admin management capabilities

-- 1. Admin Registration Requests Table
CREATE TABLE public.admin_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    requested_role TEXT DEFAULT 'admin',
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    reviewed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Activity Logs Table
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details JSONB,
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Update user_profiles table to support new roles
-- Add constraint to ensure proper role values
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN ('member', 'student', 'instructor', 'admin', 'instructor_admin', 'principal_admin'));

-- 4. Essential Indexes
CREATE INDEX idx_admin_registrations_user_id ON public.admin_registrations(user_id);
CREATE INDEX idx_admin_registrations_status ON public.admin_registrations(status);
CREATE INDEX idx_admin_registrations_approved_by ON public.admin_registrations(approved_by);
CREATE INDEX idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX idx_activity_logs_timestamp ON public.activity_logs(timestamp);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);

-- 5. RLS Setup
ALTER TABLE public.admin_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies

-- Admin registrations - users can view their own, admins can view all
CREATE POLICY "users_view_own_admin_registrations"
ON public.admin_registrations
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "admins_manage_all_admin_registrations"
ON public.admin_registrations
FOR ALL
TO authenticated
USING (EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND (up.role = 'admin' OR up.role = 'principal_admin' OR up.role = 'instructor_admin')
));

-- Activity logs - users can view their own activities, admins can view all
CREATE POLICY "users_view_own_activity_logs"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "admins_view_all_activity_logs"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND (up.role = 'admin' OR up.role = 'principal_admin' OR up.role = 'instructor_admin')
));

CREATE POLICY "authenticated_users_create_activity_logs"
ON public.activity_logs
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 7. Business Logic Functions

-- Function to check if user is principal admin
CREATE OR REPLACE FUNCTION public.is_principal_admin(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = user_uuid 
    AND (up.role = 'principal_admin' OR up.email = 'lutadordeeliteravenna@gmail.com')
) OR EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = user_uuid 
    AND au.email = 'lutadordeeliteravenna@gmail.com'
);
$$;

-- Function to check if user has admin privileges
CREATE OR REPLACE FUNCTION public.has_admin_privileges(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = user_uuid 
    AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
) OR public.is_principal_admin(user_uuid);
$$;

-- Function to promote user role
CREATE OR REPLACE FUNCTION public.promote_user_role(
    target_user_id UUID,
    new_role TEXT,
    promoted_by UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    old_role TEXT;
    is_authorized BOOLEAN := false;
BEGIN
    -- Check if the promoter has principal admin privileges
    SELECT public.is_principal_admin(promoted_by) INTO is_authorized;
    
    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Solo l''admin principale può promuovere utenti';
    END IF;

    -- Get current role
    SELECT role INTO old_role FROM public.user_profiles WHERE id = target_user_id;
    
    IF old_role IS NULL THEN
        RAISE EXCEPTION 'Utente non trovato';
    END IF;

    -- Update user role
    UPDATE public.user_profiles 
    SET role = new_role, updated_at = CURRENT_TIMESTAMP
    WHERE id = target_user_id;

    -- Log the promotion activity
    INSERT INTO public.activity_logs (user_id, action, details)
    VALUES (promoted_by, 'Utente promosso', jsonb_build_object(
        'target_user_id', target_user_id,
        'old_role', old_role,
        'new_role', new_role
    ));

    RETURN true;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Errore nella promozione utente: %', SQLERRM;
END;
$$;

-- Function to approve admin registration
CREATE OR REPLACE FUNCTION public.approve_admin_registration(
    registration_id UUID,
    approved_by_user UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    registration_record RECORD;
    is_authorized BOOLEAN := false;
BEGIN
    -- Check if the approver has principal admin privileges
    SELECT public.is_principal_admin(approved_by_user) INTO is_authorized;
    
    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Solo l''admin principale può approvare registrazioni admin';
    END IF;

    -- Get registration details
    SELECT * INTO registration_record 
    FROM public.admin_registrations 
    WHERE id = registration_id AND status = 'pending';
    
    IF registration_record IS NULL THEN
        RAISE EXCEPTION 'Registrazione non trovata o già processata';
    END IF;

    -- Update registration status
    UPDATE public.admin_registrations 
    SET 
        status = 'approved',
        approved_by = approved_by_user,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_id;

    -- Promote user to admin role
    UPDATE public.user_profiles 
    SET 
        role = registration_record.requested_role,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.user_id;

    -- Log the approval activity
    INSERT INTO public.activity_logs (user_id, action, details)
    VALUES (approved_by_user, 'Registrazione admin approvata', jsonb_build_object(
        'registration_id', registration_id,
        'approved_user_id', registration_record.user_id,
        'approved_role', registration_record.requested_role
    ));

    RETURN true;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Errore nell''approvazione: %', SQLERRM;
END;
$$;

-- Function to log admin activities
CREATE OR REPLACE FUNCTION public.log_admin_activity(
    activity_user_id UUID,
    activity_action TEXT,
    activity_details JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO public.activity_logs (user_id, action, details)
    VALUES (activity_user_id, activity_action, activity_details)
    RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$;

-- 8. Triggers

-- Trigger to automatically log user role changes
CREATE OR REPLACE FUNCTION public.log_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only log if role actually changed
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        INSERT INTO public.activity_logs (user_id, action, details)
        VALUES (NEW.id, 'Ruolo modificato', jsonb_build_object(
            'old_role', OLD.role,
            'new_role', NEW.role,
            'changed_by', auth.uid()
        ));
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_user_role_change
    AFTER UPDATE ON public.user_profiles
    FOR EACH ROW
    WHEN (OLD.role IS DISTINCT FROM NEW.role)
    EXECUTE FUNCTION public.log_role_change();

-- 9. Insert principal admin if not exists
DO $$
DECLARE
    principal_admin_id UUID;
BEGIN
    -- Check if principal admin exists by email
    SELECT id INTO principal_admin_id 
    FROM public.user_profiles 
    WHERE email = 'lutadordeeliteravenna@gmail.com';
    
    -- Update existing user to principal admin or create if needed through auth.users trigger
    IF principal_admin_id IS NOT NULL THEN
        UPDATE public.user_profiles 
        SET role = 'principal_admin'
        WHERE id = principal_admin_id;
        
        -- Log the principal admin setup
        INSERT INTO public.activity_logs (user_id, action, details)
        VALUES (principal_admin_id, 'Admin principale configurato', jsonb_build_object(
            'setup_timestamp', CURRENT_TIMESTAMP,
            'setup_method', 'migration'
        ));
    END IF;
END $$;

-- 10. Sample data for testing (admin registrations and activity logs)
DO $$
DECLARE
    test_user_id UUID;
    registration_id UUID;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE email != 'lutadordeeliteravenna@gmail.com' 
    AND role = 'member' 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Create sample admin registration request
        INSERT INTO public.admin_registrations (id, user_id, requested_role, reason, status)
        VALUES (
            gen_random_uuid(),
            test_user_id,
            'admin',
            'Richiesta di accesso amministratore per gestione palestra',
            'pending'
        ) RETURNING id INTO registration_id;
        
        -- Create sample activity logs
        INSERT INTO public.activity_logs (user_id, action, details) VALUES
        (test_user_id, 'Login effettuato', jsonb_build_object('ip_address', '192.168.1.100')),
        (test_user_id, 'Profilo aggiornato', jsonb_build_object('fields_changed', jsonb_build_array('phone', 'address'))),
        (test_user_id, 'Richiesta registrazione admin', jsonb_build_object('registration_id', registration_id));
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors in sample data creation
        NULL;
END $$;