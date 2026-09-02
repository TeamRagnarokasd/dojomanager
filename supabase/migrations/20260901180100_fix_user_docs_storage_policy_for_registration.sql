-- ============================================================================
-- Allow newly registered users to upload their terms document to user_docs
-- storage bucket during registration.
--
-- After signUp(), Supabase creates a session for the new user. The existing
-- "users_manage_own_documents" policy already covers this case (authenticated
-- user uploading to their own folder). This migration is a safety net to
-- ensure the policy is correctly in place and not accidentally dropped.
-- ============================================================================

-- Ensure the storage policy for user_docs allows authenticated users to
-- upload to their own folder (idempotent: drop and recreate)
DROP POLICY IF EXISTS "users_manage_own_documents" ON storage.objects;

CREATE POLICY "users_manage_own_documents"
ON storage.objects
FOR ALL
TO authenticated
USING (
    bucket_id = 'user_docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'user_docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Also ensure admins can view all documents in user_docs
DROP POLICY IF EXISTS "admins_view_all_documents" ON storage.objects;

CREATE POLICY "admins_view_all_documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'user_docs'
    AND public.is_admin_from_auth()
);
