-- Location: supabase/migrations/20250902131000_entry_based_subscription_plans.sql
-- Schema Analysis: Existing schema includes user_profiles, payment_method_type, user_role enums
-- Integration Type: addition - New subscription management system
-- Dependencies: user_profiles table

-- 1. Create subscription plan types enum
CREATE TYPE public.subscription_plan_type AS ENUM ('monthly', 'single_entry', 'multi_entry', 'annual');

-- 2. Create subscription plans table
CREATE TABLE public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    plan_type public.subscription_plan_type NOT NULL,
    entry_count INTEGER, -- For entry-based plans
    sumup_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create user subscriptions table
CREATE TABLE public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    subscription_plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
    entries_remaining INTEGER DEFAULT 0, -- For entry-based plans
    entries_total INTEGER DEFAULT 0, -- Original number of entries
    is_active BOOLEAN DEFAULT true,
    purchased_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ, -- NULL for entry-based plans
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create subscription entries usage table
CREATE TABLE public.subscription_entry_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    class_type TEXT, -- BJJ, MMA, Grappling, etc.
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Essential Indexes
CREATE INDEX idx_subscription_plans_type ON public.subscription_plans(plan_type);
CREATE INDEX idx_subscription_plans_active ON public.subscription_plans(is_active);
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_plan_id ON public.user_subscriptions(subscription_plan_id);
CREATE INDEX idx_user_subscriptions_active ON public.user_subscriptions(is_active);
CREATE INDEX idx_subscription_entry_usage_user_subscription_id ON public.subscription_entry_usage(user_subscription_id);
CREATE INDEX idx_subscription_entry_usage_user_id ON public.subscription_entry_usage(user_id);

-- 6. Enable RLS
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_entry_usage ENABLE ROW LEVEL SECURITY;

-- 7. Helper functions for admin role checking
CREATE OR REPLACE FUNCTION public.is_admin_level_subscription()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
)
$$;

-- 8. RLS Policies

-- Subscription plans - public read, admin manage
CREATE POLICY "public_can_read_subscription_plans"
ON public.subscription_plans
FOR SELECT
TO public
USING (is_active = true);

CREATE POLICY "admins_manage_subscription_plans"
ON public.subscription_plans
FOR ALL
TO authenticated
USING (public.is_admin_level_subscription())
WITH CHECK (public.is_admin_level_subscription());

-- User subscriptions - users manage own, admins manage all
CREATE POLICY "users_manage_own_subscriptions"
ON public.user_subscriptions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "admins_manage_all_subscriptions"
ON public.user_subscriptions
FOR ALL
TO authenticated
USING (public.is_admin_level_subscription())
WITH CHECK (public.is_admin_level_subscription());

-- Entry usage - users manage own, admins manage all
CREATE POLICY "users_manage_own_entry_usage"
ON public.subscription_entry_usage
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "admins_manage_all_entry_usage"
ON public.subscription_entry_usage
FOR ALL
TO authenticated
USING (public.is_admin_level_subscription())
WITH CHECK (public.is_admin_level_subscription());

-- 9. Functions for subscription management
CREATE OR REPLACE FUNCTION public.use_subscription_entry(
    user_subscription_uuid UUID,
    class_type_param TEXT DEFAULT NULL,
    notes_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    current_entries INTEGER;
    user_uuid UUID;
BEGIN
    -- Get current entries and user_id
    SELECT entries_remaining, user_id INTO current_entries, user_uuid
    FROM public.user_subscriptions
    WHERE id = user_subscription_uuid
    AND user_id = auth.uid()
    AND is_active = true;

    -- Check if subscription exists and has entries
    IF current_entries IS NULL OR current_entries <= 0 THEN
        RETURN false;
    END IF;

    -- Use one entry
    UPDATE public.user_subscriptions
    SET entries_remaining = entries_remaining - 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_subscription_uuid;

    -- Log the usage
    INSERT INTO public.subscription_entry_usage (
        user_subscription_id,
        user_id,
        class_type,
        notes
    ) VALUES (
        user_subscription_uuid,
        user_uuid,
        class_type_param,
        notes_param
    );

    -- Deactivate subscription if no entries left
    IF current_entries - 1 <= 0 THEN
        UPDATE public.user_subscriptions
        SET is_active = false,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = user_subscription_uuid;
    END IF;

    RETURN true;
END;
$func$;

CREATE OR REPLACE FUNCTION public.get_user_active_subscriptions(user_uuid UUID DEFAULT NULL)
RETURNS TABLE(
    subscription_id UUID,
    plan_name TEXT,
    plan_type TEXT,
    entries_remaining INTEGER,
    entries_total INTEGER,
    expires_at TIMESTAMPTZ,
    purchased_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
BEGIN
    RETURN QUERY
    SELECT
        us.id,
        sp.name,
        sp.plan_type::TEXT,
        us.entries_remaining,
        us.entries_total,
        us.expires_at,
        us.purchased_at
    FROM public.user_subscriptions us
    JOIN public.subscription_plans sp ON us.subscription_plan_id = sp.id
    WHERE us.user_id = COALESCE(user_uuid, auth.uid())
    AND us.is_active = true
    ORDER BY us.purchased_at DESC;
END;
$func$;

-- 10. Insert default subscription plans
DO $$
BEGIN
    -- Insert the two new entry-based plans
    INSERT INTO public.subscription_plans (
        name, description, price, plan_type, entry_count, sumup_url, is_active
    ) VALUES
    (
        'Ingresso singolo',
        'Un singolo ingresso per allenamento. Non ha data di scadenza.',
        10.00,
        'single_entry'::public.subscription_plan_type,
        1,
        'https://pay.sumup.com/b2c/QQE90R7O',
        true
    ),
    (
        'Pacchetto 10 ingressi',
        'Pacchetto di 10 ingressi per allenamenti. Non ha data di scadenza, scade al finire degli ingressi.',
        80.00,
        'multi_entry'::public.subscription_plan_type,
        10,
        'https://pay.sumup.com/b2c/QR3160IO',
        true
    );

    -- Insert existing monthly plans for completeness
    INSERT INTO public.subscription_plans (
        name, description, price, plan_type, sumup_url, is_active
    ) VALUES
    (
        'Corso Singolo',
        'Corso mensile singolo con scelta tra MMA o BJJ. Include sempre Grappling e Sambo.',
        60.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QHVYXRZR',
        true
    ),
    (
        'Corso Singolo (in convenzione)',
        'Corso mensile singolo con scelta tra MMA o BJJ. Include sempre Grappling e Sambo. Tariffa agevolata.',
        50.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QPQ08OQA',
        true
    ),
    (
        'Doppio Corso',
        'Corso mensile completo con accesso a BJJ, MMA, Grappling e Sambo.',
        95.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QZLJXISP',
        true
    ),
    (
        'Doppio corso (in convenzione)',
        'Corso mensile completo con accesso a tutte le discipline. Tariffa agevolata.',
        75.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QR42R0RH',
        true
    ),
    (
        'Preparazione Atletica',
        'Corso mensile di preparazione atletica specializzata.',
        30.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QU0R8I0A',
        true
    ),
    (
        'Corso Singolo + Preparazione',
        'Corso mensile singolo più preparazione atletica.',
        90.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QQ9F1KED',
        true
    ),
    (
        'Doppio Corso + Preparazione',
        'Corso mensile completo con tutte le discipline più preparazione atletica.',
        120.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QR5I6ZO7',
        true
    ),
    (
        'Doppio corso + Prep. Atl. (in conv.)',
        'Corso mensile completo con preparazione atletica. Tariffa agevolata.',
        105.00,
        'monthly'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/QT4LT4XQ',
        true
    ),
    (
        'Iscrizione Annuale',
        'Quota associativa annuale obbligatoria.',
        30.00,
        'annual'::public.subscription_plan_type,
        'https://pay.sumup.com/b2c/Q0ND0EKY',
        true
    );

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Some subscription plans already exist, skipping duplicates.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error inserting subscription plans: %', SQLERRM;
END $$;

-- 11. Create function to cleanup test data if needed
CREATE OR REPLACE FUNCTION public.cleanup_subscription_test_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
BEGIN
    DELETE FROM public.subscription_entry_usage WHERE user_id IN (
        SELECT id FROM public.user_profiles WHERE email LIKE '%@test.com'
    );
    DELETE FROM public.user_subscriptions WHERE user_id IN (
        SELECT id FROM public.user_profiles WHERE email LIKE '%@test.com'
    );
    
    RAISE NOTICE 'Test subscription data cleaned up successfully.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup failed: %', SQLERRM;
END;
$func$;