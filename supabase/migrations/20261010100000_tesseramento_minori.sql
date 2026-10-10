-- Allow federation memberships (user_federation_memberships) for minors
-- (child_profiles), not only adults (user_profiles). Idempotent.

-- 1. Add child_profile_id column (minors have no user_profiles row to point to).
ALTER TABLE public.user_federation_memberships
  ADD COLUMN IF NOT EXISTS child_profile_id uuid REFERENCES public.child_profiles(id) ON DELETE CASCADE;

-- 2. user_id is no longer required: a minor's row has child_profile_id instead.
ALTER TABLE public.user_federation_memberships
  ALTER COLUMN user_id DROP NOT NULL;

-- 3. Exactly one of user_id / child_profile_id must be set.
ALTER TABLE public.user_federation_memberships
  DROP CONSTRAINT IF EXISTS user_federation_memberships_one_owner_check;
ALTER TABLE public.user_federation_memberships
  ADD CONSTRAINT user_federation_memberships_one_owner_check
  CHECK (
    (user_id IS NOT NULL AND child_profile_id IS NULL)
    OR (user_id IS NULL AND child_profile_id IS NOT NULL)
  );

-- 4. One row per child per federation (mirrors the existing user_id/federation
-- unique constraint, which is untouched and keeps protecting adult rows).
ALTER TABLE public.user_federation_memberships
  DROP CONSTRAINT IF EXISTS user_federation_memberships_child_profile_id_federation_key;
ALTER TABLE public.user_federation_memberships
  ADD CONSTRAINT user_federation_memberships_child_profile_id_federation_key
  UNIQUE (child_profile_id, federation);

-- 5. Guardians can read (never modify) their own children's membership rows.
-- Admins already have full ALL access via admin_full_access_federation_memberships
-- (gated by is_admin_from_auth(), not by user_id/child_profile_id), so no change
-- is needed there for admins to read/write minors' cards. admin_sync_federation_roster
-- (the Excel bulk-import RPC) still matches only against user_profiles.codice_fiscale,
-- so it keeps working for adults exactly as before and is untouched by this migration.
DROP POLICY IF EXISTS guardians_read_child_federation_memberships ON public.user_federation_memberships;
CREATE POLICY guardians_read_child_federation_memberships
  ON public.user_federation_memberships
  FOR SELECT
  USING (
    child_profile_id IN (
      SELECT id FROM public.child_profiles WHERE guardian_id = auth.uid()
    )
  );
