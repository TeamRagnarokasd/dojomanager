-- Location: supabase/migrations/20250830190000_team_ragnarok_admin_management_system.sql
-- Team Ragnarok Admin Management System Migration
-- Creates role-based access control and admin management capabilities

-- 1. Create user role enum with hierarchy
CREATE TYPE public.user_role AS ENUM ('student', 'instructor', 'admin', 'instructor_admin', 'principal_admin');

-- 2. Create user profiles table (intermediary for PostgREST compatibility)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'student'::public.user_role,
    phone TEXT,
    birth_date DATE,
    emergency_contact TEXT,
    emergency_phone TEXT,
    medical_certificate_status TEXT DEFAULT 'pending',
    is_active BOOLEAN DEFAULT true,
    approved_by UUID REFERENCES public.user_profiles(id),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create pending registrations table for admin approval
CREATE TABLE public.pending_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    phone TEXT,
    requested_role public.user_role DEFAULT 'instructor'::public.user_role,
    message TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES public.user_profiles(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create admin activity log
CREATE TABLE public.admin_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    target_user_id UUID REFERENCES public.user_profiles(id),
    target_email TEXT,
    old_role TEXT,
    new_role TEXT,
    description TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Create session management table
CREATE TABLE public.admin_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    session_token TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Essential Indexes
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX idx_user_profiles_active ON public.user_profiles(is_active);
CREATE INDEX idx_pending_registrations_status ON public.pending_registrations(status);
CREATE INDEX idx_admin_activity_log_admin_id ON public.admin_activity_log(admin_id);
CREATE INDEX idx_admin_activity_log_created_at ON public.admin_activity_log(created_at);
CREATE INDEX idx_admin_sessions_user_id ON public.admin_sessions(user_id);
CREATE INDEX idx_admin_sessions_expires_at ON public.admin_sessions(expires_at);

-- 7. Enable RLS for all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;

-- 8. Create helper functions for role checking
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_principal_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role = 'principal_admin'::public.user_role
    AND up.is_active = true
);
$$;

CREATE OR REPLACE FUNCTION public.is_admin_level()
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
);
$$;

-- 9. RLS Policies

-- Pattern 1: Core user table - simple ownership
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Admin read access to all profiles
CREATE POLICY "admin_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (public.is_admin_level());

-- Only principal admin can modify admin roles
CREATE POLICY "principal_admin_role_management"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (
    public.is_principal_admin() OR 
    (public.is_admin_level() AND role NOT IN ('admin', 'instructor_admin', 'principal_admin'))
)
WITH CHECK (
    public.is_principal_admin() OR 
    (public.is_admin_level() AND role NOT IN ('admin', 'instructor_admin', 'principal_admin'))
);

-- Pending registrations policies
CREATE POLICY "admin_manage_pending_registrations"
ON public.pending_registrations
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- Activity log policies
CREATE POLICY "users_view_own_activity"
ON public.admin_activity_log
FOR SELECT
TO authenticated
USING (admin_id = auth.uid());

CREATE POLICY "admin_view_all_activity"
ON public.admin_activity_log
FOR SELECT
TO authenticated
USING (public.is_admin_level());

CREATE POLICY "admin_create_activity"
ON public.admin_activity_log
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin_level() AND admin_id = auth.uid());

-- Session management policies
CREATE POLICY "users_manage_own_sessions"
ON public.admin_sessions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "admin_view_all_sessions"
ON public.admin_sessions
FOR SELECT
TO authenticated
USING (public.is_principal_admin());

-- 10. Functions for user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'student'::public.user_role)
    );
    RETURN NEW;
END;
$$;

-- Create trigger for automatic profile creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 11. Function to log admin activities
CREATE OR REPLACE FUNCTION public.log_admin_activity(
    action_type_param TEXT,
    target_user_id_param UUID DEFAULT NULL,
    target_email_param TEXT DEFAULT NULL,
    old_role_param TEXT DEFAULT NULL,
    new_role_param TEXT DEFAULT NULL,
    description_param TEXT DEFAULT '',
    metadata_param JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    activity_id UUID;
BEGIN
    INSERT INTO public.admin_activity_log (
        admin_id, action_type, target_user_id, target_email,
        old_role, new_role, description, metadata
    )
    VALUES (
        auth.uid(), action_type_param, target_user_id_param, target_email_param,
        old_role_param, new_role_param, description_param, metadata_param
    )
    RETURNING id INTO activity_id;
    
    RETURN activity_id;
END;
$$;

-- 12. Create principal admin and mock data
DO $$
DECLARE
    principal_admin_id UUID := gen_random_uuid();
    instructor_user_id UUID := gen_random_uuid();
    student_user_id UUID := gen_random_uuid();
BEGIN
    -- Create principal admin in auth.users
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (principal_admin_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'lutadordeeliteravenna@gmail.com', crypt('Magnus833cc', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Admin Principale", "role": "principal_admin"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (instructor_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'instructor@teamragnarok.com', crypt('TempPass123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Marco Istruttore", "role": "instructor"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (student_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'studente@teamragnarok.com', crypt('StudentPass123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Andrea Studente", "role": "student"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Update principal admin profile manually (bypass trigger for specific role)
    UPDATE public.user_profiles 
    SET 
        role = 'principal_admin'::public.user_role,
        full_name = 'Admin Principale Team Ragnarok',
        phone = '+39 123 456 7890',
        emergency_contact = 'Team Ragnarok Support',
        emergency_phone = '+39 123 456 7891',
        medical_certificate_status = 'approved'
    WHERE id = principal_admin_id;

    -- Create pending registrations
    INSERT INTO public.pending_registrations (email, full_name, phone, requested_role, message, status)
    VALUES
        ('nuovo_istruttore@email.com', 'Giuseppe Nuovo', '+39 333 123 4567', 'instructor', 'Esperienza 5 anni MMA', 'pending'),
        ('candidato_admin@email.com', 'Maria Candidata', '+39 333 765 4321', 'admin', 'Gestione palestre da 10 anni', 'pending');

    -- Log initial admin activity
    INSERT INTO public.admin_activity_log (admin_id, action_type, description, metadata)
    VALUES (
        principal_admin_id, 
        'SYSTEM_INITIALIZATION', 
        'Sistema di gestione amministratori inizializzato con successo',
        '{"version": "1.0", "features": ["user_management", "role_promotion", "registration_approval"]}'::jsonb
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error during setup: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error during setup: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Setup error: %', SQLERRM;
END $$;