-- Migration: Remove 'fitness' (Prep. Atletica) discipline from the system
-- This removes the yellow discipline element from admin-discipline screen

-- Step 1: Remove 'fitness' from instructor_profiles disciplines arrays
UPDATE instructor_profiles
SET disciplines = array_remove(disciplines, 'fitness')
WHERE 'fitness' = ANY(disciplines);

-- Step 2: Update primary_discipline if it was set to 'fitness'
UPDATE instructor_profiles
SET primary_discipline = CASE
    WHEN array_length(disciplines, 1) > 0 THEN disciplines[1]
    ELSE NULL
  END
WHERE primary_discipline = 'fitness';

-- Step 3: Delete weekly_schedule_templates entries for 'fitness' discipline
DELETE FROM weekly_schedule_templates
WHERE discipline = 'fitness';

-- Step 4: Delete schedule_instances entries for 'fitness' discipline
DELETE FROM schedule_instances
WHERE discipline = 'fitness';

-- Step 5: Delete class_registrations for 'fitness' classes (if any)
DELETE FROM class_registrations
WHERE class_id IN (
  SELECT id FROM schedule_instances WHERE discipline = 'fitness'
);

-- Verification: Check that 'fitness' discipline has been removed
-- Run these queries manually to verify:
-- SELECT * FROM instructor_profiles WHERE 'fitness' = ANY(disciplines);
-- SELECT * FROM weekly_schedule_templates WHERE discipline = 'fitness';
-- SELECT * FROM schedule_instances WHERE discipline = 'fitness';
