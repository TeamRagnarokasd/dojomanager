-- Location: supabase/migrations/20250902124054_seasonal_schedule_management.sql
-- Schema Analysis: Existing user_profiles, user_role enum, and admin functions available
-- Integration Type: Addition - Building new seasonal schedule management functionality
-- Dependencies: user_profiles table, existing admin functions

-- 1. Create ENUM Types for seasonal scheduling
CREATE TYPE public.discipline_type AS ENUM (
    'bjj', 
    'mma', 
    'sambo', 
    'grappling', 
    'fitness'
);

CREATE TYPE public.day_of_week AS ENUM (
    'monday', 
    'tuesday', 
    'wednesday', 
    'thursday', 
    'friday', 
    'saturday', 
    'sunday'
);

CREATE TYPE public.season_status AS ENUM (
    'draft', 
    'active', 
    'completed', 
    'cancelled'
);

-- 2. Create Seasonal Schedules table (Core entity)
CREATE TABLE public.seasonal_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status public.season_status DEFAULT 'draft'::public.season_status,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Validation constraints
    CONSTRAINT valid_date_range CHECK (end_date > start_date)
);

-- 3. Create Weekly Template Schedules
CREATE TABLE public.weekly_schedule_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seasonal_schedule_id UUID REFERENCES public.seasonal_schedules(id) ON DELETE CASCADE,
    day_of_week public.day_of_week NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    discipline public.discipline_type NOT NULL,
    instructor_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    location TEXT NOT NULL,
    max_capacity INTEGER DEFAULT 20,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Validation constraints
    CONSTRAINT valid_time_range CHECK (end_time > start_time),
    CONSTRAINT valid_capacity CHECK (max_capacity > 0)
);

-- 4. Create Holiday Exceptions table
CREATE TABLE public.seasonal_holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seasonal_schedule_id UUID REFERENCES public.seasonal_schedules(id) ON DELETE CASCADE,
    holiday_date DATE NOT NULL,
    holiday_name TEXT NOT NULL,
    affects_all_classes BOOLEAN DEFAULT true,
    affected_disciplines public.discipline_type[],
    replacement_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Create Generated Schedule Instances (Auto-generated from templates)
CREATE TABLE public.schedule_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seasonal_schedule_id UUID REFERENCES public.seasonal_schedules(id) ON DELETE CASCADE,
    template_id UUID REFERENCES public.weekly_schedule_templates(id) ON DELETE CASCADE,
    class_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    discipline public.discipline_type NOT NULL,
    instructor_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    location TEXT NOT NULL,
    max_capacity INTEGER DEFAULT 20,
    is_cancelled BOOLEAN DEFAULT false,
    cancellation_reason TEXT,
    is_holiday_affected BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Create Essential Indexes
CREATE INDEX idx_seasonal_schedules_status ON public.seasonal_schedules(status);
CREATE INDEX idx_seasonal_schedules_dates ON public.seasonal_schedules(start_date, end_date);
CREATE INDEX idx_seasonal_schedules_created_by ON public.seasonal_schedules(created_by);

CREATE INDEX idx_weekly_templates_schedule ON public.weekly_schedule_templates(seasonal_schedule_id);
CREATE INDEX idx_weekly_templates_day ON public.weekly_schedule_templates(day_of_week);
CREATE INDEX idx_weekly_templates_instructor ON public.weekly_schedule_templates(instructor_id);

CREATE INDEX idx_holidays_schedule ON public.seasonal_holidays(seasonal_schedule_id);
CREATE INDEX idx_holidays_date ON public.seasonal_holidays(holiday_date);

CREATE INDEX idx_schedule_instances_seasonal ON public.schedule_instances(seasonal_schedule_id);
CREATE INDEX idx_schedule_instances_date ON public.schedule_instances(class_date);
CREATE INDEX idx_schedule_instances_instructor ON public.schedule_instances(instructor_id);

-- 7. Create Helper Functions (BEFORE RLS policies)
CREATE OR REPLACE FUNCTION public.generate_seasonal_schedule_instances(schedule_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
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
    
    -- Clear existing instances
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
            -- Check if this date is a holiday
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
            );
            
            instances_created := instances_created + 1;
        END LOOP;
        
        iter_date := iter_date + INTERVAL '1 day';
    END LOOP;
    
    RETURN instances_created;
END;
$func$;

-- 8. Enable RLS on all tables
ALTER TABLE public.seasonal_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_schedule_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasonal_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedule_instances ENABLE ROW LEVEL SECURITY;

-- 9. Create RLS Policies (Using existing admin functions)

-- Seasonal schedules: Only admins can manage
CREATE POLICY "admin_manage_seasonal_schedules"
ON public.seasonal_schedules
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- Public can read active schedules
CREATE POLICY "public_read_active_seasonal_schedules"
ON public.seasonal_schedules
FOR SELECT
TO public
USING (status = 'active'::public.season_status);

-- Weekly templates: Only admins can manage
CREATE POLICY "admin_manage_weekly_templates"
ON public.weekly_schedule_templates
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- Holidays: Only admins can manage
CREATE POLICY "admin_manage_holidays"
ON public.seasonal_holidays
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- Schedule instances: Read for all authenticated, manage for admins
CREATE POLICY "authenticated_read_schedule_instances"
ON public.schedule_instances
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "admin_manage_schedule_instances"
ON public.schedule_instances
FOR ALL
TO authenticated
USING (public.is_admin_level())
WITH CHECK (public.is_admin_level());

-- 10. Mock Data Generation
DO $$
DECLARE
    admin_user_id UUID;
    instructor_user_id UUID;
    season_id UUID := gen_random_uuid();
    template_monday_bjj UUID := gen_random_uuid();
    template_wednesday_mma UUID := gen_random_uuid();
    template_friday_grappling UUID := gen_random_uuid();
BEGIN
    -- Get existing admin and instructor user IDs
    SELECT id INTO admin_user_id FROM public.user_profiles 
    WHERE role IN ('admin', 'principal_admin') 
    LIMIT 1;
    
    SELECT id INTO instructor_user_id FROM public.user_profiles 
    WHERE role = 'instructor' 
    LIMIT 1;
    
    -- Create mock seasonal schedule
    INSERT INTO public.seasonal_schedules (
        id, title, description, start_date, end_date, status, created_by
    ) VALUES (
        season_id,
        'Stagione Autunno 2025',
        'Palinsesto completo autunnale con corsi BJJ, MMA, SAMBO e Grappling per tutti i livelli',
        '2025-09-15',
        '2025-12-22',
        'draft'::public.season_status,
        admin_user_id
    );
    
    -- Create weekly schedule templates
    INSERT INTO public.weekly_schedule_templates (
        id, seasonal_schedule_id, day_of_week, start_time, end_time, 
        discipline, instructor_id, location, max_capacity, notes
    ) VALUES 
        (template_monday_bjj, season_id, 'monday'::public.day_of_week, '18:00', '19:30', 
         'bjj'::public.discipline_type, instructor_user_id, 'Palestra Principale', 25, 'Corso BJJ base e avanzato'),
        (template_wednesday_mma, season_id, 'wednesday'::public.day_of_week, '19:00', '20:30', 
         'mma'::public.discipline_type, instructor_user_id, 'Palestra Principale', 20, 'Allenamento MMA completo'),
        (template_friday_grappling, season_id, 'friday'::public.day_of_week, '18:30', '20:00', 
         'grappling'::public.discipline_type, instructor_user_id, 'Sala Tatami', 22, 'Grappling no-gi avanzato');
    
    -- Add holiday exceptions
    INSERT INTO public.seasonal_holidays (
        seasonal_schedule_id, holiday_date, holiday_name, affects_all_classes, notes
    ) VALUES 
        (season_id, '2025-11-01', 'Ognissanti', true, 'Palestra chiusa per festivita nazionale'),
        (season_id, '2025-12-08', 'Immacolata Concezione', true, 'Festivita religiosa'),
        (season_id, '2025-12-25', 'Natale', true, 'Chiusura natalizia'),
        (season_id, '2025-12-26', 'Santo Stefano', true, 'Chiusura post-natalizia');

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mock data creation error: %', SQLERRM;
END $$;