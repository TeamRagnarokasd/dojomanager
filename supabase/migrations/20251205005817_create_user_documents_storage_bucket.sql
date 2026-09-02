-- Create private bucket for user documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user_docs',
    'user_docs', 
    false,  -- PRIVATE
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
);

-- RLS: Users manage only their own documents
CREATE POLICY "users_manage_own_documents" ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'user_docs' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'user_docs' AND (storage.foldername(name))[1] = auth.uid()::text);

-- RLS: Admins can view all documents
CREATE POLICY "admins_view_all_documents" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'user_docs' AND 
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'instructor_admin', 'principal_admin')
    )
);