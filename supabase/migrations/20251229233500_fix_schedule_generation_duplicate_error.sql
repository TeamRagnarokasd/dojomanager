-- Migration: Fix Schedule Generation Duplicate Key Error
-- Timestamp: 20251229233500
-- Issue: Function fails with unique constraint violation when generating lessons
-- Solution: Use ON CONFLICT DO NOTHING to skip duplicates gracefully

-- Drop the existing function
DROP FUNCTION IF EXISTS public.generate_seasonal_schedule_instances(uuid);

-- Recreate the function with ON CONFLICT handling
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
    template_day_number INTEGER;
    instances_created INTEGER := 0;
    holiday_dates DATE[];
BEGIN
    -- Get seasonal schedule details
    SELECT * INTO schedule_record FROM public.seasonal_schedules 
    WHERE id = schedule_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Get all holiday dates for this season
    SELECT ARRAY_AGG(holiday_date) INTO holiday_dates
    FROM public.seasonal_holidays 
    WHERE seasonal_schedule_id = schedule_id;
    
    -- Clear existing instances ONLY for this seasonal schedule
    DELETE FROM public.schedule_instances 
    WHERE seasonal_schedule_id = schedule_id;
    
    -- Generate instances for each day in the season
    iter_date := schedule_record.start_date;
    
    WHILE iter_date <= schedule_record.end_date LOOP
        -- Get day of week (1=Monday, 7=Sunday)
        current_day_of_week := EXTRACT(DOW FROM iter_date);
        IF current_day_of_week = 0 THEN 
            current_day_of_week := 7; -- Sunday adjustment
        END IF;
        
        -- Convert to enum value
        template_day_number := current_day_of_week;
        
        -- Find templates for this day of week
        FOR template_record IN
            SELECT * FROM public.weekly_schedule_templates
            WHERE seasonal_schedule_id = schedule_id
            AND CASE 
                WHEN template_day_number = 1 THEN day_of_week = 'monday'
                WHEN template_day_number = 2 THEN day_of_week = 'tuesday'
                WHEN template_day_number = 3 THEN day_of_week = 'wednesday'
                WHEN template_day_number = 4 THEN day_of_week = 'thursday'
                WHEN template_day_number = 5 THEN day_of_week = 'friday'
                WHEN template_day_number = 6 THEN day_of_week = 'saturday'
                WHEN template_day_number = 7 THEN day_of_week = 'sunday'
            END
        LOOP
            -- Insert with ON CONFLICT DO NOTHING to skip duplicates gracefully
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
            -- Skip duplicate lessons at same date/time/location (unique_schedule_slot constraint)
            ON CONFLICT (class_date, start_time, location) DO NOTHING;
            
            -- Increment counter (note: this counts attempts, not actual inserts due to ON CONFLICT)
            instances_created := instances_created + 1;
        END LOOP;
        
        iter_date := iter_date + INTERVAL '1 day';
    END LOOP;
    
    RETURN instances_created;
END;
$function$;

-- Add comment explaining the fix
COMMENT ON FUNCTION public.generate_seasonal_schedule_instances(uuid) IS 
'Generates schedule instances for a seasonal schedule. Uses ON CONFLICT DO NOTHING to skip duplicates gracefully when lessons already exist at the same date/time/location.';