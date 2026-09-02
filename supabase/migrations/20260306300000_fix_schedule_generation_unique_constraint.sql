-- Migration: Fix Schedule Generation - Unique Constraint Scoped per Season
-- Timestamp: 20260306300000
--
-- Root cause: The unique_schedule_slot constraint was (class_date, start_time, location)
-- which spans ALL schedules. When generating instances for a new schedule, inserts
-- silently conflict with existing instances from OTHER schedules at the same
-- date/time/location, causing ON CONFLICT DO NOTHING to skip every row.
-- Fix: Include seasonal_schedule_id in the constraint so each schedule's instances
-- are independent.

-- 1. Drop the old cross-schedule unique constraint
ALTER TABLE public.schedule_instances
DROP CONSTRAINT IF EXISTS unique_schedule_slot;

-- 2. Create a new unique constraint scoped per seasonal schedule
ALTER TABLE public.schedule_instances
ADD CONSTRAINT unique_schedule_instance_slot
UNIQUE (seasonal_schedule_id, class_date, start_time, location);

-- 3. Recreate the RPC function with:
--    a) Updated ON CONFLICT clause matching the new constraint
--    b) Accurate insert counting using GET DIAGNOSTICS
DROP FUNCTION IF EXISTS public.generate_seasonal_schedule_instances(uuid);

CREATE OR REPLACE FUNCTION public.generate_seasonal_schedule_instances(schedule_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    schedule_record public.seasonal_schedules%ROWTYPE;
    template_record public.weekly_schedule_templates%ROWTYPE;
    iter_date DATE;
    current_day_of_week INTEGER;
    instances_created INTEGER := 0;
    rows_inserted INTEGER;
    holiday_dates DATE[];
    day_name public.day_of_week;
BEGIN
    SELECT * INTO schedule_record
    FROM public.seasonal_schedules
    WHERE id = schedule_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Schedule % not found', schedule_id;
        RETURN 0;
    END IF;

    SELECT ARRAY_AGG(holiday_date) INTO holiday_dates
    FROM public.seasonal_holidays
    WHERE seasonal_schedule_id = schedule_id;

    DELETE FROM public.schedule_instances
    WHERE seasonal_schedule_id = schedule_id;

    iter_date := schedule_record.start_date;

    WHILE iter_date <= schedule_record.end_date LOOP
        current_day_of_week := EXTRACT(ISODOW FROM iter_date);

        day_name := CASE current_day_of_week
            WHEN 1 THEN 'monday'
            WHEN 2 THEN 'tuesday'
            WHEN 3 THEN 'wednesday'
            WHEN 4 THEN 'thursday'
            WHEN 5 THEN 'friday'
            WHEN 6 THEN 'saturday'
            WHEN 7 THEN 'sunday'
        END::public.day_of_week;

        FOR template_record IN
            SELECT * FROM public.weekly_schedule_templates
            WHERE seasonal_schedule_id = schedule_id
            AND day_of_week = day_name
        LOOP
            INSERT INTO public.schedule_instances (
                seasonal_schedule_id,
                template_id,
                class_date,
                start_time,
                end_time,
                discipline,
                instructor_id,
                location,
                max_capacity,
                is_cancelled,
                is_holiday_affected
            ) VALUES (
                schedule_id,
                template_record.id,
                iter_date,
                template_record.start_time,
                template_record.end_time,
                template_record.discipline,
                template_record.instructor_id,
                template_record.location,
                template_record.max_capacity,
                CASE
                    WHEN holiday_dates IS NOT NULL AND iter_date = ANY(holiday_dates)
                    THEN true
                    ELSE false
                END,
                CASE
                    WHEN holiday_dates IS NOT NULL AND iter_date = ANY(holiday_dates)
                    THEN true
                    ELSE false
                END
            )
            ON CONFLICT (seasonal_schedule_id, class_date, start_time, location) DO NOTHING;

            GET DIAGNOSTICS rows_inserted = ROW_COUNT;
            instances_created := instances_created + rows_inserted;
        END LOOP;

        iter_date := iter_date + INTERVAL '1 day';
    END LOOP;

    RETURN instances_created;
END;
$function$;

-- 4. Clean up orphaned duplicate schedules that have no templates
-- Keep the two most important: the draft with templates, and the active one
DELETE FROM public.seasonal_schedules
WHERE status IN ('draft', 'completed')
AND id NOT IN (
    -- Keep schedules that have weekly templates
    SELECT DISTINCT seasonal_schedule_id FROM public.weekly_schedule_templates
)
AND id NOT IN (
    -- Keep schedules that have generated instances
    SELECT DISTINCT seasonal_schedule_id FROM public.schedule_instances
);
