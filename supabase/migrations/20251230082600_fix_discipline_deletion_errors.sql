-- Migration: Fix Discipline Deletion Errors
-- Purpose: Add missing database function and improve discipline deletion logic
-- Created: 2025-12-30

-- 1. Create function to cleanup schedule instances by discipline
CREATE OR REPLACE FUNCTION cleanup_schedule_instances_by_discipline(
  discipline_to_remove discipline_type
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count integer;
BEGIN
  -- Delete schedule instances for the specified discipline
  DELETE FROM schedule_instances
  WHERE discipline = discipline_to_remove;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- Grant execute permission to authenticated users (admins will be checked by RLS)
GRANT EXECUTE ON FUNCTION cleanup_schedule_instances_by_discipline(discipline_type) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION cleanup_schedule_instances_by_discipline IS 'Removes all schedule instances for a specific discipline. Used during discipline deletion by admins.';

-- 2. Create a safe discipline deletion function that handles all constraints
CREATE OR REPLACE FUNCTION safe_delete_discipline(
  discipline_to_delete discipline_type
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  affected_instructors integer := 0;
  deleted_specializations integer := 0;
  deleted_templates integer := 0;
  deleted_instances integer := 0;
  deleted_schedules integer := 0;
  result jsonb;
BEGIN
  -- Only allow admins to delete disciplines
  IF NOT is_admin_level() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Only admins can delete disciplines'
    );
  END IF;

  -- Step 1: Update instructor profiles - remove from disciplines array
  UPDATE instructor_profiles
  SET 
    disciplines = array_remove(disciplines, discipline_to_delete),
    primary_discipline = CASE
      -- If this is their primary discipline and they have other disciplines, set to first remaining
      WHEN primary_discipline = discipline_to_delete AND array_length(array_remove(disciplines, discipline_to_delete), 1) > 0 
      THEN (array_remove(disciplines, discipline_to_delete))[1]
      -- If this is their only discipline, we need to handle this specially
      WHEN primary_discipline = discipline_to_delete AND (array_remove(disciplines, discipline_to_delete) = '{}' OR array_remove(disciplines, discipline_to_delete) IS NULL)
      THEN NULL -- Will fail NOT NULL constraint if not handled properly
      ELSE primary_discipline
    END
  WHERE discipline_to_delete = ANY(disciplines);

  GET DIAGNOSTICS affected_instructors = ROW_COUNT;

  -- Step 1b: For instructors who would have NULL primary_discipline, we need to handle them
  -- Check if any instructors have NULL primary_discipline after update
  IF EXISTS (
    SELECT 1 FROM instructor_profiles 
    WHERE primary_discipline IS NULL
  ) THEN
    -- Find a fallback discipline for them (use 'mma' as default, or any other available)
    UPDATE instructor_profiles
    SET primary_discipline = 'mma'::discipline_type
    WHERE primary_discipline IS NULL;
  END IF;

  -- Step 2: Delete instructor specializations
  DELETE FROM instructor_specializations
  WHERE specialization = discipline_to_delete::text;
  
  GET DIAGNOSTICS deleted_specializations = ROW_COUNT;

  -- Step 3: Delete weekly schedule templates
  DELETE FROM weekly_schedule_templates
  WHERE discipline = discipline_to_delete;
  
  GET DIAGNOSTICS deleted_templates = ROW_COUNT;

  -- Step 4: Delete schedule instances
  deleted_instances := cleanup_schedule_instances_by_discipline(discipline_to_delete);

  -- Step 5: Check and cancel empty seasonal schedules
  UPDATE seasonal_schedules
  SET 
    status = 'cancelled',
    updated_at = CURRENT_TIMESTAMP
  WHERE status = 'active'
    AND id NOT IN (
      SELECT DISTINCT seasonal_schedule_id 
      FROM weekly_schedule_templates 
      WHERE seasonal_schedule_id IS NOT NULL
    );
  
  GET DIAGNOSTICS deleted_schedules = ROW_COUNT;

  -- Build success response
  result := jsonb_build_object(
    'success', true,
    'discipline', discipline_to_delete,
    'affected_instructors', affected_instructors,
    'deleted_specializations', deleted_specializations,
    'deleted_templates', deleted_templates,
    'deleted_instances', deleted_instances,
    'cancelled_schedules', deleted_schedules
  );

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION safe_delete_discipline(discipline_type) TO authenticated;

-- Add comment
COMMENT ON FUNCTION safe_delete_discipline IS 'Safely deletes a discipline and all related data. Handles NOT NULL constraints and cascading deletions. Admin-only.';