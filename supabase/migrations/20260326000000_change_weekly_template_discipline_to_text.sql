-- Migration: Change weekly_schedule_templates.discipline from ENUM to TEXT
-- This allows storing custom discipline names from the custom_disciplines table
-- instead of being restricted to the discipline_type ENUM values

-- Step 1: Drop dependent objects that reference the discipline column as ENUM
-- (No foreign keys reference this column, but we need to handle the type change)

-- Step 2: Change the discipline column type from discipline_type ENUM to TEXT
ALTER TABLE public.weekly_schedule_templates
ALTER COLUMN discipline TYPE TEXT USING discipline::TEXT;

-- Step 3: Also change schedule_instances.discipline to TEXT for consistency
ALTER TABLE public.schedule_instances
ALTER COLUMN discipline TYPE TEXT USING discipline::TEXT;

-- Step 4: Also change seasonal_holidays.affected_disciplines array to TEXT[] for consistency
ALTER TABLE public.seasonal_holidays
ALTER COLUMN affected_disciplines TYPE TEXT[] USING affected_disciplines::TEXT[];
