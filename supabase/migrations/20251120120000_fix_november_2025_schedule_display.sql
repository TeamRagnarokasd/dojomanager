-- Migration: Fix November 2025 Schedule Display Issue
-- Fix the issue where Thursday November 20, 2025 shows no classes
-- Root cause: Schedule instances not generated for 2025/2026 season + season not active

-- Step 1: Activate the 2025/2026 seasonal schedule
UPDATE public.seasonal_schedules
SET 
  status = 'active',
  updated_at = NOW()
WHERE title = 'Palinsesto 2025/2026'
  AND start_date = '2025-09-01'
  AND end_date = '2026-06-29';

-- Step 2: Generate schedule instances for the entire 2025/2026 season
-- This will populate all dates including November 20, 2025 (Thursday)
DO $$
DECLARE
  season_id UUID;
  instances_count INTEGER;
BEGIN
  -- Get the season ID
  SELECT id INTO season_id
  FROM public.seasonal_schedules
  WHERE title = 'Palinsesto 2025/2026'
    AND start_date = '2025-09-01';

  IF season_id IS NOT NULL THEN
    -- Generate instances using the existing function
    SELECT public.generate_seasonal_schedule_instances(season_id) INTO instances_count;
    
    RAISE NOTICE 'Generated % schedule instances for 2025/2026 season', instances_count;
  ELSE
    RAISE NOTICE 'Season 2025/2026 not found';
  END IF;
END $$;

-- Step 3: Verify Thursday classes exist for November 2025
DO $$
DECLARE
  thursday_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO thursday_count
  FROM public.schedule_instances si
  JOIN public.seasonal_schedules ss ON si.seasonal_schedule_id = ss.id
  WHERE ss.title = 'Palinsesto 2025/2026'
    AND EXTRACT(DOW FROM si.class_date) = 4  -- Thursday
    AND si.class_date >= '2025-11-01'
    AND si.class_date < '2025-12-01';
    
  RAISE NOTICE 'Found % Thursday classes in November 2025', thursday_count;
END $$;

-- Step 4: Create index for faster date-based queries if not exists
CREATE INDEX IF NOT EXISTS idx_schedule_instances_date_dow 
ON public.schedule_instances(class_date, EXTRACT(DOW FROM class_date));

-- Step 5: Update get_class_schedule_with_enrollments to include date range validation
CREATE OR REPLACE FUNCTION public.get_class_schedule_with_enrollments(target_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    result jsonb;
    active_season_count INTEGER;
BEGIN
    -- First check if date falls within any active seasonal schedule
    SELECT COUNT(*) INTO active_season_count
    FROM public.seasonal_schedules
    WHERE status = 'active'
      AND target_date >= start_date
      AND target_date <= end_date;

    -- If no active season covers this date, return empty array
    IF active_season_count = 0 THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Query schedule instances for the target date
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
            'is_cancelled', si.is_cancelled,
            'cancellation_reason', si.cancellation_reason,
            'is_holiday_affected', si.is_holiday_affected,
            'updated_at', TO_CHAR(si.updated_at, 'YYYY-MM-DD HH24:MI:SS'),
            'created_at', TO_CHAR(si.created_at, 'YYYY-MM-DD HH24:MI:SS'),
            'is_modified', (si.updated_at > si.created_at + INTERVAL '1 minute')
        ) ORDER BY si.start_time, si.discipline
    ) INTO result
    FROM public.schedule_instances si
    INNER JOIN public.seasonal_schedules ss ON si.seasonal_schedule_id = ss.id
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
      AND ss.status = 'active'
      AND si.discipline IN ('bjj', 'mma', 'sambo', 'grappling', 'fitness');
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

-- Step 6: Verify the fix
DO $$
DECLARE
  nov_20_classes jsonb;
BEGIN
  SELECT public.get_class_schedule_with_enrollments('2025-11-20') INTO nov_20_classes;
  
  RAISE NOTICE 'November 20, 2025 schedule: %', nov_20_classes;
END $$;