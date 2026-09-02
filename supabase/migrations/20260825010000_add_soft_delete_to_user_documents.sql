-- Add soft-delete support to user_documents table
-- When a user deletes a document, it is hidden from their view but remains visible to admins
-- Only admins can permanently delete documents

ALTER TABLE public.user_documents
ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_by_user_at TIMESTAMPTZ;

-- Index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_user_documents_deleted_by_user 
ON public.user_documents(user_id, deleted_by_user);

-- Update RLS: users can only see documents not deleted by them
-- Admins (via service role or admin queries) can see all documents

-- Allow users to soft-delete their own documents (UPDATE deleted_by_user = true)
DROP POLICY IF EXISTS "users_can_soft_delete_own_documents" ON public.user_documents;
CREATE POLICY "users_can_soft_delete_own_documents"
ON public.user_documents
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
