-- Migration: Add RLS SELECT policy so users can read their own payment_confirmations
-- Root cause: Regular users had no SELECT policy on payment_confirmations, causing
-- the direct Dart query `FROM payment_confirmations WHERE user_id = auth.uid()`
-- to return empty rows. The SECURITY DEFINER check_class_booking_eligibility
-- function bypasses RLS and works, but the Flutter client-side queries do not.
-- Fix: Add a SELECT policy so users can always see their own payment records.

ALTER TABLE public.payment_confirmations ENABLE ROW LEVEL SECURITY;

-- Users can read their own payment confirmations
DROP POLICY IF EXISTS "users_read_own_payment_confirmations" ON public.payment_confirmations;
CREATE POLICY "users_read_own_payment_confirmations"
    ON public.payment_confirmations
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Admins can read and manage all payment confirmations
DROP POLICY IF EXISTS "admins_manage_all_payment_confirmations" ON public.payment_confirmations;
CREATE POLICY "admins_manage_all_payment_confirmations"
    ON public.payment_confirmations
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
        )
    );
