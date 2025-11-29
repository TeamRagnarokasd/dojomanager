-- Migration to clean up discontinued martial arts references
-- Schema Analysis: discipline_type enum only contains: ['bjj', 'mma', 'sambo', 'grappling', 'fitness']
-- Since karate, judo, taekwondo were never valid enum values, no records exist to clean up
-- This migration ensures the system is ready and provides utility functions for future use

-- Check if there are any records with invalid discipline references in text fields
-- (instructor_specializations uses TEXT, not enum, so it might contain discontinued martial arts)

-- Remove any instructor specializations for discontinued martial arts
DELETE FROM public.instructor_specializations
WHERE LOWER(specialization) IN ('karate', 'judo', 'taekwondo');

-- Note: schedule_instances and weekly_schedule_templates use discipline_type enum
-- Since karate, judo, taekwondo were never valid enum values, no cleanup needed for these tables

-- Create a logging function to track discipline cleanup operations
CREATE OR REPLACE FUNCTION public.log_discipline_cleanup()
RETURNS TABLE(
    table_name TEXT,
    records_found INTEGER,
    records_cleaned INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    instructor_specializations_count INTEGER := 0;
BEGIN
    -- Count and clean instructor_specializations
    SELECT COUNT(*) INTO instructor_specializations_count
    FROM public.instructor_specializations
    WHERE LOWER(specialization) IN ('karate', 'judo', 'taekwondo');
    
    DELETE FROM public.instructor_specializations
    WHERE LOWER(specialization) IN ('karate', 'judo', 'taekwondo');
    
    -- Return cleanup results
    RETURN QUERY VALUES 
        ('instructor_specializations'::TEXT, instructor_specializations_count, instructor_specializations_count);
    
    -- Log the operation
    RAISE NOTICE 'Discipline cleanup completed - instructor_specializations: % records removed', instructor_specializations_count;
END;
$$;

-- Create a validation function to ensure only valid disciplines are used
CREATE OR REPLACE FUNCTION public.validate_discipline_values()
RETURNS TABLE(
    issue_type TEXT,
    table_name TEXT,
    column_name TEXT,
    invalid_values TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invalid_specializations TEXT[];
BEGIN
    -- Check instructor_specializations for invalid values
    SELECT ARRAY_AGG(DISTINCT LOWER(specialization))
    INTO invalid_specializations
    FROM public.instructor_specializations
    WHERE LOWER(specialization) NOT IN ('bjj', 'mma', 'sambo', 'grappling', 'fitness');
    
    IF array_length(invalid_specializations, 1) > 0 THEN
        RETURN QUERY VALUES (
            'invalid_discipline'::TEXT,
            'instructor_specializations'::TEXT,
            'specialization'::TEXT,
            invalid_specializations
        );
    END IF;
    
    -- Note: schedule tables use enum so they're automatically validated
    RAISE NOTICE 'Discipline validation completed';
END;
$$;

-- Add comments for documentation
COMMENT ON FUNCTION public.log_discipline_cleanup IS 'Cleans up and logs discontinued martial arts disciplines from the database';
COMMENT ON FUNCTION public.validate_discipline_values IS 'Validates that all discipline values match the approved list: bjj, mma, sambo, grappling, fitness';

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Migration completed successfully - discontinued martial arts cleanup and validation functions created';
END $$;