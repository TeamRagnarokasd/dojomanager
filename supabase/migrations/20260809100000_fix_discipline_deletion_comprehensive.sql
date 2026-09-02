-- Migration: Fix discipline deletion to handle all related tables
-- Purpose: Extend safe_delete_discipline to clean up discipline_subscription_plans
--          and add a text-based deletion function for custom/non-ENUM disciplines

-- ============================================================
-- 1. Recreate safe_delete_discipline with full cleanup
-- ============================================================
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
  deleted_plan_associations integer := 0;
  result jsonb;
BEGIN
  -- Only allow admins to delete disciplines
  IF NOT is_admin_level() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Only admins can delete disciplines'
    );
  END IF;

  -- Step 0: Delete discipline-subscription plan associations
  DELETE FROM public.discipline_subscription_plans
  WHERE discipline = discipline_to_delete;
  GET DIAGNOSTICS deleted_plan_associations = ROW_COUNT;

  -- Step 1: Update instructor profiles - remove from disciplines array
  UPDATE instructor_profiles
  SET 
    disciplines = array_remove(disciplines, discipline_to_delete),
    primary_discipline = CASE
      WHEN primary_discipline = discipline_to_delete AND array_length(array_remove(disciplines, discipline_to_delete), 1) > 0 
      THEN (array_remove(disciplines, discipline_to_delete))[1]
      WHEN primary_discipline = discipline_to_delete AND (array_remove(disciplines, discipline_to_delete) = '{}' OR array_remove(disciplines, discipline_to_delete) IS NULL)
      THEN NULL
      ELSE primary_discipline
    END
  WHERE discipline_to_delete = ANY(disciplines);

  GET DIAGNOSTICS affected_instructors = ROW_COUNT;

  -- Step 1b: Fix instructors with NULL primary_discipline
  UPDATE instructor_profiles
  SET primary_discipline = 'mma'::discipline_type
  WHERE primary_discipline IS NULL;

  -- Step 2: Delete instructor specializations
  DELETE FROM instructor_specializations
  WHERE specialization = discipline_to_delete::text;
  GET DIAGNOSTICS deleted_specializations = ROW_COUNT;

  -- Step 3: Delete weekly schedule templates
  DELETE FROM weekly_schedule_templates
  WHERE discipline = discipline_to_delete;
  GET DIAGNOSTICS deleted_templates = ROW_COUNT;

  -- Step 4: Delete schedule instances
  DELETE FROM schedule_instances
  WHERE discipline = discipline_to_delete;
  GET DIAGNOSTICS deleted_instances = ROW_COUNT;

  -- Step 5: Cancel empty seasonal schedules
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

  result := jsonb_build_object(
    'success', true,
    'discipline', discipline_to_delete,
    'affected_instructors', affected_instructors,
    'deleted_specializations', deleted_specializations,
    'deleted_templates', deleted_templates,
    'deleted_instances', deleted_instances,
    'cancelled_schedules', deleted_schedules,
    'deleted_plan_associations', deleted_plan_associations
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

GRANT EXECUTE ON FUNCTION safe_delete_discipline(discipline_type) TO authenticated;

-- ============================================================
-- 2. Create a text-based deletion function for custom disciplines
--    that also handles cleanup of all related tables
-- ============================================================
CREATE OR REPLACE FUNCTION safe_delete_custom_discipline(
  discipline_name_to_delete TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_custom integer := 0;
  deleted_plan_associations integer := 0;
  deleted_specializations integer := 0;
  result jsonb;
BEGIN
  -- Only allow admins to delete disciplines
  IF NOT is_admin_level() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Only admins can delete disciplines'
    );
  END IF;

  -- Step 0: Delete from discipline_subscription_plans_custom
  DELETE FROM public.discipline_subscription_plans_custom
  WHERE discipline_name = discipline_name_to_delete;
  GET DIAGNOSTICS deleted_plan_associations = ROW_COUNT;

  -- Step 1: Delete instructor specializations (text-based)
  DELETE FROM instructor_specializations
  WHERE specialization = discipline_name_to_delete;
  GET DIAGNOSTICS deleted_specializations = ROW_COUNT;

  -- Step 2: Remove from instructor_profiles disciplines array (text comparison)
  UPDATE instructor_profiles
  SET disciplines = array_remove(disciplines::text[], discipline_name_to_delete)::discipline_type[]
  WHERE discipline_name_to_delete = ANY(disciplines::text[]);

  -- Step 3: Delete from custom_disciplines table
  DELETE FROM public.custom_disciplines
  WHERE name = discipline_name_to_delete
     OR LOWER(name) = LOWER(discipline_name_to_delete);
  GET DIAGNOSTICS deleted_custom = ROW_COUNT;

  result := jsonb_build_object(
    'success', true,
    'discipline', discipline_name_to_delete,
    'deleted_custom_record', deleted_custom,
    'deleted_plan_associations', deleted_plan_associations,
    'deleted_specializations', deleted_specializations
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

GRANT EXECUTE ON FUNCTION safe_delete_custom_discipline(TEXT) TO authenticated;
COMMENT ON FUNCTION safe_delete_custom_discipline IS 'Safely deletes a custom (non-ENUM) discipline and all related data.';
