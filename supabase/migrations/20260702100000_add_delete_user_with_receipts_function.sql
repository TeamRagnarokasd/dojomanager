-- Location: supabase/migrations/20260702100000_add_delete_user_with_receipts_function.sql
-- Adds a variant of safe_delete_user that also deletes associated receipts

CREATE OR REPLACE FUNCTION public.safe_delete_user_with_receipts(target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deletion_summary jsonb := '{}'::jsonb;
    records_deleted INTEGER;
    target_email TEXT;
BEGIN
    -- Get user email for logging
    SELECT email INTO target_email FROM public.user_profiles WHERE id = target_user_id;

    -- Prevent deletion of principal admin
    IF target_email = 'lutadordeeliteravenna@gmail.com' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Impossibile eliminare l''amministratore principale');
    END IF;

    -- 1. Delete subscription entry usage
    DELETE FROM public.subscription_entry_usage WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{subscription_entry_usage}', to_jsonb(records_deleted));

    -- 2. Delete user subscriptions
    DELETE FROM public.user_subscriptions WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{user_subscriptions}', to_jsonb(records_deleted));

    -- 3. Delete class registrations
    DELETE FROM public.class_registrations WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{class_registrations}', to_jsonb(records_deleted));

    -- 4. Delete payment confirmations
    DELETE FROM public.payment_confirmations WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{payment_confirmations}', to_jsonb(records_deleted));

    -- 5. Delete pending registrations
    DELETE FROM public.pending_registrations WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{pending_registrations}', to_jsonb(records_deleted));

    -- 6. Delete admin communications
    DELETE FROM public.admin_communications WHERE recipient_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{admin_communications}', to_jsonb(records_deleted));

    -- 7. Delete user session activity
    DELETE FROM public.user_session_activity WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{session_activity}', to_jsonb(records_deleted));

    -- 8. Delete app sessions
    DELETE FROM public.app_sessions WHERE user_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{app_sessions}', to_jsonb(records_deleted));

    -- 9. Delete admin sessions
    DELETE FROM public.admin_sessions WHERE admin_id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{admin_sessions}', to_jsonb(records_deleted));

    -- 10. Clean up activity log
    UPDATE public.admin_activity_log
    SET performed_by = NULL
    WHERE performed_by = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{activity_log_cleaned}', to_jsonb(records_deleted));

    -- 11. DELETE receipts associated with this user (instead of preserving them)
    DELETE FROM public.non_fiscal_receipts
    WHERE created_by = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{receipts_deleted}', to_jsonb(records_deleted));

    -- 12. Delete user profile
    DELETE FROM public.user_profiles WHERE id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{user_profile}', to_jsonb(records_deleted));

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Utente e ricevute associate eliminati con successo',
        'deleted_user_id', target_user_id,
        'summary', deletion_summary
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'detail', SQLSTATE
        );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.safe_delete_user_with_receipts(UUID) TO authenticated;
