-- Fix medical-certificates storage RLS policy to use path-based access
-- The previous policy used 'owner = auth.uid()' which doesn't work reliably
-- New policy uses path-based access: userId/filename

-- Drop existing policies for medical-certificates bucket
DROP POLICY IF EXISTS "users_manage_own_medical_certificates" ON storage.objects;

-- Create new path-based RLS policy for medical certificates
-- Files are stored as: {userId}/{filename}
CREATE POLICY "users_upload_own_medical_certificates" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'medical-certificates' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "users_read_own_medical_certificates" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'medical-certificates' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "users_update_own_medical_certificates" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'medical-certificates' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'medical-certificates' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "users_delete_own_medical_certificates" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'medical-certificates' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow admins to read all medical certificates for verification
CREATE POLICY "admins_read_all_medical_certificates" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'medical-certificates' AND
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid()
    AND role IN ('principal_admin', 'admin')
  )
);
