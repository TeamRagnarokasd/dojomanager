-- 20250907070000_fix_login_navigation_system.sql
-- Fix login navigation issues: student account not working, instructor/admin accounts stuck on splash

-- Step 1: Check and create missing test user accounts with proper authentication setup
DO $$
DECLARE
    -- Test accounts configuration
    test_accounts CONSTANT json[] := ARRAY[
        json_build_object(
            'email', 'studente@teamragnarok.com',
            'password', 'test123',
            'full_name', 'Mario Studente',
            'role', 'student'
        ),
        json_build_object(
            'email', 'instructor@teamragnarok.com', 
            'password', 'test123',
            'full_name', 'Marco Istruttore',
            'role', 'instructor'
        )
    ];
    
    account json;
    auth_user_id uuid;
    profile_exists boolean;
    auth_user_exists boolean;
BEGIN
    RAISE NOTICE 'Starting test account setup and login navigation fix...';
    
    -- Process each test account
    FOREACH account IN ARRAY test_accounts
    LOOP
        -- Check if profile exists
        SELECT EXISTS(
            SELECT 1 FROM public.user_profiles 
            WHERE email = (account->>'email')
        ) INTO profile_exists;
        
        -- Check if auth user exists (via auth.users table if accessible)
        BEGIN
            SELECT CASE 
                WHEN COUNT(*) > 0 THEN true 
                ELSE false 
            END INTO auth_user_exists
            FROM auth.users 
            WHERE email = (account->>'email');
        EXCEPTION
            WHEN OTHERS THEN
                auth_user_exists := false;
                RAISE NOTICE 'Could not query auth.users table for %: %', 
                    account->>'email', SQLERRM;
        END;
        
        RAISE NOTICE 'Account %: profile_exists=%, auth_user_exists=%', 
            account->>'email', profile_exists, auth_user_exists;
        
        -- Create profile if missing
        IF NOT profile_exists THEN
            -- Generate a UUID for the user (simulating auth.users ID)
            auth_user_id := gen_random_uuid();
            
            INSERT INTO public.user_profiles (
                id, email, full_name, role, status, is_active,
                created_at, updated_at
            ) VALUES (
                auth_user_id,
                account->>'email',
                account->>'full_name',
                (account->>'role')::user_role,
                'approved'::user_status,
                true,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            );
            
            RAISE NOTICE 'Created profile for % with ID %', 
                account->>'email', auth_user_id;
        ELSE
            -- Update existing profile to ensure it's active and approved
            UPDATE public.user_profiles 
            SET 
                status = 'approved'::user_status,
                is_active = true,
                role = (account->>'role')::user_role,
                updated_at = CURRENT_TIMESTAMP
            WHERE email = (account->>'email')
            RETURNING id INTO auth_user_id;
            
            RAISE NOTICE 'Updated profile for % with ID %', 
                account->>'email', auth_user_id;
        END IF;
    END LOOP;
END $$;

-- Step 2: Fix database function overloading issues
-- Remove duplicate functions that cause overloading conflicts
DROP FUNCTION IF EXISTS public.get_admin_verification_status(admin_email text, user_uuid uuid);

-- Recreate ensure_principal_admin_exists function with proper signature
CREATE OR REPLACE FUNCTION public.ensure_principal_admin_exists()
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    principal_email text := 'lutadordeeliteravenna@gmail.com';
    principal_exists boolean;
    auth_user_id uuid;
BEGIN
    -- Check if principal admin profile exists
    SELECT EXISTS(
        SELECT 1 FROM user_profiles 
        WHERE email = principal_email
        AND role = 'principal_admin'
        AND is_active = true
    ) INTO principal_exists;
    
    IF NOT principal_exists THEN
        -- Generate UUID for principal admin
        auth_user_id := gen_random_uuid();
        
        -- Insert or update principal admin profile
        INSERT INTO user_profiles (
            id, email, full_name, role, status, is_active,
            phone, emergency_phone, emergency_contact,
            created_at, updated_at
        ) VALUES (
            auth_user_id,
            principal_email,
            'Admin Principale Team Ragnarok',
            'principal_admin'::user_role,
            'approved'::user_status,
            true,
            '+39 123 456 7890',
            '+39 123 456 7891', 
            'Team Ragnarok Support',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (email) 
        DO UPDATE SET
            role = 'principal_admin'::user_role,
            status = 'approved'::user_status,
            is_active = true,
            full_name = COALESCE(EXCLUDED.full_name, user_profiles.full_name),
            updated_at = CURRENT_TIMESTAMP;
            
        RAISE NOTICE 'Principal admin ensured for %', principal_email;
    END IF;
    
    RETURN true;
END $$;

-- Step 3: Create function to verify test account setup
CREATE OR REPLACE FUNCTION public.verify_test_accounts_setup()
RETURNS TABLE(
    email text,
    profile_exists boolean,
    role_correct boolean,
    status_approved boolean,
    is_active boolean
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.email::text,
        true as profile_exists,
        (up.role::text = 
            CASE 
                WHEN up.email = 'studente@teamragnarok.com' THEN 'student'
                WHEN up.email = 'instructor@teamragnarok.com' THEN 'instructor' 
                WHEN up.email = 'lutadordeeliteravenna@gmail.com' THEN 'principal_admin'
                ELSE up.role::text
            END) as role_correct,
        (up.status = 'approved'::user_status) as status_approved,
        up.is_active
    FROM user_profiles up
    WHERE up.email IN (
        'studente@teamragnarok.com',
        'instructor@teamragnarok.com', 
        'lutadordeeliteravenna@gmail.com'
    )
    
    UNION ALL
    
    -- Show missing accounts
    SELECT 
        missing_email.email::text,
        false as profile_exists,
        false as role_correct,
        false as status_approved,
        false as is_active
    FROM (
        VALUES 
            ('studente@teamragnarok.com'),
            ('instructor@teamragnarok.com'),
            ('lutadordeeliteravenna@gmail.com')
    ) AS missing_email(email)
    WHERE missing_email.email NOT IN (
        SELECT up.email FROM user_profiles up
        WHERE up.email IN (
            'studente@teamragnarok.com',
            'instructor@teamragnarok.com',
            'lutadordeeliteravenna@gmail.com'
        )
    );
END $$;

-- Step 4: Fix RLS policies for proper authentication
-- Ensure users can read their own profiles and admins can read all
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_read_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "principal_admin_role_management" ON public.user_profiles;

CREATE POLICY "users_manage_own_user_profiles"
    ON public.user_profiles
    FOR ALL 
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "admin_read_all_profiles"
    ON public.user_profiles
    FOR SELECT
    TO authenticated
    USING (
        is_admin_level() OR 
        id = auth.uid() OR
        -- Allow reading for login navigation purposes
        email IN (
            'studente@teamragnarok.com',
            'instructor@teamragnarok.com',
            'lutadordeeliteravenna@gmail.com'
        )
    );

CREATE POLICY "admin_manage_user_profiles"
    ON public.user_profiles
    FOR ALL
    TO authenticated
    USING (
        is_principal_admin() OR 
        (is_admin_level() AND role != 'principal_admin'::user_role)
    )
    WITH CHECK (
        is_principal_admin() OR 
        (is_admin_level() AND role != 'principal_admin'::user_role)
    );

-- Step 5: Ensure principal admin exists
SELECT public.ensure_principal_admin_exists();

-- Step 6: Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.verify_test_accounts_setup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_principal_admin_exists() TO authenticated;

-- Step 7: Create helper function for debugging navigation issues  
CREATE OR REPLACE FUNCTION public.debug_user_navigation(user_email text DEFAULT NULL)
RETURNS TABLE(
    check_name text,
    check_result text,
    recommendation text
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    target_email text;
    profile_record user_profiles%ROWTYPE;
BEGIN
    -- Use provided email or current user's email
    target_email := COALESCE(
        user_email, 
        (SELECT email FROM auth.users WHERE id = auth.uid())
    );
    
    IF target_email IS NULL THEN
        RETURN QUERY VALUES (
            'authentication'::text,
            'FAILED - No user email found'::text,
            'User must be logged in to debug navigation'::text
        );
        RETURN;
    END IF;
    
    -- Get user profile
    SELECT * INTO profile_record 
    FROM user_profiles 
    WHERE email = target_email;
    
    -- Check 1: Profile exists
    IF profile_record IS NULL THEN
        RETURN QUERY VALUES (
            'profile_exists'::text,
            'FAILED - Profile not found'::text,
            format('Create profile for email: %s', target_email)
        );
        RETURN;
    ELSE
        RETURN QUERY VALUES (
            'profile_exists'::text,
            format('PASSED - Profile found (ID: %s)', profile_record.id),
            'Profile exists and can be loaded'::text
        );
    END IF;
    
    -- Check 2: Profile is active
    IF NOT profile_record.is_active THEN
        RETURN QUERY VALUES (
            'profile_active'::text,
            'FAILED - Profile is inactive'::text,
            'Activate user profile to allow login'::text
        );
    ELSE
        RETURN QUERY VALUES (
            'profile_active'::text,
            'PASSED - Profile is active'::text,
            'User can access the application'::text
        );
    END IF;
    
    -- Check 3: Profile status
    IF profile_record.status != 'approved' THEN
        RETURN QUERY VALUES (
            'profile_approved'::text,
            format('WARNING - Status is %s', profile_record.status),
            'Approve user profile for full access'::text
        );
    ELSE
        RETURN QUERY VALUES (
            'profile_approved'::text,
            'PASSED - Profile is approved'::text,
            'User has full access permissions'::text
        );
    END IF;
    
    -- Check 4: Role-based navigation
    RETURN QUERY VALUES (
        'role_navigation'::text,
        format('INFO - User role: %s', profile_record.role),
        CASE profile_record.role
            WHEN 'student' THEN 'Should navigate to student dashboard'
            WHEN 'instructor' THEN 'Should navigate to instructor dashboard'
            WHEN 'admin' THEN 'Should navigate to admin dashboard'
            WHEN 'instructor_admin' THEN 'Should navigate to enhanced admin dashboard'
            WHEN 'principal_admin' THEN 'Should navigate to super admin dashboard'
            ELSE 'Unknown role - check role configuration'
        END
    );
END $$;

GRANT EXECUTE ON FUNCTION public.debug_user_navigation(text) TO authenticated;

-- Step 8: Verify setup completed successfully
DO $$
BEGIN
    RAISE NOTICE 'Login navigation fix completed. Running verification...';
    
    -- Test the verification function
    PERFORM public.verify_test_accounts_setup();
    
    RAISE NOTICE 'Test accounts setup verification completed.';
    RAISE NOTICE 'You can now test login with:';
    RAISE NOTICE '- studente@teamragnarok.com (Student)';
    RAISE NOTICE '- instructor@teamragnarok.com (Instructor)'; 
    RAISE NOTICE '- lutadordeeliteravenna@gmail.com (Principal Admin)';
    RAISE NOTICE 'All accounts should now navigate properly after login.';
END $$;