-- Test query to verify your mechanics are being fetched
-- Run this in your Supabase SQL editor to see what the app will fetch

SELECT 
  u.id,
  u.full_name,
  u.phone,
  u.email,
  u.image_url,
  u.role,
  m.rating,
  m.location_x,
  m.location_y,
  m.fcm_token
FROM users u
LEFT JOIN mechanics m ON u.id = m.id
WHERE u.role = 'mechanic';

-- This should return your 3 mechanics
-- If a mechanic doesn't have a row in the mechanics table, 
-- the m.* columns will be NULL (which is fine - the app handles this)
