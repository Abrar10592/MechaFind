-- Alternative: Simple fix - Disable RLS for user-profile-images bucket
-- This completely disables row-level security for the user profile images
-- Use this if the above policies don't work

-- Method 1: Remove RLS entirely for this bucket
CREATE OR REPLACE FUNCTION disable_rls_for_user_profiles()
RETURNS void AS $$
BEGIN
  -- Create bucket if it doesn't exist
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('user-profile-images', 'user-profile-images', true)
  ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

  -- Remove all existing policies for this bucket
  DELETE FROM storage.policies 
  WHERE bucket_id = 'user-profile-images';

  -- Drop all policies from pg_policies for this bucket
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
  DROP POLICY IF EXISTS "Allow authenticated updates to user-profile-images" ON storage.objects;

  -- Create a single permissive policy that allows everything
  EXECUTE format('
    CREATE POLICY "Full access to user-profile-images"
    ON storage.objects
    FOR ALL
    TO public
    USING (bucket_id = %L)
    WITH CHECK (bucket_id = %L)',
    'user-profile-images', 'user-profile-images'
  );

END;
$$ LANGUAGE plpgsql;

-- Execute the function
SELECT disable_rls_for_user_profiles();

-- Clean up the function
DROP FUNCTION disable_rls_for_user_profiles();

-- Verify the setup
SELECT 
  'Bucket exists: ' || CASE WHEN EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'user-profile-images') THEN 'YES' ELSE 'NO' END as bucket_status,
  'Bucket is public: ' || COALESCE((SELECT public::text FROM storage.buckets WHERE id = 'user-profile-images'), 'UNKNOWN') as public_status;

-- Show active policies
SELECT policyname, cmd, permissive
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND policyname LIKE '%user-profile-images%'
ORDER BY policyname;
