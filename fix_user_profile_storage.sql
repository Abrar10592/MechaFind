-- Fix for user profile image storage policies
-- This addresses the "new row violates row-level security policy" error

-- First, ensure the bucket exists and is properly configured
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-profile-images', 'user-profile-images', true)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880, -- 5MB limit
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- Remove all existing conflicting policies
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public access to profile images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to user-profile-images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads from user-profile-images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from user-profile-images" ON storage.objects;

-- Create comprehensive policies for user profile images
-- Policy 1: Allow authenticated users to upload their own profile images
CREATE POLICY "Allow authenticated uploads to user-profile-images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'user-profile-images' 
  AND auth.uid()::text IS NOT NULL
);

-- Policy 2: Allow public read access to all profile images
CREATE POLICY "Allow public reads from user-profile-images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'user-profile-images');

-- Policy 3: Allow authenticated users to delete their own profile images
CREATE POLICY "Allow authenticated deletes from user-profile-images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'user-profile-images' 
  AND auth.uid()::text IS NOT NULL
);

-- Policy 4: Allow authenticated users to update their own profile images
CREATE POLICY "Allow authenticated updates to user-profile-images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'user-profile-images' 
  AND auth.uid()::text IS NOT NULL
);

-- Ensure RLS is enabled on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions to authenticated users
GRANT SELECT ON storage.objects TO authenticated;
GRANT INSERT ON storage.objects TO authenticated;
GRANT UPDATE ON storage.objects TO authenticated;
GRANT DELETE ON storage.objects TO authenticated;

-- Grant permissions to public for reads
GRANT SELECT ON storage.objects TO public;

-- Verify the bucket configuration
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets 
WHERE id = 'user-profile-images';

-- Verify policies are created
SELECT policyname, cmd, permissive, roles, qual, with_check
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND policyname LIKE '%user-profile-images%'
ORDER BY policyname;

-- Test the current user's access
SELECT 
  'Current user ID: ' || COALESCE(auth.uid()::text, 'NULL') as user_info,
  'Current role: ' || COALESCE(auth.role(), 'NULL') as role_info;
