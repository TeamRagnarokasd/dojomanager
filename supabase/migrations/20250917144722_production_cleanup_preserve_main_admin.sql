-- Location: supabase/migrations/20250917144722_production_cleanup_preserve_main_admin.sql
-- Schema Analysis: Comprehensive Team Ragnarok database with complete auth, business, and operational tables
-- Integration Type: Production Cleanup - Remove all test/mock data while preserving main admin
-- Dependencies: Existing user_profiles, auth.users, and all related tables

-- Enhanced production cleanup function to preserve only the main admin user
CREATE OR REPLACE FUNCTION public.cleanup_all_test_data_preserve_main_admin()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    cleanup_count INTEGER;
    main_admin_id UUID;
BEGIN
    RAISE NOTICE 'Starting enhanced production cleanup - preserving only main admin (lutadordeeliteravenna@gmail.com)...';
    
    -- Get the main admin ID
    SELECT id INTO main_admin_id 
    FROM public.user_profiles 
    WHERE email = 'lutadordeeliteravenna@gmail.com' 
    LIMIT 1;
    
    IF main_admin_id IS NULL THEN
        RAISE NOTICE 'Main admin user not found, creating it...';
        
        -- Create the main admin user in auth.users if it doesn't exist
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
            'lutadordeeliteravenna@gmail.com', crypt('Magnus833cc', gen_salt('bf', 10)), now(), 
            now(), now(),
            '{"full_name": "Amministratore Principale"}'::jsonb, 
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        )
        ON CONFLICT (email) DO NOTHING;
        
        -- Get the admin ID after creation
        SELECT id INTO main_admin_id 
        FROM auth.users 
        WHERE email = 'lutadordeeliteravenna@gmail.com';
        
        -- Create user profile for main admin
        INSERT INTO public.user_profiles (
            id, email, full_name, role, status, is_active, 
            phone, emergency_phone, emergency_contact, 
            medical_certificate_status, approved_at
        ) VALUES (
            main_admin_id, 'lutadordeeliteravenna@gmail.com', 'Amministratore Principale', 
            'principal_admin'::public.user_role, 'approved'::public.user_status, true,
            '+39 123 456 7890', '+39 123 456 7891', 'Team Ragnarok Support',
            'approved', CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO UPDATE SET
            role = 'principal_admin'::public.user_role,
            status = 'approved'::public.user_status,
            is_active = true,
            medical_certificate_status = 'approved',
            approved_at = CURRENT_TIMESTAMP;
    END IF;

    RAISE NOTICE 'Main admin preserved with ID: %', main_admin_id;
    
    -- Step 1: Clean up dependent data in correct order (children first)
    DELETE FROM public.subscription_entry_usage 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % subscription entry usage records', cleanup_count;
    
    DELETE FROM public.user_subscriptions 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % user subscription records', cleanup_count;
    
    DELETE FROM public.payment_confirmations 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % payment confirmations', cleanup_count;
    
    DELETE FROM public.app_sessions 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % app sessions', cleanup_count;
    
    DELETE FROM public.user_session_activity 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % user session activity records', cleanup_count;
    
    DELETE FROM public.admin_sessions 
    WHERE user_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % admin sessions', cleanup_count;
    
    DELETE FROM public.admin_communications 
    WHERE sender_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % admin communications', cleanup_count;
    
    DELETE FROM public.non_fiscal_receipts 
    WHERE created_by != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % non-fiscal receipts', cleanup_count;
    
    -- Step 2: Clean up schedule-related data
    DELETE FROM public.schedule_instances 
    WHERE instructor_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % schedule instances', cleanup_count;
    
    DELETE FROM public.weekly_schedule_templates 
    WHERE instructor_id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % weekly schedule templates', cleanup_count;
    
    DELETE FROM public.seasonal_holidays;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % seasonal holidays', cleanup_count;
    
    DELETE FROM public.seasonal_schedules 
    WHERE created_by != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % seasonal schedules', cleanup_count;
    
    -- Step 3: Clean up sponsor data (keep structure but remove test sponsors)
    UPDATE public.sponsors 
    SET status = 'inactive'::public.sponsor_status
    WHERE created_by != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Deactivated % test sponsors', cleanup_count;
    
    -- Step 4: Clean up admin activity logs (keep system logs from main admin)
    DELETE FROM public.admin_activity_log 
    WHERE admin_id != main_admin_id 
    AND target_user_id != main_admin_id 
    AND target_user_id IS NOT NULL;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % admin activity logs', cleanup_count;
    
    -- Step 5: Clean up pending registrations
    DELETE FROM public.pending_registrations 
    WHERE reviewed_by != main_admin_id OR reviewed_by IS NULL;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % pending registrations', cleanup_count;
    
    -- Step 6: Clean up test user profiles (preserve only main admin)
    DELETE FROM public.user_profiles 
    WHERE id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % test user profiles', cleanup_count;
    
    -- Step 7: Clean up auth.users (preserve only main admin)
    DELETE FROM auth.users 
    WHERE id != main_admin_id;
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Cleaned up % test auth users', cleanup_count;
    
    -- Step 8: Reset subscription plans to production state
    UPDATE public.subscription_plans 
    SET 
        description = CASE 
            WHEN plan_type = 'single_entry'::public.subscription_plan_type THEN 'Ingresso singolo per allenamento'
            WHEN plan_type = 'multi_entry'::public.subscription_plan_type AND entry_count = 10 THEN 'Pacchetto di 10 ingressi per allenamenti'
            ELSE description
        END,
        sumup_url = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE sumup_url IS NOT NULL OR description LIKE '%test%' OR description LIKE '%Test%';
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RAISE NOTICE 'Reset % subscription plans for production', cleanup_count;
    
    -- Step 9: Update organization info timestamp
    UPDATE public.organization_info 
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id IS NOT NULL;
    
    -- Step 10: User approval stats view will automatically update when user data changes
    -- No action needed as user_approval_stats is a view that reflects current user_profiles data
    RAISE NOTICE 'User approval stats view will automatically reflect the updated user data';
    
    RAISE NOTICE '=== PRODUCTION CLEANUP COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE 'Preserved main admin user: lutadordeeliteravenna@gmail.com';
    RAISE NOTICE 'All test data, mock users, and unnecessary records have been removed';
    RAISE NOTICE 'The application is now ready for production use';
    RAISE NOTICE 'Database contains only:';
    RAISE NOTICE '- Main admin user (lutadordeeliteravenna@gmail.com)';
    RAISE NOTICE '- Core organizational data';
    RAISE NOTICE '- Essential system configuration';
    RAISE NOTICE '- Production-ready subscription plans';
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint error during cleanup: %', SQLERRM;
        RAISE EXCEPTION 'Cleanup failed due to foreign key constraints. Manual intervention required.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error during cleanup: %', SQLERRM;
        RAISE EXCEPTION 'Production cleanup failed: %', SQLERRM;
END;
$function$;

-- Execute the enhanced cleanup function
SELECT public.cleanup_all_test_data_preserve_main_admin();

-- Verify the cleanup results
DO $$
DECLARE
    user_count INTEGER;
    admin_email TEXT;
    view_stats RECORD;
BEGIN
    SELECT COUNT(*), MAX(email) INTO user_count, admin_email
    FROM public.user_profiles;
    
    -- Check the view statistics after cleanup
    SELECT * INTO view_stats FROM public.user_approval_stats LIMIT 1;
    
    RAISE NOTICE '=== CLEANUP VERIFICATION ===';
    RAISE NOTICE 'Remaining users in system: %', user_count;
    RAISE NOTICE 'Main admin email: %', admin_email;
    RAISE NOTICE 'View stats - Total: %, Active: %, Approved: %', 
        view_stats.total_users, view_stats.active_users, view_stats.approved_users;
    
    IF user_count = 1 AND admin_email = 'lutadordeeliteravenna@gmail.com' THEN
        RAISE NOTICE '✅ SUCCESS: Only main admin user remains';
        RAISE NOTICE '✅ SUCCESS: User approval stats view automatically updated';
    ELSE
        RAISE NOTICE '⚠️  WARNING: Unexpected user count or email';
    END IF;
END $$;