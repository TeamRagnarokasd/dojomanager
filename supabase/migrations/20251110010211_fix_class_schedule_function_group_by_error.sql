-- Fix get_class_schedule_with_enrollments function GROUP BY error
-- The function was failing because of incorrect SQL syntax in the aggregate subquery

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
        ) order by si.start_time, si.discipline
    ) into result
    from public.schedule_instances si
    left join public.user_profiles up on si.instructor_id = up.id
    left join public.weekly_schedule_templates wst on si.template_id = wst.id
    left join (
        select 
            schedule_instance_id, 
            count(*)::integer as count
        from public.class_registrations
        where registration_status = 'registered'
        group by schedule_instance_id
    ) enrolled_count on si.id = enrolled_count.schedule_instance_id
    left join (
        select 
            schedule_instance_id, 
            true as is_registered
        from public.class_registrations
        where user_id = auth.uid() 
          and registration_status = 'registered'
    ) user_registered on si.id = user_registered.schedule_instance_id
    where si.class_date = target_date
      and si.is_cancelled = false
      and si.discipline in ('bjj', 'mma', 'sambo', 'grappling', 'fitness');
    
    return coalesce(result, '[]'::jsonb);
end;
$function$;

-- Also fix get_class_schedule_for_date function to ensure consistency
CREATE OR REPLACE FUNCTION public.get_class_schedule_for_date(target_date date)
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
            'enrolled', floor(random() * si.max_capacity * 0.7)::int,
            'is_booked', false,
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
        ) order by si.start_time, si.discipline
    ) into result
    from public.schedule_instances si
    left join public.user_profiles up on si.instructor_id = up.id
    left join public.weekly_schedule_templates wst on si.template_id = wst.id
    where si.class_date = target_date
      and si.is_cancelled = false
      and si.discipline in ('bjj', 'mma', 'sambo', 'grappling', 'fitness');
    
    return coalesce(result, '[]'::jsonb);
end;
$function$;

-- Ensure that schedule instances are generated for current and future dates
-- This function should be called when seasonal schedules are activated
CREATE OR REPLACE FUNCTION public.ensure_schedule_instances_exist()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    active_schedule_id uuid;
    instances_created integer := 0;
BEGIN
    -- Get the currently active seasonal schedule
    SELECT id INTO active_schedule_id 
    FROM public.seasonal_schedules 
    WHERE status = 'active'::season_status 
      AND start_date <= CURRENT_DATE 
      AND end_date >= CURRENT_DATE
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF active_schedule_id IS NOT NULL THEN
        -- Generate instances for the active schedule
        SELECT generate_seasonal_schedule_instances(active_schedule_id) INTO instances_created;
        
        -- Log the operation
        RAISE NOTICE 'Generated % schedule instances for active seasonal schedule %', instances_created, active_schedule_id;
    ELSE
        RAISE NOTICE 'No active seasonal schedule found for current date';
    END IF;
    
    RETURN instances_created;
END;
$function$;

-- Add helpful function to check schedule data for debugging
CREATE OR REPLACE FUNCTION public.debug_schedule_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'seasonal_schedules', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'title', title,
                    'status', status,
                    'start_date', start_date,
                    'end_date', end_date
                )
            )
            FROM public.seasonal_schedules
            WHERE status = 'active'
        ),
        'weekly_templates_count', (
            SELECT count(*)
            FROM public.weekly_schedule_templates wst
            JOIN public.seasonal_schedules ss ON wst.seasonal_schedule_id = ss.id
            WHERE ss.status = 'active'
        ),
        'schedule_instances_today', (
            SELECT count(*)
            FROM public.schedule_instances
            WHERE class_date = CURRENT_DATE
              AND is_cancelled = false
        ),
        'schedule_instances_this_week', (
            SELECT count(*)
            FROM public.schedule_instances
            WHERE class_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
              AND is_cancelled = false
        )
    ) INTO result;
    
    RETURN result;
END;
$function$;

-- Create a function to refresh schedule instances for active seasonal schedules
-- This ensures that the schedule is properly generated and visible to students
SELECT public.ensure_schedule_instances_exist();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.get_class_schedule_with_enrollments(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_class_schedule_for_date(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debug_schedule_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_schedule_instances_exist() TO authenticated;