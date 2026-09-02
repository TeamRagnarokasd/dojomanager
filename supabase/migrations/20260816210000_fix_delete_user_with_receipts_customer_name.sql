-- Migration: Fix safe_delete_user_with_receipts receipt detection
-- Problem: The function counted/deleted receipts using WHERE created_by = target_user_id
--          but receipts are created by the ADMIN (created_by = admin UUID), not the user.
--          Receipts belong to a user via customer_name ILIKE user's full_name
--          OR via batch_transaction_id linked to payment_confirmations.
-- Fix: Count and delete receipts using the correct criteria (customer_name + batch_transaction_id).

CREATE OR REPLACE FUNCTION public.safe_delete_user_with_receipts(target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deletion_summary jsonb := '{}'::jsonb;
    records_deleted INTEGER;
    target_email TEXT;
    target_full_name TEXT;
    receipts_count INTEGER := 0;
BEGIN
    -- Get user email and full_name for receipt matching and admin protection
    SELECT email, full_name
    INTO target_email, target_full_name
    FROM public.user_profiles
    WHERE id = target_user_id;

    -- Prevent deletion of principal admin
    IF target_email = 'lutadordeeliteravenna@gmail.com' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Impossibile eliminare l''amministratore principale');
    END IF;

    -- ✅ FIX: Count receipts correctly:
    --   1. customer_name matches user's full_name (admin fills this when creating receipt)
    --   2. batch_transaction_id linked to user's confirmed payment_confirmations
    --   3. created_by = target_user_id (fallback: receipts created directly by the user)
    SELECT COALESCE(COUNT(*), 0) INTO receipts_count
    FROM public.non_fiscal_receipts r
    WHERE
        (target_full_name IS NOT NULL AND r.customer_name ILIKE target_full_name)
        OR (
            r.batch_transaction_id IS NOT NULL
            AND r.batch_transaction_id IN (
                SELECT pc.batch_transaction_id
                FROM public.payment_confirmations pc
                WHERE pc.user_id = target_user_id
                  AND pc.batch_transaction_id IS NOT NULL
            )
        )
        OR r.created_by = target_user_id;

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

    -- 5. Delete pending registrations by user_id AND email
    BEGIN
        DELETE FROM public.pending_registrations WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{pending_registrations_by_user_id}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{pending_registrations_by_user_id}', to_jsonb(0));
    END;

    BEGIN
        IF target_email IS NOT NULL THEN
            DELETE FROM public.pending_registrations WHERE LOWER(TRIM(email)) = LOWER(TRIM(target_email));
            GET DIAGNOSTICS records_deleted = ROW_COUNT;
            deletion_summary := jsonb_set(deletion_summary, '{pending_registrations_by_email}', to_jsonb(records_deleted));
        END IF;
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{pending_registrations_by_email}', to_jsonb(0));
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

    -- 11. ✅ FIX: Delete receipts using correct criteria:
    --   - customer_name matches user's full_name
    --   - OR batch_transaction_id linked to user's payment_confirmations
    --   - OR created_by = target_user_id (fallback)
    BEGIN
        DELETE FROM public.non_fiscal_receipts
        WHERE
            (target_full_name IS NOT NULL AND customer_name ILIKE target_full_name)
            OR (
                batch_transaction_id IS NOT NULL
                AND batch_transaction_id IN (
                    SELECT pc.batch_transaction_id
                    FROM public.payment_confirmations pc
                    WHERE pc.user_id = target_user_id
                      AND pc.batch_transaction_id IS NOT NULL
                )
            )
            OR created_by = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{receipts_deleted}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{receipts_deleted}', to_jsonb(0));
        deletion_summary := jsonb_set(deletion_summary, '{receipts_error}', to_jsonb(SQLERRM));
    END;

    -- 12. Delete member belts
    BEGIN
        DELETE FROM public.member_belts WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{member_belts}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{member_belts}', to_jsonb(0));
    END;

    -- 13. Delete child profiles
    BEGIN
        DELETE FROM public.child_profiles WHERE guardian_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{child_profiles}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{child_profiles}', to_jsonb(0));
    END;

    -- 14. Delete instructor profiles (if user was an instructor)
    BEGIN
        DELETE FROM public.instructor_profiles WHERE user_id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{instructor_profiles}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{instructor_profiles}', to_jsonb(0));
    END;

    -- 15. Delete user profile
    BEGIN
        DELETE FROM public.user_profiles WHERE id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{user_profile}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        deletion_summary := jsonb_set(deletion_summary, '{user_profile}', to_jsonb(0));
        deletion_summary := jsonb_set(deletion_summary, '{user_profile_error}', to_jsonb(SQLERRM));
    END;

    -- 16. Delete from auth.users so the email is freed for re-registration
    BEGIN
        DELETE FROM auth.users WHERE id = target_user_id;
        GET DIAGNOSTICS records_deleted = ROW_COUNT;
        deletion_summary := jsonb_set(deletion_summary, '{auth_user}', to_jsonb(records_deleted));
    EXCEPTION WHEN OTHERS THEN
        -- Log but don't fail — profile is already deleted
        deletion_summary := jsonb_set(deletion_summary, '{auth_user}', to_jsonb(0));
        deletion_summary := jsonb_set(deletion_summary, '{auth_user_error}', to_jsonb(SQLERRM));
    END;

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
