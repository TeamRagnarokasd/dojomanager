-- Location: supabase/migrations/20250922111111_populate_class_schedule_sample_data.sql
-- Schema Analysis: Complete class scheduling system exists with schedule_instances, weekly_schedule_templates, seasonal_schedules, user_profiles
-- Integration Type: Additive - Adding sample data to existing schema
-- Dependencies: schedule_instances, weekly_schedule_templates, seasonal_schedules, user_profiles tables

-- Populate sample class schedule data to replace static mock data
DO $$
DECLARE
    existing_user_id UUID;
    instructor1_id UUID := gen_random_uuid();
    instructor2_id UUID := gen_random_uuid();
    instructor3_id UUID := gen_random_uuid();
    season_id UUID := gen_random_uuid();
    template1_id UUID := gen_random_uuid();
    template2_id UUID := gen_random_uuid();
    template3_id UUID := gen_random_uuid();
    template4_id UUID := gen_random_uuid();
    template5_id UUID := gen_random_uuid();
BEGIN
    -- Get existing user ID (assume user_profiles exists from previous migrations)
    SELECT id INTO existing_user_id FROM public.user_profiles LIMIT 1;
    
    -- If no existing users, create sample instructors for class schedule
    IF existing_user_id IS NULL THEN
        -- Create sample instructor users directly in user_profiles
        INSERT INTO public.user_profiles (id, email, full_name, role, status, is_active)
        VALUES 
            (instructor1_id, 'marco.rossi@teamragnarok.it', 'Marco Rossi', 'instructor', 'approved', true),
            (instructor2_id, 'anna.bianchi@teamragnarok.it', 'Anna Bianchi', 'instructor', 'approved', true),
            (instructor3_id, 'giuseppe.verdi@teamragnarok.it', 'Giuseppe Verdi', 'instructor', 'approved', true)
        ON CONFLICT (id) DO NOTHING;
    ELSE
        -- Use existing user as instructor for demo
        instructor1_id := existing_user_id;
        instructor2_id := existing_user_id;
        instructor3_id := existing_user_id;
    END IF;

    -- Create sample seasonal schedule
    INSERT INTO public.seasonal_schedules (id, title, description, start_date, end_date, status, created_by)
    VALUES (
        season_id,
        'Stagione Autunno/Inverno 2025',
        'Programmazione corsi per la stagione autunno/inverno 2025 con focus su BJJ, MMA, Sambo e Grappling',
        '2025-09-01'::date,
        '2026-02-28'::date,
        'active'::season_status,
        instructor1_id
    )
    ON CONFLICT (id) DO NOTHING;

    -- Create weekly schedule templates
    INSERT INTO public.weekly_schedule_templates (id, seasonal_schedule_id, instructor_id, day_of_week, start_time, end_time, discipline, location, max_capacity, notes)
    VALUES 
        (template1_id, season_id, instructor1_id, 'thursday', '09:00:00', '10:30:00', 'bjj', 'Palestra Principale', 20, 'BJJ tradizionale per principianti e intermedi. Focus su tecniche di base, posizioni e sottomissioni.'),
        (template2_id, season_id, instructor2_id, 'thursday', '11:00:00', '12:30:00', 'grappling', 'Palestra Principale', 16, 'Allenamento di Grappling con focus su tecniche di controllo e finalizzazioni.'),
        (template3_id, season_id, instructor3_id, 'thursday', '15:00:00', '16:30:00', 'mma', 'Palestra Principale', 18, 'Corso di MMA con enfasi su tecniche miste e condizionamento atletico.'),
        (template4_id, season_id, instructor1_id, 'thursday', '17:30:00', '19:00:00', 'bjj', 'Palestra Principale', 22, 'BJJ avanzato con focus su applicazioni competitive e strategia di gara.'),
        (template5_id, season_id, instructor2_id, 'thursday', '19:30:00', '21:00:00', 'sambo', 'Palestra Principale', 20, 'Sambo competitivo per atleti esperti. Preparazione per competizioni regionali e nazionali.')
    ON CONFLICT (id) DO NOTHING;

    -- Create specific schedule instances for the current week (Thursday, September 22, 2025)
    INSERT INTO public.schedule_instances (id, seasonal_schedule_id, template_id, instructor_id, class_date, start_time, end_time, discipline, location, max_capacity, is_cancelled, is_holiday_affected)
    VALUES 
        (gen_random_uuid(), season_id, template1_id, instructor1_id, '2025-09-25'::date, '09:00:00', '10:30:00', 'bjj', 'Palestra Principale', 20, false, false),
        (gen_random_uuid(), season_id, template2_id, instructor2_id, '2025-09-25'::date, '11:00:00', '12:30:00', 'grappling', 'Palestra Principale', 16, false, false),
        (gen_random_uuid(), season_id, template3_id, instructor3_id, '2025-09-25'::date, '15:00:00', '16:30:00', 'mma', 'Palestra Principale', 18, false, false),
        (gen_random_uuid(), season_id, template4_id, instructor1_id, '2025-09-25'::date, '17:30:00', '19:00:00', 'bjj', 'Palestra Principale', 22, false, false),
        (gen_random_uuid(), season_id, template5_id, instructor2_id, '2025-09-25'::date, '19:30:00', '21:00:00', 'sambo', 'Palestra Principale', 20, false, false),
        
        -- Add instances for the next few days
        (gen_random_uuid(), season_id, template1_id, instructor1_id, '2025-09-26'::date, '09:00:00', '10:30:00', 'bjj', 'Palestra Principale', 20, false, false),
        (gen_random_uuid(), season_id, template3_id, instructor3_id, '2025-09-26'::date, '17:30:00', '19:00:00', 'mma', 'Palestra Principale', 18, false, false),
        (gen_random_uuid(), season_id, template5_id, instructor2_id, '2025-09-26'::date, '19:30:00', '21:00:00', 'sambo', 'Palestra Principale', 20, false, false),
        
        (gen_random_uuid(), season_id, template2_id, instructor2_id, '2025-09-27'::date, '10:00:00', '11:30:00', 'grappling', 'Palestra Principale', 16, false, false),
        (gen_random_uuid(), season_id, template4_id, instructor1_id, '2025-09-27'::date, '18:00:00', '19:30:00', 'bjj', 'Palestra Principale', 22, false, false)
    ON CONFLICT (id) DO NOTHING;

    -- Create some booking tracking data (using existing subscription system if available)
    -- Note: This would typically integrate with user_subscriptions and subscription_entry_usage tables
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint error in class schedule data: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error in class schedule data: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error creating class schedule data: %', SQLERRM;
END $$;

-- Create a function to get formatted class data for the Flutter app
CREATE OR REPLACE FUNCTION public.get_class_schedule_for_date(target_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    id UUID,
    discipline TEXT,
    instructor_name TEXT,
    instructor_email TEXT,
    time_range TEXT,
    date_formatted TEXT,
    capacity INTEGER,
    location TEXT,
    is_cancelled BOOLEAN,
    start_time TIME,
    end_time TIME,
    class_date DATE
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    si.id,
    si.discipline::TEXT,
    COALESCE(up.full_name, 'Istruttore Disponibile') as instructor_name,
    COALESCE(up.email, '') as instructor_email,
    (si.start_time::TEXT || ' - ' || si.end_time::TEXT) as time_range,
    TO_CHAR(si.class_date, 'DD/MM/YYYY') as date_formatted,
    si.max_capacity,
    si.location,
    si.is_cancelled,
    si.start_time,
    si.end_time,
    si.class_date
FROM public.schedule_instances si
LEFT JOIN public.user_profiles up ON si.instructor_id = up.id
WHERE si.class_date = target_date
    AND si.is_cancelled = false
ORDER BY si.start_time;
$$;