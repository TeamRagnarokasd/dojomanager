-- =====================================================
-- AUTO-POPULATE SEASONAL SCHEDULE INSTANCES
-- =====================================================
-- Purpose: Automatically generate schedule_instances for the entire duration
--          of active seasonal schedules based on weekly templates
-- Dependencies: seasonal_schedules, weekly_schedule_templates, schedule_instances
-- =====================================================

DO $$
DECLARE
    active_season RECORD;
    template RECORD;
    iteration_date DATE;
    instances_count INT;
    expected_instances INT;
    season_duration_days INT;
BEGIN
    RAISE NOTICE '🚀 Starting seasonal schedule instance population...';
    
    -- Loop through all active seasonal schedules
    FOR active_season IN 
        SELECT id, title, start_date, end_date 
        FROM seasonal_schedules 
        WHERE status = 'active'
    LOOP
        RAISE NOTICE '📅 Processing season: % (% to %)', 
            active_season.title, 
            active_season.start_date, 
            active_season.end_date;
        
        -- Calculate season duration in days
        season_duration_days := active_season.end_date - active_season.start_date;
        
        -- Check how many instances already exist for this season
        SELECT COUNT(*) INTO instances_count
        FROM schedule_instances
        WHERE seasonal_schedule_id = active_season.id;
        
        -- Calculate expected instances (approximately 2 classes per week for the duration)
        -- This is a rough estimate: (total days / 7 days per week) * 2 classes per week
        expected_instances := (season_duration_days / 7) * 2;
        
        RAISE NOTICE '   📊 Current instances: %, Expected: % (season duration: % days)', 
            instances_count, 
            expected_instances,
            season_duration_days;
        
        -- If we have very few instances compared to what we should have, populate them
        IF instances_count < (expected_instances * 0.5) THEN
            RAISE NOTICE '   ⚠️  Insufficient instances detected. Generating...';
            
            -- Loop through each weekly template for this season
            FOR template IN 
                SELECT 
                    id,
                    day_of_week,
                    start_time,
                    end_time,
                    location,
                    discipline,
                    instructor_id,
                    max_capacity
                FROM weekly_schedule_templates
                WHERE seasonal_schedule_id = active_season.id
            LOOP
                RAISE NOTICE '   📋 Processing template: % at % in %', 
                    template.discipline, 
                    template.start_time,
                    template.location;
                
                -- Start from the season start date
                iteration_date := active_season.start_date;
                
                -- Adjust to the first occurrence of the target day
                WHILE EXTRACT(DOW FROM iteration_date) != 
                      CASE template.day_of_week
                          WHEN 'monday' THEN 1
                          WHEN 'tuesday' THEN 2
                          WHEN 'wednesday' THEN 3
                          WHEN 'thursday' THEN 4
                          WHEN 'friday' THEN 5
                          WHEN 'saturday' THEN 6
                          WHEN 'sunday' THEN 0
                      END
                LOOP
                    iteration_date := iteration_date + 1;
                END LOOP;
                
                -- Generate instances for every week until season end
                WHILE iteration_date <= active_season.end_date LOOP
                    -- Check if instance already exists (avoid duplicates)
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM schedule_instances 
                        WHERE class_date = iteration_date
                        AND start_time = template.start_time
                        AND location = template.location
                    ) THEN
                        -- Insert the instance
                        INSERT INTO schedule_instances (
                            seasonal_schedule_id,
                            template_id,
                            class_date,
                            start_time,
                            end_time,
                            location,
                            discipline,
                            instructor_id,
                            max_capacity,
                            is_cancelled,
                            is_holiday_affected
                        ) VALUES (
                            active_season.id,
                            template.id,
                            iteration_date,
                            template.start_time,
                            template.end_time,
                            template.location,
                            template.discipline,
                            template.instructor_id,
                            template.max_capacity,
                            false,
                            false
                        );
                        
                        RAISE NOTICE '      ✅ Created instance for % at %', 
                            iteration_date, 
                            template.start_time;
                    ELSE
                        RAISE NOTICE '      ⏭️  Instance already exists for % at %', 
                            iteration_date, 
                            template.start_time;
                    END IF;
                    
                    -- Move to next week
                    iteration_date := iteration_date + 7;
                END LOOP;
            END LOOP;
            
            RAISE NOTICE '   ✅ Completed populating instances for season: %', active_season.title;
        ELSE
            RAISE NOTICE '   ℹ️  Season already has sufficient instances. Skipping.';
        END IF;
    END LOOP;
    
    RAISE NOTICE '🎉 Seasonal schedule instance population completed successfully!';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Error populating seasonal schedule instances: %', SQLERRM;
END $$;

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
-- Run this to verify the instances were created correctly
SELECT 
    ss.title AS season_title,
    COUNT(DISTINCT si.class_date) AS unique_dates,
    COUNT(*) AS total_instances,
    MIN(si.class_date) AS first_class,
    MAX(si.class_date) AS last_class
FROM seasonal_schedules ss
LEFT JOIN schedule_instances si ON si.seasonal_schedule_id = ss.id
WHERE ss.status = 'active'
GROUP BY ss.id, ss.title
ORDER BY ss.start_date;