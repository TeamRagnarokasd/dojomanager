-- Location: supabase/migrations/20250922110544_add_class_schedule_mock_data.sql
-- Schema Analysis: Complete class schedule system exists with schedule_instances, weekly_schedule_templates, seasonal_schedules, user_profiles
-- Integration Type: Mock data addition to existing schema
-- Dependencies: schedule_instances, weekly_schedule_templates, seasonal_schedules, user_profiles

-- Add mock data for class schedule functionality
-- Note: Using existing schema objects, no new table creation needed

DO $$
DECLARE
    active_season_id UUID := gen_random_uuid();
    instructor_id UUID;
    template_monday_bjj UUID := gen_random_uuid();
    template_tuesday_mma UUID := gen_random_uuid();
    template_wednesday_grappling UUID := gen_random_uuid();
    template_thursday_sambo UUID := gen_random_uuid();
    template_friday_fitness UUID := gen_random_uuid();
    today_date DATE := CURRENT_DATE;
    week_start DATE;
    i INTEGER;
BEGIN
    -- Get existing instructor (use principal admin as instructor)
    SELECT id INTO instructor_id FROM public.user_profiles WHERE role = 'principal_admin' LIMIT 1;
    
    -- If no instructor found, create a notice
    IF instructor_id IS NULL THEN
        RAISE NOTICE 'No instructor found in user_profiles. Please ensure users exist first.';
        RETURN;
    END IF;

    -- Create active seasonal schedule for current academic year
    INSERT INTO public.seasonal_schedules (
        id,
        title,
        description,
        start_date,
        end_date,
        status,
        created_by
    ) VALUES (
        active_season_id,
        'Anno Sportivo 2024-2025',
        'Stagione sportiva completa con corsi di arti marziali - BJJ, MMA, Sambo, Grappling e Fitness',
        '2024-09-01',
        '2025-07-31',
        'active'::public.season_status,
        instructor_id
    );

    -- Create weekly schedule templates for different disciplines
    INSERT INTO public.weekly_schedule_templates (
        id,
        seasonal_schedule_id,
        day_of_week,
        start_time,
        end_time,
        discipline,
        location,
        max_capacity,
        instructor_id,
        notes
    ) VALUES
    -- Monday BJJ
    (template_monday_bjj, active_season_id, 'monday'::public.day_of_week, '19:00'::time, '20:30'::time, 
     'bjj'::public.discipline_type, 'Tatami Principale', 20, instructor_id,
     'Corso Brazilian Jiu-Jitsu per tutti i livelli. Focus su tecniche di base, guard passing e submissions.'),
    
    -- Tuesday MMA
    (template_tuesday_mma, active_season_id, 'tuesday'::public.day_of_week, '20:00'::time, '21:30'::time,
     'mma'::public.discipline_type, 'Sala Principale', 16, instructor_id,
     'Allenamento MMA completo con striking, clinch, takedowns e ground game.'),
    
    -- Wednesday Grappling
    (template_wednesday_grappling, active_season_id, 'wednesday'::public.day_of_week, '18:30'::time, '20:00'::time,
     'grappling'::public.discipline_type, 'Tatami Principale', 18, instructor_id,
     'No-Gi Grappling e submission wrestling. Tecniche avanzate di controllo e finalizzazione.'),
    
    -- Thursday Sambo
    (template_thursday_sambo, active_season_id, 'thursday'::public.day_of_week, '19:30'::time, '21:00'::time,
     'sambo'::public.discipline_type, 'Sala Principale', 15, instructor_id,
     'Combat Sambo con focus su proiezioni, controllo a terra e striking limitato.'),
    
    -- Friday Fitness
    (template_friday_fitness, active_season_id, 'friday'::public.day_of_week, '18:00'::time, '19:00'::time,
     'fitness'::public.discipline_type, 'Area Fitness', 25, instructor_id,
     'Preparazione atletica funzionale per arti marziali. Forza, resistenza e mobilità.');

    -- Generate schedule instances for the next 4 weeks
    week_start := date_trunc('week', today_date);
    
    FOR i IN 0..3 LOOP
        -- Monday BJJ
        INSERT INTO public.schedule_instances (
            template_id,
            seasonal_schedule_id,
            instructor_id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            is_holiday_affected
        ) VALUES (
            template_monday_bjj,
            active_season_id,
            instructor_id,
            week_start + (i * 7),
            '19:00'::time,
            '20:30'::time,
            'bjj'::public.discipline_type,
            'Tatami Principale',
            20,
            false,
            false
        );
        
        -- Tuesday MMA
        INSERT INTO public.schedule_instances (
            template_id,
            seasonal_schedule_id,
            instructor_id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            is_holiday_affected
        ) VALUES (
            template_tuesday_mma,
            active_season_id,
            instructor_id,
            week_start + (i * 7) + 1,
            '20:00'::time,
            '21:30'::time,
            'mma'::public.discipline_type,
            'Sala Principale',
            16,
            false,
            false
        );
        
        -- Wednesday Grappling
        INSERT INTO public.schedule_instances (
            template_id,
            seasonal_schedule_id,
            instructor_id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            is_holiday_affected
        ) VALUES (
            template_wednesday_grappling,
            active_season_id,
            instructor_id,
            week_start + (i * 7) + 2,
            '18:30'::time,
            '20:00'::time,
            'grappling'::public.discipline_type,
            'Tatami Principale',
            18,
            false,
            false
        );
        
        -- Thursday Sambo
        INSERT INTO public.schedule_instances (
            template_id,
            seasonal_schedule_id,
            instructor_id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            is_holiday_affected
        ) VALUES (
            template_thursday_sambo,
            active_season_id,
            instructor_id,
            week_start + (i * 7) + 3,
            '19:30'::time,
            '21:00'::time,
            'sambo'::public.discipline_type,
            'Sala Principale',
            15,
            false,
            false
        );
        
        -- Friday Fitness
        INSERT INTO public.schedule_instances (
            template_id,
            seasonal_schedule_id,
            instructor_id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            is_holiday_affected
        ) VALUES (
            template_friday_fitness,
            active_season_id,
            instructor_id,
            week_start + (i * 7) + 4,
            '18:00'::time,
            '19:00'::time,
            'fitness'::public.discipline_type,
            'Area Fitness',
            25,
            false,
            false
        );
    END LOOP;

    RAISE NOTICE 'Successfully created class schedule mock data:';
    RAISE NOTICE '- 1 active seasonal schedule (Anno Sportivo 2024-2025)';
    RAISE NOTICE '- 5 weekly schedule templates (BJJ, MMA, Grappling, Sambo, Fitness)';
    RAISE NOTICE '- 20 schedule instances for the next 4 weeks';
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %. Check that user_profiles table has data.', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %. Data may already exist.', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;