-- Migration: Auto-delete auth.users when user_profiles is deleted
-- This ensures the email is freed for re-registration automatically,
-- without requiring Edge Function secrets or manual intervention.

-- Trigger function: deletes the corresponding auth.users row
CREATE OR REPLACE FUNCTION public.handle_user_profile_deleted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    -- Delete from auth.users to free the email for re-registration
    DELETE FROM auth.users WHERE id = OLD.id;
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        -- Log but don't block the profile deletion
        RAISE WARNING 'Could not delete auth.users row for id %: %', OLD.id, SQLERRM;
        RETURN OLD;
END;
$$;

-- Drop existing trigger if present (idempotent)
DROP TRIGGER IF EXISTS on_user_profile_deleted ON public.user_profiles;

-- Create trigger: fires AFTER DELETE on user_profiles
CREATE TRIGGER on_user_profile_deleted
    AFTER DELETE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_profile_deleted();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.handle_user_profile_deleted() TO authenticated;
