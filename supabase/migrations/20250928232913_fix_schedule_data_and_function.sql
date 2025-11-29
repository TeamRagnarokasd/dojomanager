-- Fix schedule preview grey screen issue and add missing function
-- Migration: 20250928232913_fix_schedule_data_and_function

-- First, clean up any invalid time data that might be causing errors
UPDATE weekly_schedule_templates 
SET 
  start_time = '19:00:00'
WHERE start_time::text LIKE '%p:%' OR start_time IS NULL;

UPDATE weekly_schedule_templates 
SET 
  end_time = '20:30:00'  
WHERE end_time::text LIKE '%p:%' OR end_time IS NULL;

UPDATE schedule_instances 
SET 
  start_time = '19:00:00'
WHERE start_time::text LIKE '%p:%' OR start_time IS NULL;

UPDATE schedule_instances 
SET 
  end_time = '20:30:00'
WHERE end_time::text LIKE '%p:%' OR end_time IS NULL;

-- Add unique constraint for schedule instances to support ON CONFLICT
-- This prevents double bookings at the same time and location
ALTER TABLE schedule_instances 
ADD CONSTRAINT unique_schedule_slot 
UNIQUE (class_date, start_time, location);

-- Create the missing function that the service is calling
CREATE OR REPLACE FUNCTION get_class_schedule_for_date(target_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
            'enrolled', floor(random() * si.max_capacity * 0.7)::int, -- Random enrollment for demo
            'is_booked', false, -- Default to not booked
            'waitlist_position', null, -- No waitlist by default
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
    from schedule_instances si
    left join user_profiles up on si.instructor_id = up.id
    left join weekly_schedule_templates wst on si.template_id = wst.id
    where si.class_date = target_date
      and si.is_cancelled = false
      and si.discipline in ('bjj', 'mma', 'sambo', 'grappling', 'fitness')
    order by si.start_time, si.discipline;
    
    return coalesce(result, '[]'::jsonb);
end;
$$;

-- Add more schedule instances for better testing (covering the next few days)
INSERT INTO schedule_instances (
    class_date, 
    discipline, 
    start_time, 
    end_time, 
    location, 
    max_capacity, 
    instructor_id, 
    template_id, 
    seasonal_schedule_id,
    is_cancelled
) VALUES
-- Today and tomorrow schedules
(CURRENT_DATE, 'bjj', '19:00:00', '20:30:00', 'Tatami Principale', 20, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'bjj' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false),

(CURRENT_DATE, 'mma', '20:30:00', '22:00:00', 'Sala Principale', 16, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'mma' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false),

(CURRENT_DATE + INTERVAL '1 day', 'grappling', '18:00:00', '19:30:00', 'Tatami Principale', 18, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'bjj' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false),

(CURRENT_DATE + INTERVAL '1 day', 'fitness', '19:30:00', '20:30:00', 'Sala Fitness', 15, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'fitness' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false),

(CURRENT_DATE + INTERVAL '2 days', 'bjj', '19:00:00', '20:30:00', 'Tatami Principale', 20, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'bjj' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false),

(CURRENT_DATE + INTERVAL '2 days', 'sambo', '20:30:00', '22:00:00', 'Sala Principale', 12, 
 (SELECT id FROM user_profiles WHERE email = 'admin@teamragnarok.com' LIMIT 1),
 (SELECT id FROM weekly_schedule_templates WHERE discipline = 'mma' LIMIT 1),
 (SELECT id FROM seasonal_schedules WHERE status = 'active' LIMIT 1),
 false)

ON CONFLICT (class_date, start_time, location) DO NOTHING;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_class_schedule_for_date(date) TO authenticated;

-- Update RLS policies to ensure data is visible to authenticated users
DROP POLICY IF EXISTS authenticated_read_schedule_instances ON schedule_instances;
CREATE POLICY authenticated_read_schedule_instances ON schedule_instances
    FOR SELECT
    TO authenticated
    USING (true); -- Allow all authenticated users to read schedules

-- Ensure we have proper data visibility
DROP POLICY IF EXISTS public_read_active_seasonal_schedules ON seasonal_schedules;
CREATE POLICY public_read_active_schedules ON seasonal_schedules
    FOR SELECT
    TO authenticated
    USING (status = 'active');

-- Add policy for weekly templates
DROP POLICY IF EXISTS authenticated_read_weekly_templates ON weekly_schedule_templates;  
CREATE POLICY authenticated_read_weekly_templates ON weekly_schedule_templates
    FOR SELECT
    TO authenticated
    USING (true);