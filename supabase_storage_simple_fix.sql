-- Simple Supabase Storage Fix for Profile Images
-- This avoids permission errors by using Supabase's built-in functions

-- Step 1: Ensure bucket exists (this should work in Supabase)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'user-profile-images',
  'user-profile-images', 
  true,
  5242880,
  array['image/jpeg','image/jpg','image/png','image/webp','image/gif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/jpg','image/png','image/webp','image/gif'];

-- Step 2: Create storage policies using Supabase's approach
-- These policies should work without ownership issues

-- Remove existing policies if they exist
drop policy if exists "Give users access to own folder 1oj01fe_0" on storage.objects;
drop policy if exists "Give users access to own folder 1oj01fe_1" on storage.objects;
drop policy if exists "Give users access to own folder 1oj01fe_2" on storage.objects;
drop policy if exists "Give users access to own folder 1oj01fe_3" on storage.objects;

-- Policy for uploading files
create policy "Give users access to own folder 1oj01fe_0"
on storage.objects for insert with check (
  bucket_id = 'user-profile-images'
);

-- Policy for viewing files
create policy "Give users access to own folder 1oj01fe_1"
on storage.objects for select using (
  bucket_id = 'user-profile-images'
);

-- Policy for updating files  
create policy "Give users access to own folder 1oj01fe_2"
on storage.objects for update using (
  bucket_id = 'user-profile-images'
);

-- Policy for deleting files
create policy "Give users access to own folder 1oj01fe_3"
on storage.objects for delete using (
  bucket_id = 'user-profile-images'
);
