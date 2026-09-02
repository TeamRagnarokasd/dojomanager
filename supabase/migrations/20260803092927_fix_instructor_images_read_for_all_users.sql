-- Fix: Allow ALL authenticated users to view instructor images
-- Previously only instructors/admins could read images, regular users (students) were blocked

-- Drop the restrictive view policy that only allowed instructors/admins to read
DROP POLICY IF EXISTS "instructors_view_own_images" ON storage.objects;

-- Create a new policy that allows ALL authenticated users to view instructor images
CREATE POLICY "authenticated_users_view_instructor_images"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'instructor-images');
