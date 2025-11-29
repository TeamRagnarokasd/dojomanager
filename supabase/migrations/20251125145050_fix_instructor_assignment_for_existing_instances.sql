-- Migration: Fix instructor assignment for existing schedule instances
-- Description: Updates NULL instructor_id values in schedule_instances by copying from weekly_schedule_templates
-- Date: 2025-11-25

-- Step 1: Update existing schedule_instances with NULL instructor_id by copying from template
UPDATE public.schedule_instances si
SET instructor_id = wst.instructor_id
FROM public.weekly_schedule_templates wst
WHERE si.template_id = wst.id
  AND si.instructor_id IS NULL
  AND wst.instructor_id IS NOT NULL;

-- Step 2: Log the update results
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % schedule instances with instructor assignments from templates', updated_count;
END $$;

-- Step 3: Verify the results by showing schedule instances that still have NULL instructor_id
DO $$
DECLARE
    remaining_null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining_null_count
    FROM public.schedule_instances
    WHERE instructor_id IS NULL;
    
    IF remaining_null_count > 0 THEN
        RAISE WARNING 'Warning: % schedule instances still have NULL instructor_id', remaining_null_count;
    ELSE
        RAISE NOTICE 'Success: All schedule instances now have instructor assignments';
    END IF;
END $$;

-- Step 4: Add helpful comment
COMMENT ON TRIGGER trigger_set_instructor_from_template ON public.schedule_instances IS 
'Automatically sets instructor_id from weekly_schedule_templates when creating new schedule instances. This migration fixes existing records created before this trigger was added.';