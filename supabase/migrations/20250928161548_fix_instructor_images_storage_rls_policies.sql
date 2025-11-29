-- Fix RLS policies for instructor-images storage bucket to allow instructors to upload their own images

-- RLS Policy: Allow instructors to view their own images
CREATE POLICY "instructors_view_own_images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    )
);

-- RLS Policy: Allow instructors to upload their own images
CREATE POLICY "instructors_upload_own_images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'instructor-images'
    AND owner = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    )
);

-- RLS Policy: Allow instructors to update their own images
CREATE POLICY "instructors_update_own_images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND owner = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    )
)
WITH CHECK (
    bucket_id = 'instructor-images'
    AND owner = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    )
);

-- RLS Policy: Allow instructors to delete their own images
CREATE POLICY "instructors_delete_own_images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND owner = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('instructor', 'instructor_admin', 'admin', 'principal_admin')
    )
);

-- RLS Policy: Allow admins to manage all instructor images
CREATE POLICY "admins_manage_all_instructor_images"
ON storage.objects
FOR ALL
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin')
    )
)
WITH CHECK (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'principal_admin')
    )
);