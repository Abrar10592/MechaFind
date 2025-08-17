-- Simple storage policies for testing - Updated for new image_url column
-- This allows all authenticated users to do everything with profile images
-- Use this for testing, then tighten security later

-- Make sure the bucket is public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'user-profile-images';

-- Remove all existing policies
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public access to profile images" ON storage.objects;

-- Create simple policies for testing
CREATE POLICY "Authenticated users can upload profile images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'user-profile-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Authenticated users can view profile images"
ON storage.objects FOR SELECT
USING (bucket_id = 'user-profile-images');

CREATE POLICY "Authenticated users can delete profile images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'user-profile-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Authenticated users can update profile images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'user-profile-images' 
  AND auth.role() = 'authenticated'
);

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Verify policies
SELECT policyname, cmd, permissive
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
ORDER BY policyname;
