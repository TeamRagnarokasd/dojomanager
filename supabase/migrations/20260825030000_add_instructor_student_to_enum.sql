-- Migration: Add 'instructor_student' value to user_role enum
-- Fix: previous migration updated functions but did not add the enum value,
-- causing PostgreSQL error "invalid input value for enum user_role: instructor_student"

DO $$
BEGIN
  -- Add instructor_student to the enum only if it doesn't already exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'instructor_student'
      AND enumtypid = (
        SELECT oid FROM pg_type
        WHERE typname = 'user_role'
          AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      )
  ) THEN
    ALTER TYPE public.user_role ADD VALUE 'instructor_student';
  END IF;
END $$;
