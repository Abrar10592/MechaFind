-- EMERGENCY FIX for user profile image upload error
-- This version avoids ownership errors

-- Step 1: Create/update bucket (this should work)
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

-- Step 2: Remove existing policies (if any)
drop policy if exists "profile_images_policy_insert" on storage.objects;
drop policy if exists "profile_images_policy_select" on storage.objects; 
drop policy if exists "profile_images_policy_update" on storage.objects;
drop policy if exists "profile_images_policy_delete" on storage.objects;

-- Step 3: Create new simple policies
create policy "profile_images_policy_insert"
on storage.objects for insert 
with check (bucket_id = 'user-profile-images');

create policy "profile_images_policy_select"
on storage.objects for select 
using (bucket_id = 'user-profile-images');

create policy "profile_images_policy_update"
on storage.objects for update 
using (bucket_id = 'user-profile-images');

create policy "profile_images_policy_delete"
on storage.objects for delete 
using (bucket_id = 'user-profile-images');