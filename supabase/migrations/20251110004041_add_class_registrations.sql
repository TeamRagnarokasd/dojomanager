-- Location: supabase/migrations/20251110004041_add_class_registrations.sql
-- Schema Analysis: Existing schema with schedule_instances, user_profiles, seasonal_schedules, user_subscriptions
-- Integration Type: Extension - Adding class registration functionality
-- Dependencies: schedule_instances, user_profiles, user_subscriptions

-- 1. Create enum for registration status
CREATE TYPE public.registration_status AS ENUM ('pending', 'confirmed', 'cancelled', 'completed', 'no_show');

-- 2. Create class registrations table
CREATE TABLE public.class_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_instance_id UUID NOT NULL REFERENCES public.schedule_instances(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    user_subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    registration_status public.registration_status DEFAULT 'confirmed'::public.registration_status,
    registered_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate registrations for same class
    UNIQUE(schedule_instance_id, user_id)
);

-- 3. Create indexes for performance
CREATE INDEX idx_class_registrations_schedule_instance ON public.class_registrations(schedule_instance_id);
CREATE INDEX idx_class_registrations_user_id ON public.class_registrations(user_id);
CREATE INDEX idx_class_registrations_status ON public.class_registrations(registration_status);
CREATE INDEX idx_class_registrations_registered_at ON public.class_registrations(registered_at);

-- 4. Enable RLS
ALTER TABLE public.class_registrations ENABLE ROW LEVEL SECURITY;

-- 5. Create helper functions BEFORE RLS policies
CREATE OR REPLACE FUNCTION public.is_admin_level()
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

CREATE OR REPLACE FUNCTION public.get_current_enrollment_count(instance_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT COUNT(*)::INTEGER
FROM public.class_registrations cr
WHERE cr.schedule_instance_id = instance_id
AND cr.registration_status IN ('confirmed', 'pending')
$$;

CREATE OR REPLACE FUNCTION public.can_register_for_class(instance_id UUID, requesting_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.schedule_instances si
    WHERE si.id = instance_id
    AND si.is_cancelled = false
    AND si.class_date >= CURRENT_DATE
    AND (
        SELECT COUNT(*) FROM public.class_registrations cr
        WHERE cr.schedule_instance_id = instance_id
        AND cr.registration_status IN ('confirmed', 'pending')
    ) < si.max_capacity
)
$$;

-- 6. Create RLS policies using Pattern 2 (Simple User Ownership)
CREATE POLICY "users_manage_own_registrations"
ON public.class_registrations
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Admin policy for full access
CREATE POLICY "admin_manage_all_registrations"
ON public.class_registrations
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- 7. Create functions for class registration management
CREATE OR REPLACE FUNCTION public.register_for_class(
    instance_id UUID,
    subscription_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID := auth.uid();
    current_count INTEGER;
    max_capacity INTEGER;
    result JSONB;
BEGIN
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Check if class exists and is not cancelled
    SELECT si.max_capacity INTO max_capacity
    FROM public.schedule_instances si
    WHERE si.id = instance_id
    AND si.is_cancelled = false
    AND si.class_date >= CURRENT_DATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Class not found or not available');
    END IF;

    -- Check current enrollment
    SELECT public.get_current_enrollment_count(instance_id) INTO current_count;

    IF current_count >= max_capacity THEN
        RETURN jsonb_build_object('success', false, 'error', 'Class is full');
    END IF;

    -- Check if already registered
    IF EXISTS (
        SELECT 1 FROM public.class_registrations cr
        WHERE cr.schedule_instance_id = instance_id
        AND cr.user_id = user_uuid
        AND cr.registration_status IN ('confirmed', 'pending')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Already registered for this class');
    END IF;

    -- Create registration
    INSERT INTO public.class_registrations (
        schedule_instance_id,
        user_id,
        user_subscription_id,
        registration_status
    ) VALUES (
        instance_id,
        user_uuid,
        subscription_id,
        'confirmed'::public.registration_status
    );

    -- Use subscription entry if provided
    IF subscription_id IS NOT NULL THEN
        INSERT INTO public.subscription_entry_usage (
            user_id,
            user_subscription_id,
            class_type,
            notes,
            used_at
        )
        SELECT 
            user_uuid,
            subscription_id,
            si.discipline::TEXT,
            'Prenotazione classe: ' || si.discipline::TEXT || ' - ' || si.location,
            CURRENT_TIMESTAMP
        FROM public.schedule_instances si
        WHERE si.id = instance_id;

        -- Update subscription entries remaining
        UPDATE public.user_subscriptions
        SET entries_remaining = GREATEST(0, entries_remaining - 1)
        WHERE id = subscription_id
        AND user_id = user_uuid;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully registered for class',
        'enrollment_count', current_count + 1
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Registration failed: ' || SQLERRM
        );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_class_registration(
    instance_id UUID,
    cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID := auth.uid();
    registration_record RECORD;
    usage_entry_id UUID;
    result JSONB;
BEGIN
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Find the registration
    SELECT cr.*, si.class_date, si.discipline
    INTO registration_record
    FROM public.class_registrations cr
    JOIN public.schedule_instances si ON cr.schedule_instance_id = si.id
    WHERE cr.schedule_instance_id = instance_id
    AND cr.user_id = user_uuid
    AND cr.registration_status IN ('confirmed', 'pending');

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Registration not found');
    END IF;

    -- Check if it is too late to cancel (same day)
    IF registration_record.class_date = CURRENT_DATE THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel on the day of the class');
    END IF;

    -- Update registration status
    UPDATE public.class_registrations
    SET 
        registration_status = 'cancelled'::public.registration_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = cancel_class_registration.cancellation_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = registration_record.id;

    -- Restore subscription entry if it was used
    IF registration_record.user_subscription_id IS NOT NULL THEN
        -- Find and remove the most recent matching usage entry
        SELECT id INTO usage_entry_id
        FROM public.subscription_entry_usage
        WHERE user_subscription_id = registration_record.user_subscription_id
        AND user_id = user_uuid
        AND used_at >= registration_record.registered_at
        AND class_type = registration_record.discipline::TEXT
        ORDER BY used_at DESC
        LIMIT 1;

        -- Delete the usage entry if found
        IF usage_entry_id IS NOT NULL THEN
            DELETE FROM public.subscription_entry_usage
            WHERE id = usage_entry_id;

            -- Restore the entry to subscription
            UPDATE public.user_subscriptions
            SET entries_remaining = entries_remaining + 1
            WHERE id = registration_record.user_subscription_id
            AND user_id = user_uuid;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration cancelled successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cancellation failed: ' || SQLERRM
        );
END;
$$;

-- 8. Create updated schedule function that includes enrollment data
CREATE OR REPLACE FUNCTION public.get_class_schedule_with_enrollments(target_date DATE)
RETURNS TABLE(
    id UUID,
    discipline TEXT,
    discipline_display_name TEXT,
    instructor_name TEXT,
    instructor_email TEXT,
    instructor_bio TEXT,
    time_range TEXT,
    date_formatted TEXT,
    capacity INTEGER,
    enrolled INTEGER,
    is_booked BOOLEAN,
    waitlist_position INTEGER,
    description TEXT,
    location TEXT,
    is_cancelled BOOLEAN,
    start_time TIME,
    end_time TIME,
    class_date DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID := auth.uid();
BEGIN
    RETURN QUERY
    SELECT
        si.id,
        si.discipline::TEXT,
        CASE si.discipline::TEXT
            WHEN 'bjj' THEN 'Brazilian Jiu-Jitsu'
            WHEN 'mma' THEN 'MMA'
            WHEN 'sambo' THEN 'Sambo'
            WHEN 'grappling' THEN 'Grappling'
            WHEN 'fitness' THEN 'Prep. Atletica'
            ELSE si.discipline::TEXT
        END AS discipline_display_name,
        COALESCE(up.full_name, 'Istruttore Disponibile') AS instructor_name,
        COALESCE(up.email, '') AS instructor_email,
        COALESCE(up.full_name || ' è un istruttore esperto con anni di esperienza nel settore delle arti marziali.', 'Istruttore esperto') AS instructor_bio,
        (si.start_time::TEXT || ' - ' || si.end_time::TEXT) AS time_range,
        TO_CHAR(si.class_date, 'DD/MM/YYYY') AS date_formatted,
        si.max_capacity,
        COALESCE(enrollment_counts.enrolled, 0)::INTEGER AS enrolled,
        COALESCE(user_registrations.is_registered, false) AS is_booked,
        NULL::INTEGER AS waitlist_position,
        CASE si.discipline::TEXT
            WHEN 'bjj' THEN 'Corso di Brazilian Jiu-Jitsu con focus su tecniche di base, posizioni e sottomissioni.'
            WHEN 'mma' THEN 'Allenamento di MMA con enfasi su tecniche miste e condizionamento atletico.'
            WHEN 'sambo' THEN 'Corso di Sambo con tecniche di proiezione e controllo a terra.'
            WHEN 'grappling' THEN 'Allenamento di Grappling con focus su tecniche di controllo e finalizzazioni.'
            WHEN 'fitness' THEN 'Allenamento fitness specifico per arti marziali e conditioning.'
            ELSE 'Allenamento di ' || si.discipline::TEXT
        END AS description,
        si.location,
        si.is_cancelled,
        si.start_time,
        si.end_time,
        si.class_date
    FROM public.schedule_instances si
    LEFT JOIN public.user_profiles up ON si.instructor_id = up.id
    LEFT JOIN (
        SELECT 
            cr.schedule_instance_id,
            COUNT(*) AS enrolled
        FROM public.class_registrations cr
        WHERE cr.registration_status IN ('confirmed', 'pending')
        GROUP BY cr.schedule_instance_id
    ) enrollment_counts ON si.id = enrollment_counts.schedule_instance_id
    LEFT JOIN (
        SELECT 
            cr.schedule_instance_id,
            true AS is_registered
        FROM public.class_registrations cr
        WHERE cr.user_id = current_user_id
        AND cr.registration_status IN ('confirmed', 'pending')
    ) user_registrations ON si.id = user_registrations.schedule_instance_id
    WHERE si.class_date = target_date
    AND si.is_cancelled = false
    ORDER BY si.start_time;
END;
$$;

-- 9. Mock data for testing
DO $$
DECLARE
    existing_user_id UUID;
    existing_instance_id UUID;
    existing_subscription_id UUID;
BEGIN
    -- Get existing user and schedule instance
    SELECT id INTO existing_user_id FROM public.user_profiles LIMIT 1;
    SELECT id INTO existing_instance_id FROM public.schedule_instances WHERE class_date >= CURRENT_DATE LIMIT 1;
    SELECT id INTO existing_subscription_id FROM public.user_subscriptions WHERE user_id = existing_user_id AND is_active = true LIMIT 1;

    -- Only create mock registrations if we have existing data
    IF existing_user_id IS NOT NULL AND existing_instance_id IS NOT NULL THEN
        INSERT INTO public.class_registrations (
            schedule_instance_id,
            user_id,
            user_subscription_id,
            registration_status
        ) VALUES (
            existing_instance_id,
            existing_user_id,
            existing_subscription_id,
            'confirmed'::public.registration_status
        )
        ON CONFLICT (schedule_instance_id, user_id) DO NOTHING;
    END IF;

    -- Add more mock registrations with different users if they exist
    FOR existing_user_id IN 
        SELECT id FROM public.user_profiles LIMIT 3
    LOOP
        FOR existing_instance_id IN 
            SELECT id FROM public.schedule_instances 
            WHERE class_date >= CURRENT_DATE 
            AND class_date <= CURRENT_DATE + INTERVAL '7 days'
            LIMIT 2
        LOOP
            INSERT INTO public.class_registrations (
                schedule_instance_id,
                user_id,
                registration_status
            ) VALUES (
                existing_instance_id,
                existing_user_id,
                'confirmed'::public.registration_status
            )
            ON CONFLICT (schedule_instance_id, user_id) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;