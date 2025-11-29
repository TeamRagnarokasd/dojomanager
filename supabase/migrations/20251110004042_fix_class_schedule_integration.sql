-- Location: supabase/migrations/20251110004042_fix_class_schedule_integration.sql
-- Schema Analysis: Schedule system exists, need to add class registration functionality
-- Integration Type: Extension - Adding missing class_registrations table and functions
-- Dependencies: schedule_instances, user_profiles, user_subscriptions tables

-- Add registration status enum
CREATE TYPE public.registration_status AS ENUM ('registered', 'cancelled', 'waitlisted');

-- Create class_registrations table (missing from schema)
CREATE TABLE public.class_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE NOT NULL,
    schedule_instance_id UUID REFERENCES public.schedule_instances(id) ON DELETE CASCADE NOT NULL,
    user_subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    registration_status public.registration_status DEFAULT 'registered'::public.registration_status NOT NULL,
    registered_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add essential indexes
CREATE INDEX idx_class_registrations_user_id ON public.class_registrations(user_id);
CREATE INDEX idx_class_registrations_schedule_instance ON public.class_registrations(schedule_instance_id);
CREATE INDEX idx_class_registrations_status ON public.class_registrations(registration_status);
CREATE INDEX idx_class_registrations_date ON public.class_registrations(registered_at);

-- Unique constraint to prevent duplicate registrations
CREATE UNIQUE INDEX idx_unique_active_registration 
ON public.class_registrations(user_id, schedule_instance_id) 
WHERE registration_status = 'registered';

-- Enable RLS
ALTER TABLE public.class_registrations ENABLE ROW LEVEL SECURITY;

-- RLS Policy using Pattern 2 (Simple User Ownership)
CREATE POLICY "users_manage_own_class_registrations"
ON public.class_registrations
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Create updated function to get class schedule with enrollments
CREATE OR REPLACE FUNCTION public.get_class_schedule_with_enrollments(target_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
    result jsonb;
begin
    select jsonb_agg(
        jsonb_build_object(
            'id', si.id,
            'discipline', si.discipline,
            'disciplineDisplayName', 
                case si.discipline
                    when 'bjj' then 'BJJ'
                    when 'mma' then 'MMA'
                    when 'sambo' then 'Sambo'
                    when 'grappling' then 'Grappling'
                    when 'fitness' then 'Prep. Atletica'
                    else upper(si.discipline::text)
                end,
            'instructor_name', coalesce(up.full_name, 'Istruttore Disponibile'),
            'instructor_bio', 'Istruttore esperto con anni di esperienza',
            'time_range', si.start_time::text || ' - ' || si.end_time::text,
            'date_formatted', to_char(si.class_date, 'DD/MM/YYYY'),
            'capacity', si.max_capacity,
            'enrolled', coalesce(enrolled_count.count, 0),
            'is_booked', coalesce(user_registered.is_registered, false),
            'waitlist_position', null,
            'description', coalesce(wst.notes, 'Allenamento di ' || 
                case si.discipline
                    when 'bjj' then 'Brazilian Jiu-Jitsu'
                    when 'mma' then 'Mixed Martial Arts'
                    when 'sambo' then 'Sambo'
                    when 'grappling' then 'Grappling'
                    when 'fitness' then 'Preparazione Atletica'
                    else si.discipline::text
                end),
            'location', si.location,
            'start_time', si.start_time::text,
            'end_time', si.end_time::text,
            'class_date', si.class_date::text
        )
    ) into result
    from public.schedule_instances si
    left join public.user_profiles up on si.instructor_id = up.id
    left join public.weekly_schedule_templates wst on si.template_id = wst.id
    left join (
        select schedule_instance_id, count(*) as count
        from public.class_registrations
        where registration_status = 'registered'
        group by schedule_instance_id
    ) enrolled_count on si.id = enrolled_count.schedule_instance_id
    left join (
        select schedule_instance_id, true as is_registered
        from public.class_registrations
        where user_id = auth.uid() and registration_status = 'registered'
    ) user_registered on si.id = user_registered.schedule_instance_id
    where si.class_date = target_date
      and si.is_cancelled = false
      and si.discipline in ('bjj', 'mma', 'sambo', 'grappling', 'fitness')
    order by si.start_time, si.discipline;
    
    return coalesce(result, '[]'::jsonb);
end;
$function$;

-- Function to register for a class
CREATE OR REPLACE FUNCTION public.register_for_class(instance_id UUID, subscription_id UUID DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
    current_enrollment integer;
    max_capacity integer;
    user_uuid UUID;
    result jsonb;
begin
    -- Get current user
    user_uuid := auth.uid();
    if user_uuid is null then
        return jsonb_build_object('success', false, 'error', 'User not authenticated');
    end if;

    -- Check if user is already registered
    if exists(
        select 1 from public.class_registrations
        where user_id = user_uuid 
        and schedule_instance_id = instance_id 
        and registration_status = 'registered'
    ) then
        return jsonb_build_object('success', false, 'error', 'Already registered for this class');
    end if;

    -- Get class capacity and current enrollment
    select si.max_capacity, coalesce(enrollment_count.count, 0)
    into max_capacity, current_enrollment
    from public.schedule_instances si
    left join (
        select schedule_instance_id, count(*) as count
        from public.class_registrations
        where registration_status = 'registered'
        group by schedule_instance_id
    ) enrollment_count on si.id = enrollment_count.schedule_instance_id
    where si.id = instance_id;

    if max_capacity is null then
        return jsonb_build_object('success', false, 'error', 'Class not found');
    end if;

    -- Check capacity
    if current_enrollment >= max_capacity then
        return jsonb_build_object('success', false, 'error', 'Class is full');
    end if;

    -- Register user
    insert into public.class_registrations (
        user_id, 
        schedule_instance_id, 
        user_subscription_id, 
        registration_status
    ) values (
        user_uuid, 
        instance_id, 
        subscription_id, 
        'registered'
    );

    -- Use subscription entry if provided
    if subscription_id is not null then
        perform public.use_subscription_entry(user_uuid, subscription_id);
    end if;

    return jsonb_build_object('success', true, 'message', 'Successfully registered for class');
exception
    when others then
        return jsonb_build_object('success', false, 'error', SQLERRM);
end;
$function$;

-- Function to cancel class registration
CREATE OR REPLACE FUNCTION public.cancel_class_registration(instance_id UUID, cancellation_reason TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
    user_uuid UUID;
    registration_record record;
    result jsonb;
begin
    -- Get current user
    user_uuid := auth.uid();
    if user_uuid is null then
        return jsonb_build_object('success', false, 'error', 'User not authenticated');
    end if;

    -- Find and update registration
    select * into registration_record
    from public.class_registrations
    where user_id = user_uuid 
    and schedule_instance_id = instance_id 
    and registration_status = 'registered'
    limit 1;

    if registration_record is null then
        return jsonb_build_object('success', false, 'error', 'No active registration found');
    end if;

    -- Update registration status
    update public.class_registrations
    set registration_status = 'cancelled',
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = coalesce(cancel_class_registration.cancellation_reason, 'Cancelled by user'),
        updated_at = CURRENT_TIMESTAMP
    where id = registration_record.id;

    return jsonb_build_object('success', true, 'message', 'Registration cancelled successfully');
exception
    when others then
        return jsonb_build_object('success', false, 'error', SQLERRM);
end;
$function$;

-- Function to check if user can register for class
CREATE OR REPLACE FUNCTION public.can_register_for_class(instance_id UUID, requesting_user_id UUID)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $function$
    select not exists(
        select 1 from public.class_registrations cr
        where cr.user_id = requesting_user_id
        and cr.schedule_instance_id = instance_id
        and cr.registration_status = 'registered'
    ) and exists(
        select 1 from public.schedule_instances si
        where si.id = instance_id
        and si.is_cancelled = false
        and si.class_date >= current_date
    );
$function$;

-- Function to get current enrollment count
CREATE OR REPLACE FUNCTION public.get_current_enrollment_count(instance_id UUID)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
AS $function$
    select coalesce(count(*), 0)::integer
    from public.class_registrations
    where schedule_instance_id = instance_id
    and registration_status = 'registered';
$function$;

-- Add updated trigger for updated_at
CREATE OR REPLACE FUNCTION public.update_class_registrations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trigger_update_class_registrations_updated_at
    BEFORE UPDATE ON public.class_registrations
    FOR EACH ROW
    EXECUTE FUNCTION public.update_class_registrations_updated_at();

-- Sample registration data (only if schedule instances exist)
DO $$
DECLARE
    sample_instance_id UUID;
    sample_user_id UUID;
BEGIN
    -- Get a sample schedule instance
    SELECT id INTO sample_instance_id FROM public.schedule_instances LIMIT 1;
    -- Get a sample user
    SELECT id INTO sample_user_id FROM public.user_profiles LIMIT 1;
    
    -- Only add sample data if both exist
    IF sample_instance_id IS NOT NULL AND sample_user_id IS NOT NULL THEN
        INSERT INTO public.class_registrations (user_id, schedule_instance_id, registration_status)
        VALUES (sample_user_id, sample_instance_id, 'registered'::public.registration_status)
        ON CONFLICT DO NOTHING;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Sample data creation skipped: %', SQLERRM;
END $$;