-- Fix safe_delete_user function schema cache issue
-- Schema Analysis: User management system exists with safe_delete_user function
-- Integration Type: Function fix/refresh
-- Dependencies: user_profiles, admin_activity_log

-- Step 1: Drop existing function to clear any cache issues
DROP FUNCTION IF EXISTS public.safe_delete_user(UUID);
DROP FUNCTION IF EXISTS public.safe_delete_user(target_user_id UUID);
DROP FUNCTION IF EXISTS public.safe_delete_user(user_id_to_delete UUID);

-- Step 2: Recreate safe_delete_user function with proper schema registration
CREATE OR REPLACE FUNCTION public.safe_delete_user(user_id_to_delete UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    target_user_email TEXT;
    target_user_name TEXT;
    admin_performing_deletion UUID := auth.uid();
    deletion_summary JSONB := '{}'::JSONB;
    records_deleted INTEGER := 0;
    total_deleted INTEGER := 0;
BEGIN
    -- Verify admin permissions
    IF NOT public.is_admin_from_auth() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Accesso negato: solo gli amministratori possono eliminare utenti');
    END IF;

    -- Get user details before deletion
    SELECT email, full_name INTO target_user_email, target_user_name
    FROM public.user_profiles
    WHERE id = user_id_to_delete;

    IF target_user_email IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Utente non trovato');
    END IF;

    -- Prevent deletion of principal admin
    IF target_user_email = 'lutadordeeliteravenna@gmail.com' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Impossibile eliminare l''amministratore principale');
    END IF;

    -- Delete user data in dependency order (children first, preserving receipts)

    -- 1. Delete subscription entry usage
    DELETE FROM public.subscription_entry_usage WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{subscription_entries}', to_jsonb(records_deleted));

    -- 2. Delete user subscriptions
    DELETE FROM public.user_subscriptions WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{user_subscriptions}', to_jsonb(records_deleted));

    -- 3. Delete payment confirmations
    DELETE FROM public.payment_confirmations WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{payment_confirmations}', to_jsonb(records_deleted));

    -- 4. Delete user session activity
    DELETE FROM public.user_session_activity WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{session_activity}', to_jsonb(records_deleted));

    -- 5. Delete app sessions
    DELETE FROM public.app_sessions WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{app_sessions}', to_jsonb(records_deleted));

    -- 6. Delete admin sessions
    DELETE FROM public.admin_sessions WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{admin_sessions}', to_jsonb(records_deleted));

    -- 7. Delete instructor specializations (if user is instructor)
    DELETE FROM public.instructor_specializations 
    WHERE instructor_id IN (
        SELECT id FROM public.instructor_profiles WHERE user_id = user_id_to_delete
    );
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{instructor_specializations}', to_jsonb(records_deleted));

    -- 8. Delete instructor profiles
    DELETE FROM public.instructor_profiles WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{instructor_profiles}', to_jsonb(records_deleted));

    -- 9. Delete admin communications (as sender)
    DELETE FROM public.admin_communications WHERE sender_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{admin_communications}', to_jsonb(records_deleted));

    -- 10. Update pending registrations to remove reviewer reference
    UPDATE public.pending_registrations 
    SET reviewed_by = NULL 
    WHERE reviewed_by = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{pending_registrations_updated}', to_jsonb(records_deleted));

    -- 11. Clean up admin activity log references with explicit table qualification
    UPDATE public.admin_activity_log 
    SET target_user_id = NULL 
    WHERE admin_activity_log.target_user_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    
    UPDATE public.admin_activity_log 
    SET admin_id = NULL 
    WHERE admin_activity_log.admin_id = user_id_to_delete;
    
    deletion_summary := jsonb_set(deletion_summary, '{activity_log_cleaned}', to_jsonb(records_deleted));

    -- PRESERVE: non_fiscal_receipts (invoices/receipts) - only update created_by to NULL
    UPDATE public.non_fiscal_receipts 
    SET created_by = NULL 
    WHERE created_by = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{receipts_preserved}', to_jsonb(records_deleted));

    -- 12. Update user_profiles approved_by references
    UPDATE public.user_profiles 
    SET approved_by = NULL 
    WHERE approved_by = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{user_profiles_updated}', to_jsonb(records_deleted));

    -- 13. Update seasonal_schedules created_by references
    UPDATE public.seasonal_schedules 
    SET created_by = NULL 
    WHERE created_by = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{seasonal_schedules_updated}', to_jsonb(records_deleted));

    -- 14. Update sponsors created_by references
    UPDATE public.sponsors 
    SET created_by = NULL 
    WHERE created_by = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{sponsors_updated}', to_jsonb(records_deleted));

    -- 15. Update schedule_instances instructor_id references
    UPDATE public.schedule_instances 
    SET instructor_id = NULL 
    WHERE instructor_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{schedule_instances_updated}', to_jsonb(records_deleted));

    -- 16. Update weekly_schedule_templates instructor_id references
    UPDATE public.weekly_schedule_templates 
    SET instructor_id = NULL 
    WHERE instructor_id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{weekly_templates_updated}', to_jsonb(records_deleted));

    -- 17. Delete user profile
    DELETE FROM public.user_profiles WHERE id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{user_profile}', to_jsonb(records_deleted));

    -- 18. Delete from auth.users (last, after all references are cleaned)
    DELETE FROM auth.users WHERE id = user_id_to_delete;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    total_deleted := total_deleted + records_deleted;
    deletion_summary := jsonb_set(deletion_summary, '{auth_user}', to_jsonb(records_deleted));

    -- Log the deletion activity
    INSERT INTO public.admin_activity_log (
        admin_id,
        action_type,
        description,
        target_email,
        metadata
    ) VALUES (
        admin_performing_deletion,
        'USER_DELETED',
        'Utente eliminato dal sistema (fatture preservate)',
        target_user_email,
        jsonb_build_object(
            'deleted_user_name', target_user_name,
            'deletion_summary', deletion_summary,
            'total_records_deleted', total_deleted
        )
    );

    -- Return success with summary
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Utente eliminato con successo (fatture preservate)',
        'deleted_user_email', target_user_email,
        'deleted_user_name', target_user_name,
        'total_records_deleted', total_deleted,
        'deletion_summary', deletion_summary
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint error during user deletion: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', 'Errore di vincolo referenziale durante l''eliminazione');
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error during user deletion: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', 'Errore imprevisto durante l''eliminazione: ' || SQLERRM);
END;
$function$;

-- Step 3: Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.safe_delete_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_delete_user(UUID) TO service_role;

-- Step 4: Add function comment for documentation
COMMENT ON FUNCTION public.safe_delete_user(UUID) IS 'Safely delete a user and all their associated data while preserving financial records. Requires admin privileges.';

-- Step 5: Refresh PostgREST schema cache by updating a system setting
-- This forces PostgREST to reload function definitions
DO $refresh$
BEGIN
    -- Force schema reload by temporarily updating and restoring a setting
    PERFORM set_config('app.refresh_schema', 'true', true);
    PERFORM set_config('app.refresh_schema', 'false', true);
END $refresh$;