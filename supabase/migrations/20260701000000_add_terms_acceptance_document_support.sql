-- Add document_type and document_label columns to user_documents for categorization
ALTER TABLE public.user_documents
ADD COLUMN IF NOT EXISTS document_type TEXT DEFAULT 'user_upload',
ADD COLUMN IF NOT EXISTS document_label TEXT;

-- Add index for document_type queries
CREATE INDEX IF NOT EXISTS idx_user_documents_type ON public.user_documents(document_type);

-- Update storage bucket to allow PDF mime type (already allowed, but ensure terms docs can be stored)
-- The user_docs bucket already exists and supports PDF uploads

-- Allow service role to upload documents on behalf of users (for terms acceptance during registration)
-- The existing RLS policies already allow authenticated users to manage their own documents
-- We need to also allow the service role (used during registration flow) to insert documents

-- Drop and recreate the user_documents RLS policies to ensure service role can insert
-- (service role bypasses RLS by default in Supabase, so no changes needed to DB policies)

-- Ensure the user_documents table has RLS enabled (it should already)
ALTER TABLE public.user_documents ENABLE ROW LEVEL SECURITY;

-- Ensure admins can view all user documents (for admin profile view)
DROP POLICY IF EXISTS "admins_view_all_user_documents" ON public.user_documents;
CREATE POLICY "admins_view_all_user_documents"
ON public.user_documents
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid()
    AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
  )
);

-- Ensure users can view their own documents
DROP POLICY IF EXISTS "users_view_own_documents" ON public.user_documents;
CREATE POLICY "users_view_own_documents"
ON public.user_documents
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Allow authenticated users to insert their own documents
DROP POLICY IF EXISTS "users_insert_own_documents" ON public.user_documents;
CREATE POLICY "users_insert_own_documents"
ON public.user_documents
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Allow authenticated users to delete their own documents
DROP POLICY IF EXISTS "users_delete_own_documents" ON public.user_documents;
CREATE POLICY "users_delete_own_documents"
ON public.user_documents
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Storage: Allow service role to upload to user_docs bucket on behalf of any user
-- (service role bypasses RLS automatically, so no additional storage policy needed)
-- But we need to allow the newly registered user (who just signed up) to upload their own terms doc
-- The existing "users_manage_own_documents" storage policy already handles this since
-- the user is authenticated at the time of upload (before signOut)
