-- Admin Management System Migration
-- Implements role-based access control with principal admin restrictions

-- 1. Enhanced role system with more granular permissions
CREATE TYPE public.user_role AS ENUM ('member', 'instructor', 'admin', 'instructor_admin', 'principal_admin');

-- Drop existing role column and add new enum-based role
ALTER TABLE public.user_profiles DROP COLUMN role;
ALTER TABLE public.user_profiles ADD COLUMN role public.user_role DEFAULT 'member'::public.user_role;

-- 2. Admin registration requests table
CREATE TABLE public.admin_registration_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    requested_role public.user_role NOT NULL,
    request_reason TEXT,
    status TEXT DEFAULT 'pending',
    reviewed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_admin_roles CHECK (requested_role IN ('instructor', 'admin', 'instructor_admin'))
);

-- 3. User role change history for audit trail
CREATE TABLE public.user_role_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    previous_role public.user_role,
    new_role public.user_role,
    changed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    change_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Admin activity log
CREATE TABLE public.admin_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    description TEXT NOT NULL,
    target_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Essential Indexes
CREATE INDEX idx_admin_registration_requests_status ON public.admin_registration_requests(status);
CREATE INDEX idx_admin_registration_requests_requester ON public.admin_registration_requests(requester_id);
CREATE INDEX idx_user_role_changes_user_id ON public.user_role_changes(user_id);
CREATE INDEX idx_user_role_changes_changed_by ON public.user_role_changes(changed_by);
CREATE INDEX idx_admin_activities_admin_id ON public.admin_activities(admin_id);
CREATE INDEX idx_admin_activities_type ON public.admin_activities(activity_type);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);

-- 6. RLS Setup
ALTER TABLE public.admin_registration_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_role_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activities ENABLE ROW LEVEL SECURITY;

-- 7. Functions for role management

-- Function to check if user is principal admin
CREATE OR REPLACE FUNCTION public.is_principal_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.email = 'lutadordeeliteravenna@gmail.com'
    AND up.role = 'principal_admin'::public.user_role
)
$$;

-- Function to check admin level permissions
CREATE OR REPLACE FUNCTION public.has_admin_permission(required_role TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role::TEXT IN ('admin', 'instructor_admin', 'principal_admin')
    AND (required_role = 'any' OR up.role::TEXT = required_role OR up.role = 'principal_admin'::public.user_role)
)
$$;

-- Function to promote user (only principal admin)
CREATE OR REPLACE FUNCTION public.promote_user(
    target_user_id UUID,
    new_role public.user_role,
    change_reason TEXT DEFAULT 'Admin promotion'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    old_role public.user_role;
    admin_id UUID := auth.uid();
    is_principal BOOLEAN;
BEGIN
    -- Check if current user is principal admin
    SELECT public.is_principal_admin() INTO is_principal;
    
    IF NOT is_principal THEN
        RAISE EXCEPTION 'Only principal admin can promote users';
    END IF;
    
    -- Get current role
    SELECT role INTO old_role FROM public.user_profiles WHERE id = target_user_id;
    
    IF old_role IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Update user role
    UPDATE public.user_profiles 
    SET role = new_role, updated_at = CURRENT_TIMESTAMP
    WHERE id = target_user_id;
    
    -- Log the change
    INSERT INTO public.user_role_changes (user_id, previous_role, new_role, changed_by, change_reason)
    VALUES (target_user_id, old_role, new_role, admin_id, change_reason);
    
    -- Log admin activity
    INSERT INTO public.admin_activities (admin_id, activity_type, description, target_user_id, metadata)
    VALUES (
        admin_id, 
        'USER_PROMOTION', 
        'Promoted user from ' || old_role::TEXT || ' to ' || new_role::TEXT,
        target_user_id,
        jsonb_build_object('previous_role', old_role, 'new_role', new_role, 'reason', change_reason)
    );
    
    RETURN true;
END;
$$;

-- Function to approve admin registration request
CREATE OR REPLACE FUNCTION public.approve_admin_request(
    request_id UUID,
    approval_decision TEXT DEFAULT 'approved'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    request_record RECORD;
    admin_id UUID := auth.uid();
    is_principal BOOLEAN;
BEGIN
    -- Check if current user is principal admin
    SELECT public.is_principal_admin() INTO is_principal;
    
    IF NOT is_principal THEN
        RAISE EXCEPTION 'Only principal admin can approve admin requests';
    END IF;
    
    -- Get request details
    SELECT * INTO request_record 
    FROM public.admin_registration_requests 
    WHERE id = request_id AND status = 'pending';
    
    IF request_record IS NULL THEN
        RAISE EXCEPTION 'Request not found or already processed';
    END IF;
    
    -- Update request status
    UPDATE public.admin_registration_requests 
    SET status = approval_decision,
        reviewed_by = admin_id,
        reviewed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = request_id;
    
    -- If approved, promote the user
    IF approval_decision = 'approved' THEN
        PERFORM public.promote_user(
            request_record.requester_id,
            request_record.requested_role,
            'Admin request approval: ' || COALESCE(request_record.request_reason, 'No reason provided')
        );
    END IF;
    
    -- Log admin activity
    INSERT INTO public.admin_activities (admin_id, activity_type, description, target_user_id, metadata)
    VALUES (
        admin_id,
        'ADMIN_REQUEST_REVIEW',
        approval_decision || ' admin request for role: ' || request_record.requested_role::TEXT,
        request_record.requester_id,
        jsonb_build_object('request_id', request_id, 'decision', approval_decision, 'requested_role', request_record.requested_role)
    );
    
    RETURN true;
END;
$$;

-- 8. RLS Policies

-- Admin registration requests - users can create own requests, principal admin can view all
CREATE POLICY "users_create_own_admin_requests"
ON public.admin_registration_requests
FOR INSERT
TO authenticated
WITH CHECK (requester_id = auth.uid());

CREATE POLICY "users_view_own_admin_requests"
ON public.admin_registration_requests
FOR SELECT
TO authenticated
USING (requester_id = auth.uid());

CREATE POLICY "principal_admin_manage_all_requests"
ON public.admin_registration_requests
FOR ALL
TO authenticated
USING (public.is_principal_admin());

-- User role changes - users can view their own changes, admins can view all
CREATE POLICY "users_view_own_role_changes"
ON public.user_role_changes
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "admins_view_all_role_changes"
ON public.user_role_changes
FOR SELECT
TO authenticated
USING (public.has_admin_permission('any'));

-- Admin activities - only admins can view
CREATE POLICY "admins_view_admin_activities"
ON public.admin_activities
FOR SELECT
TO authenticated
USING (public.has_admin_permission('any'));

-- Update user_profiles policies to handle new role system
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;

CREATE POLICY "users_view_own_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (id = auth.uid() OR public.has_admin_permission('any'));

CREATE POLICY "users_update_own_basic_info"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid() AND role = (SELECT role FROM public.user_profiles WHERE id = auth.uid()));

CREATE POLICY "principal_admin_manage_all_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (public.is_principal_admin())
WITH CHECK (public.is_principal_admin());

-- 9. Initialize principal admin
DO $$
DECLARE
    principal_admin_id UUID;
BEGIN
    -- Check if principal admin exists
    SELECT id INTO principal_admin_id 
    FROM public.user_profiles 
    WHERE email = 'lutadordeeliteravenna@gmail.com';
    
    IF principal_admin_id IS NOT NULL THEN
        -- Update existing user to principal admin
        UPDATE public.user_profiles 
        SET role = 'principal_admin'::public.user_role,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = principal_admin_id;
        
        RAISE NOTICE 'Updated existing user to principal admin: lutadordeeliteravenna@gmail.com';
    ELSE
        -- Create principal admin if it doesn't exist
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
            created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
            is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
            recovery_token, recovery_sent_at, email_change_token_new, email_change,
            email_change_sent_at, email_change_token_current, email_change_confirm_status,
            reauthentication_token, reauthentication_sent_at, phone, phone_change,
            phone_change_token, phone_change_sent_at
        ) VALUES (
            gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'lutadordeeliteravenna@gmail.com', crypt('Magnus833cc', gen_salt('bf', 10)), now(), now(), now(),
            '{"full_name": "Principal Admin", "role": "principal_admin"}'::jsonb, 
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        );
        
        RAISE NOTICE 'Created new principal admin: lutadordeeliteravenna@gmail.com';
    END IF;
END $$;

-- 10. Sample admin request for testing
DO $$
DECLARE
    regular_user_id UUID;
    principal_admin_id UUID;
BEGIN
    -- Get regular user and principal admin IDs
    SELECT id INTO regular_user_id FROM public.user_profiles WHERE email = 'pasquale.casaburo@example.com' LIMIT 1;
    SELECT id INTO principal_admin_id FROM public.user_profiles WHERE email = 'lutadordeeliteravenna@gmail.com' LIMIT 1;
    
    IF regular_user_id IS NOT NULL THEN
        -- Create sample admin registration request
        INSERT INTO public.admin_registration_requests (
            requester_id, requested_role, request_reason
        ) VALUES (
            regular_user_id, 
            'instructor'::public.user_role,
            'I have extensive martial arts experience and would like to become an instructor to help other members.'
        );
        
        RAISE NOTICE 'Created sample admin registration request';
    END IF;
END $$;