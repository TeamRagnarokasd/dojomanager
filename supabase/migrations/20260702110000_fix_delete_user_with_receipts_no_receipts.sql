-- Location: supabase/migrations/20260702110000_fix_delete_user_with_receipts_no_receipts.sql
-- Fix: safe_delete_user_with_receipts should succeed even when user has no receipts
-- Also returns receipts_count so Flutter can show appropriate confirmation message

CREATE OR REPLACE FUNCTION public.safe_delete_user_with_receipts(target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deletion_summary jsonb := '{}'::jsonb;
    records_deleted INTEGER;
    target_email TEXT;
    receipts_count INTEGER := 0;
BEGIN
    -- Get user email for logging
    SELECT email INTO target_email FROM public.user_profiles WHERE id = target_user_id;

    -- Prevent deletion of principal admin
    IF target_email = 'lutadordeeliteravenna@gmail.com' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Impossibile eliminare l''amministratore principale');
    END IF;

    -- Count receipts before deletion (for informational message)
    SELECT COALESCE(COUNT(*), 0) INTO receipts_count
    FROM public.non_fiscal_receipts
    WHERE created_by = target_user_id;

    -- 1. Delete subscription entry usage
    BEGIN
        DELETE FROM public.subscription_entry_usage WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{subscription_entry_usage}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{subscription_entry_usage}', to_jsonb(0));
    END;

    -- 2. Delete user subscriptions
    BEGIN
        DELETE FROM public.user_subscriptions WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{user_subscriptions}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{user_subscriptions}', to_jsonb(0));
    END;

    -- 3. Delete class registrations
    BEGIN
        DELETE FROM public.class_registrations WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{class_registrations}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{class_registrations}', to_jsonb(0));
    END;

    -- 4. Delete payment confirmations
    BEGIN
        DELETE FROM public.payment_confirmations WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{payment_confirmations}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{payment_confirmations}', to_jsonb(0));
    END;

    -- 5. Delete pending registrations
    BEGIN
        DELETE FROM public.pending_registrations WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{pending_registrations}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{pending_registrations}', to_jsonb(0));
    END;

    -- 6. Delete admin communications
    BEGIN
        DELETE FROM public.admin_communications WHERE recipient_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{admin_communications}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{admin_communications}', to_jsonb(0));
    END;

    -- 7. Delete user session activity
    BEGIN
        DELETE FROM public.user_session_activity WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{session_activity}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{session_activity}', to_jsonb(0));
    END;

    -- 8. Delete app sessions
    BEGIN
        DELETE FROM public.app_sessions WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{app_sessions}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{app_sessions}', to_jsonb(0));
    END;

    -- 9. Delete admin sessions
    BEGIN
        DELETE FROM public.admin_sessions WHERE admin_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{admin_sessions}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{admin_sessions}', to_jsonb(0));
    END;

    -- 10. Clean up activity log
    BEGIN
        UPDATE public.admin_activity_log
        SET performed_by = NULL
        WHERE performed_by = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{activity_log_cleaned}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{activity_log_cleaned}', to_jsonb(0));
    END;

    -- 11. DELETE receipts associated with this user (0 rows is fine - no error)
    BEGIN
        DELETE FROM public.non_fiscal_receipts
        WHERE created_by = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{receipts_deleted}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{receipts_deleted}', to_jsonb(0));
    END;

    -- 12. Delete user profile
    DELETE FROM public.user_profiles WHERE id = target_user_id;
    GET DIAGNOSTICS records_deleted = ROW_COUNT;
    deletion_summary := jsonb_set(deletion_summary, '{user_profile}', to_jsonb(records_deleted));

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE
            WHEN receipts_count = 0 THEN 'Utente eliminato con successo. Nessuna ricevuta associata trovata.'
            ELSE 'Utente e ' || receipts_count || ' ricevuta/e associate eliminati con successo.'
        END,
        'receipts_count', receipts_count,
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
