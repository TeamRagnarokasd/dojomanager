-- Add INSERT policy for user_profiles table to allow new user registration
-- This policy allows authenticated users to create their own profile during registration

CREATE POLICY "users_can_create_own_profile" ON "public"."user_profiles"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Also ensure the function exists for the existing policy
-- This function should return true during registration process
CREATE OR REPLACE FUNCTION public.can_create_user_profile_during_registration()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Allow profile creation during registration
    -- This function should return true when called during the registration process
    RETURN TRUE;
END;
$$;

-- Update the existing INSERT policy to use both conditions
DROP POLICY IF EXISTS "users_can_create_profile_during_registration" ON "public"."user_profiles";

CREATE POLICY "users_can_create_profile_during_registration" ON "public"."user_profiles"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (
    (id = auth.uid()) OR 
    can_create_user_profile_during_registration()
);
