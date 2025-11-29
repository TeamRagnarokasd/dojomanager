-- Migration: Fix Missing Instructor Assignments in Schedule Instances
-- Description: Updates NULL instructor_id values in schedule_instances by copying from weekly_schedule_templates
-- Date: 2025-11-22

-- Step 1: Update existing schedule_instances that have NULL instructor_id
-- Copy instructor_id from the linked weekly_schedule_template
UPDATE public.schedule_instances si
SET instructor_id = wst.instructor_id,
    updated_at = CURRENT_TIMESTAMP
FROM public.weekly_schedule_templates wst
WHERE si.template_id = wst.id
  AND si.instructor_id IS NULL
  AND wst.instructor_id IS NOT NULL;

-- Step 2: Create a trigger function to automatically set instructor_id when inserting schedule instances
CREATE OR REPLACE FUNCTION public.set_instructor_from_template()
RETURNS TRIGGER AS $$
BEGIN
    -- If instructor_id is NULL and template_id exists, copy from template
    IF NEW.instructor_id IS NULL AND NEW.template_id IS NOT NULL THEN
        SELECT instructor_id INTO NEW.instructor_id
        FROM public.weekly_schedule_templates
        WHERE id = NEW.template_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create trigger to automatically populate instructor_id on insert
DROP TRIGGER IF EXISTS trigger_set_instructor_from_template ON public.schedule_instances;
CREATE TRIGGER trigger_set_instructor_from_template
    BEFORE INSERT ON public.schedule_instances
    FOR EACH ROW
    EXECUTE FUNCTION public.set_instructor_from_template();

-- Step 4: Verify the updates
DO $$
DECLARE
    updated_count INTEGER;
    remaining_null INTEGER;
BEGIN
    -- Count how many were updated
    SELECT COUNT(*) INTO updated_count
    FROM public.schedule_instances
    WHERE instructor_id IS NOT NULL AND template_id IS NOT NULL;
    
    -- Count remaining NULLs
    SELECT COUNT(*) INTO remaining_null
    FROM public.schedule_instances
    WHERE instructor_id IS NULL;
    
    RAISE NOTICE 'Migration completed:';
    RAISE NOTICE '  - Schedule instances with instructors: %', updated_count;
    RAISE NOTICE '  - Remaining NULL instructor_ids: %', remaining_null;
    
    -- If there are still NULLs without templates, warn about them
    IF remaining_null > 0 THEN
        RAISE WARNING 'Some schedule instances still have NULL instructor_id. These may not have valid template_id references.';
    END IF;
END $$;