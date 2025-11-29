-- Location: supabase/migrations/20250928183449_cleanup_test_users.sql
-- Schema Analysis: Existing user management system with safe_delete_user function
-- Integration Type: data cleanup - remove test users
-- Dependencies: user_profiles table, safe_delete_user function

-- Clean up test users: "Dany Pri" and "Antonio Rizzo" and all their associated data
-- Using the existing safe_delete_user function to ensure proper cleanup while preserving invoices

DO $$
DECLARE
    dany_pri_id UUID;
    antonio_rizzo_id UUID;
    deletion_result JSONB;
BEGIN
    -- Get the IDs of the test users to delete
    SELECT id INTO dany_pri_id 
    FROM public.user_profiles 
    WHERE email = 'danyssj4@yahoo.it' AND full_name = 'Dany Pri';
    
    SELECT id INTO antonio_rizzo_id 
    FROM public.user_profiles 
    WHERE email = 'antonio@gmail.com' AND full_name = 'Antonio Rizzo';

    -- Delete Dany Pri user and all associated data
    IF dany_pri_id IS NOT NULL THEN
        SELECT public.safe_delete_user(dany_pri_id) INTO deletion_result;
        RAISE NOTICE 'Dany Pri deletion result: %', deletion_result;
    ELSE
        RAISE NOTICE 'Dany Pri user not found - may already be deleted';
    END IF;

    -- Delete Antonio Rizzo user and all associated data  
    IF antonio_rizzo_id IS NOT NULL THEN
        SELECT public.safe_delete_user(antonio_rizzo_id) INTO deletion_result;
        RAISE NOTICE 'Antonio Rizzo deletion result: %', deletion_result;
    ELSE
        RAISE NOTICE 'Antonio Rizzo user not found - may already be deleted';
    END IF;

    -- Log the cleanup activity
    INSERT INTO public.admin_activity_log (
        admin_id,
        action_type,
        description,
        metadata
    ) VALUES (
        (SELECT id FROM public.user_profiles WHERE email = 'lutadordeeliteravenna@gmail.com' LIMIT 1),
        'TEST_DATA_CLEANUP',
        'Removed test users: Dany Pri and Antonio Rizzo with all associated data',
        jsonb_build_object(
            'deleted_users', ARRAY['danyssj4@yahoo.it', 'antonio@gmail.com'],
            'cleanup_reason', 'Test user removal as requested',
            'invoices_preserved', true
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error during test user cleanup: %', SQLERRM;
END $$;