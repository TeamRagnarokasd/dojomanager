-- Team Ragnarok ASD Receipt System Migration
-- Implements non-fiscal receipts with zero VAT and automatic subscription management

-- 1. Types and Enums
CREATE TYPE public.subscription_type AS ENUM ('monthly', 'annual');
CREATE TYPE public.payment_method AS ENUM ('sumup', 'satispay', 'cash', 'bank_transfer');
CREATE TYPE public.receipt_status AS ENUM ('draft', 'issued', 'cancelled');

-- 2. Gym Information Table
CREATE TABLE public.gym_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL DEFAULT 'TEAM RAGNAROK ASD',
    address TEXT NOT NULL DEFAULT 'via giulio bezzi 25, 48026 Russi - RA',
    tax_code TEXT NOT NULL DEFAULT '92100170395',
    phone TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. User Profiles for Authentication
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    tax_code TEXT,
    address TEXT,
    phone TEXT,
    role TEXT DEFAULT 'member',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Subscriptions Table
CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    type public.subscription_type NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    auto_renewal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Receipts Table
CREATE TABLE public.receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number SERIAL,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    gym_id UUID REFERENCES public.gym_info(id) ON DELETE CASCADE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    vat_rate DECIMAL(5,2) DEFAULT 0.00,
    payment_method public.payment_method NOT NULL,
    validity_start DATE,
    validity_end DATE,
    status public.receipt_status DEFAULT 'issued',
    notes TEXT DEFAULT 'Ricevuta Fiscale generata da APP Palestre (generata tramite TEAM RAGNAROK ASD APP)',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Payment Reminders Table
CREATE TABLE public.payment_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reminder_date DATE NOT NULL,
    message TEXT NOT NULL,
    is_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 7. Essential Indexes
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX idx_subscriptions_active ON public.subscriptions(is_active);
CREATE INDEX idx_receipts_user_id ON public.receipts(user_id);
CREATE INDEX idx_receipts_number ON public.receipts(receipt_number);
CREATE INDEX idx_receipts_issue_date ON public.receipts(issue_date);
CREATE INDEX idx_payment_reminders_user_id ON public.payment_reminders(user_id);
CREATE INDEX idx_payment_reminders_date ON public.payment_reminders(reminder_date);

-- 8. RLS Setup
ALTER TABLE public.gym_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_reminders ENABLE ROW LEVEL SECURITY;

-- 9. RLS Policies

-- Gym info - public read, admin write
CREATE POLICY "public_read_gym_info" ON public.gym_info
    FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_gym_info" ON public.gym_info
    FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM auth.users au
        WHERE au.id = auth.uid() 
        AND (au.raw_user_meta_data->>'role' = 'admin' OR au.raw_app_meta_data->>'role' = 'admin')
    ));

-- User profiles - users manage own profiles
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Subscriptions - users manage own subscriptions
CREATE POLICY "users_manage_own_subscriptions"
ON public.subscriptions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Receipts - users view own receipts, admins view all
CREATE POLICY "users_view_own_receipts"
ON public.receipts
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "admin_manage_all_receipts"
ON public.receipts
FOR ALL
TO authenticated
USING (EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (au.raw_user_meta_data->>'role' = 'admin' OR au.raw_app_meta_data->>'role' = 'admin')
));

-- Payment reminders - users view own reminders
CREATE POLICY "users_view_own_reminders"
ON public.payment_reminders
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- 10. Business Logic Functions

-- Function to calculate subscription dates according to Team Ragnarok rules
CREATE OR REPLACE FUNCTION public.calculate_subscription_dates(
    subscription_type public.subscription_type,
    payment_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(start_date DATE, end_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    current_year INTEGER := EXTRACT(year FROM payment_date);
    current_month INTEGER := EXTRACT(month FROM payment_date);
BEGIN
    IF subscription_type = 'monthly' THEN
        -- Monthly: Always from 10th of current month to 10th of next month
        RETURN QUERY SELECT 
            DATE(current_year, current_month, 10) as start_date,
            (DATE(current_year, current_month, 10) + INTERVAL '1 month')::DATE as end_date;
    ELSE
        -- Annual: Valid until August 28th based on payment timing
        IF EXTRACT(month FROM payment_date) >= 8 AND EXTRACT(day FROM payment_date) >= 29 THEN
            -- Paid from August 29th onwards - valid until next year's August 28th
            RETURN QUERY SELECT 
                payment_date as start_date,
                DATE(current_year + 1, 8, 28) as end_date;
        ELSE
            -- Paid before August 29th - valid until current year's August 28th
            RETURN QUERY SELECT 
                payment_date as start_date,
                DATE(current_year, 8, 28) as end_date;
        END IF;
    END IF;
END;
$$;

-- Function to generate receipt number
CREATE OR REPLACE FUNCTION public.generate_receipt_number()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    next_number INTEGER;
BEGIN
    SELECT COALESCE(MAX(receipt_number), 0) + 1 INTO next_number
    FROM public.receipts;
    RETURN next_number;
END;
$$;

-- Function to create receipt automatically
CREATE OR REPLACE FUNCTION public.create_receipt(
    p_user_id UUID,
    p_subscription_id UUID,
    p_amount DECIMAL(10,2),
    p_payment_method public.payment_method,
    p_subscription_type public.subscription_type
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    receipt_id UUID;
    gym_id UUID;
    dates RECORD;
    description_text TEXT;
    current_year INTEGER := EXTRACT(year FROM CURRENT_DATE);
BEGIN
    -- Get gym info
    SELECT id INTO gym_id FROM public.gym_info LIMIT 1;
    
    -- Calculate dates
    SELECT * INTO dates FROM public.calculate_subscription_dates(p_subscription_type);
    
    -- Generate description
    IF p_subscription_type = 'monthly' THEN
        description_text := 'Quota associativa mensile ' || TO_CHAR(CURRENT_DATE, 'MM/YYYY');
    ELSE
        description_text := 'Quota associativa stagione ' || current_year::TEXT || '/' || (current_year + 1)::TEXT;
    END IF;
    
    -- Create receipt
    INSERT INTO public.receipts (
        user_id,
        subscription_id,
        gym_id,
        issue_date,
        description,
        quantity,
        unit_price,
        total_amount,
        payment_method,
        validity_start,
        validity_end
    ) VALUES (
        p_user_id,
        p_subscription_id,
        gym_id,
        CURRENT_DATE,
        description_text,
        1,
        p_amount,
        p_amount,
        p_payment_method,
        dates.start_date,
        dates.end_date
    ) RETURNING id INTO receipt_id;
    
    RETURN receipt_id;
END;
$$;

-- Function to check if payment reminder is needed
CREATE OR REPLACE FUNCTION public.check_payment_reminder_needed(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    has_monthly_receipt BOOLEAN := false;
    current_month INTEGER := EXTRACT(month FROM CURRENT_DATE);
    current_year INTEGER := EXTRACT(year FROM CURRENT_DATE);
BEGIN
    -- Check if user has monthly receipt for current month
    SELECT EXISTS(
        SELECT 1 FROM public.receipts r
        JOIN public.subscriptions s ON r.subscription_id = s.id
        WHERE r.user_id = p_user_id
        AND s.type = 'monthly'
        AND EXTRACT(month FROM r.issue_date) = current_month
        AND EXTRACT(year FROM r.issue_date) = current_year
        AND r.status = 'issued'
    ) INTO has_monthly_receipt;
    
    RETURN NOT has_monthly_receipt;
END;
$$;

-- 11. Triggers for automatic profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'member')
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 12. Initialize Gym Data
INSERT INTO public.gym_info (name, address, tax_code) VALUES
    ('TEAM RAGNAROK ASD', 'via giulio bezzi 25, 48026 Russi - RA', '92100170395');

-- 13. Mock Data for Testing
DO $$
DECLARE
    admin_uuid UUID := gen_random_uuid();
    user_uuid UUID := gen_random_uuid();
    gym_uuid UUID;
    subscription_uuid UUID := gen_random_uuid();
BEGIN
    -- Create auth users
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@teamragnarok.it', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Admin Team Ragnarok", "role": "admin"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'pasquale.casaburo@example.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Pasquale Casaburo"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Update user profile with tax code and address
    UPDATE public.user_profiles 
    SET tax_code = 'CSBPQL96E21F839L', 
        address = 'Viale Alessandro Manzoni, 387, 48122, Ravenna'
    WHERE id = user_uuid;

    -- Get gym ID
    SELECT id INTO gym_uuid FROM public.gym_info LIMIT 1;

    -- Create subscription
    INSERT INTO public.subscriptions (id, user_id, type, amount, start_date, end_date, is_active)
    VALUES (subscription_uuid, user_uuid, 'monthly', 30.00, '2024-08-10', '2024-09-10', true);

    -- Create sample receipt
    INSERT INTO public.receipts (
        user_id, subscription_id, gym_id, issue_date, receipt_number,
        description, quantity, unit_price, total_amount, 
        payment_method, validity_start, validity_end
    ) VALUES (
        user_uuid, subscription_uuid, gym_uuid, '2024-08-30', 4,
        'Quota associativa mensile 08/2024', 1, 30.00, 30.00,
        'satispay', '2024-08-10', '2024-09-10'
    );

END $$;