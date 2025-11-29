-- Migration: Enhance class schedule display to show admin modifications
-- This migration updates the get_class_schedule_with_enrollments function to include
-- modification tracking fields (is_cancelled, cancellation_reason, is_holiday_affected, updated_at)

-- Drop existing function
DROP FUNCTION IF EXISTS public.get_class_schedule_with_enrollments(date);

-- Recreate function with modification tracking
CREATE OR REPLACE FUNCTION public.get_class_schedule_with_enrollments(target_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', si.id,
            'discipline', si.discipline,
            'disciplineDisplayName', 
                CASE si.discipline
                    WHEN 'bjj' THEN 'BJJ'
                    WHEN 'mma' THEN 'MMA'
                    WHEN 'sambo' THEN 'Sambo'
                    WHEN 'grappling' THEN 'Grappling'
                    WHEN 'fitness' THEN 'Prep. Atletica'
                    ELSE UPPER(si.discipline::text)
                END,
            'instructor_name', COALESCE(up.full_name, 'Istruttore Disponibile'),
            'instructor_email', COALESCE(up.email, ''),
            'instructor_bio', 'Istruttore esperto con anni di esperienza',
            'time_range', si.start_time::text || ' - ' || si.end_time::text,
            'date_formatted', TO_CHAR(si.class_date, 'DD/MM/YYYY'),
            'capacity', si.max_capacity,
            'enrolled', COALESCE(enrolled_count.count, 0),
            'is_booked', COALESCE(user_registered.is_registered, false),
            'waitlist_position', NULL,
            'description', COALESCE(wst.notes, 'Allenamento di ' || 
                CASE si.discipline
                    WHEN 'bjj' THEN 'Brazilian Jiu-Jitsu'
                    WHEN 'mma' THEN 'Mixed Martial Arts'
                    WHEN 'sambo' THEN 'Sambo'
                    WHEN 'grappling' THEN 'Grappling'
                    WHEN 'fitness' THEN 'Preparazione Atletica'
                    ELSE si.discipline::text
                END),
            'location', si.location,
            'start_time', si.start_time::text,
            'end_time', si.end_time::text,
            'class_date', si.class_date::text,
            -- Admin modification tracking fields
            'is_cancelled', si.is_cancelled,
            'cancellation_reason', si.cancellation_reason,
            'is_holiday_affected', si.is_holiday_affected,
            'updated_at', TO_CHAR(si.updated_at, 'YYYY-MM-DD HH24:MI:SS'),
            'created_at', TO_CHAR(si.created_at, 'YYYY-MM-DD HH24:MI:SS'),
            'is_modified', (si.updated_at > si.created_at + INTERVAL '1 minute')
        ) ORDER BY si.start_time, si.discipline
    ) INTO result
    FROM public.schedule_instances si
    LEFT JOIN public.user_profiles up ON si.instructor_id = up.id
    LEFT JOIN public.weekly_schedule_templates wst ON si.template_id = wst.id
    LEFT JOIN (
        SELECT 
            schedule_instance_id, 
            COUNT(*)::integer AS count
        FROM public.class_registrations
        WHERE registration_status = 'registered'
        GROUP BY schedule_instance_id
    ) enrolled_count ON si.id = enrolled_count.schedule_instance_id
    LEFT JOIN (
        SELECT 
            schedule_instance_id, 
            true AS is_registered
        FROM public.class_registrations
        WHERE user_id = auth.uid() 
          AND registration_status = 'registered'
    ) user_registered ON si.id = user_registered.schedule_instance_id
    WHERE si.class_date = target_date
      AND si.discipline IN ('bjj', 'mma', 'sambo', 'grappling', 'fitness');
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_class_schedule_with_enrollments(date) TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION public.get_class_schedule_with_enrollments(date) IS 
'Returns class schedule for a specific date including enrollment counts, user booking status, and admin modifications (cancellations, updates).
Now includes is_cancelled, cancellation_reason, is_holiday_affected, updated_at, and is_modified fields to track admin changes.';