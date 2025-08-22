# Find Mechanics UI - Real Database Integration

This implementation replaces the dummy data in the Find Mechanics UI with real database data from your Supabase tables. **It now shows ALL registered mechanics** in your app, not just those within a specific radius.

## ✅ What's Implemented

### 1. **All Registered Mechanics Display**
- ✅ Fetches ALL users with `role = 'mechanic'` from the `users` table
- ✅ Shows mechanics regardless of location (no radius filtering)
- ✅ Calculates distances when user location is available (optional)
- ✅ Shows real ratings from `reviews` table
- ✅ Displays services from `mechanic_services` table
- ✅ Online status based on recent activity
- ✅ Works with or without location permissions

### 2. **Functional Buttons**
- ✅ **Call Button**: Opens phone dialer with mechanic's phone number
- ✅ **Chat Button**: Opens functional chat screen with real-time messaging
- ✅ **Profile Button**: Shows detailed mechanic profile with tabs

### 3. **Enhanced UI**
- ✅ Loading states while fetching data
- ✅ Error handling for network issues
- ✅ Search functionality by mechanic name
- ✅ Refresh capability
- ✅ Empty state handling
- ✅ **No location permission required** (optional for distance calculation)

### 4. **Database Tables Used**
- ✅ `users` - Fetches users with `role = 'mechanic'`
- ✅ `mechanics` - Rating, location, FCM token (optional, creates row in mechanics table)
- ✅ `messages` - Chat functionality
- ✅ `services` - Available services
- ✅ `mechanic_services` - Mechanic-service relationships
- ✅ `reviews` - Customer reviews

## 🗄️ Database Setup Required

### 1. Run the Services Setup SQL
Execute `setup_mechanic_services.sql` in your Supabase SQL editor to create the required tables and policies.

### 2. Ensure Your Tables Match the Schema

#### Users Table (should already exist):
```sql
create table public.users (
  id uuid not null,
  full_name text not null,
  phone text not null,
  role text not null default 'user'::text,
  created_at timestamp with time zone null default now(),
  image_url text null,
  email character varying not null,
  dob date null,
  veh_model text[] null,
  constraint users_pkey primary key (id)
);
```

#### Mechanics Table (should already exist):
```sql
create table public.mechanics (
  id uuid not null,
  rating double precision null default 0,
  image_url text null,
  location_x double precision null,
  location_y double precision null,
  fcm_token text null,
  constraint mechanics_pkey primary key (id),
  constraint mechanics_id_fkey foreign KEY (id) references users (id) on delete CASCADE
);
```

#### Messages Table (should already exist):
```sql
create table public.messages (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  sender_id uuid null,
  receiver_id uuid null,
  content text not null,
  is_read boolean not null default false,
  constraint messages_pkey primary key (id),
  constraint messages_receiver_id_fkey foreign KEY (receiver_id) references users (id),
  constraint messages_sender_id_fkey foreign KEY (sender_id) references users (id)
);
```

### 3. Sample Data

To test the implementation, you can insert some sample mechanic data:

```sql
-- Insert a sample mechanic user
INSERT INTO users (id, full_name, phone, email, role) VALUES 
  ('12345678-1234-1234-1234-123456789012', 'John Doe Mechanics', '+1234567890', 'john@mechanic.com', 'mechanic');

-- Insert mechanic details
INSERT INTO mechanics (id, rating, location_x, location_y) VALUES 
  ('12345678-1234-1234-1234-123456789012', 4.5, 37.7749, -122.4194);

-- Link mechanic to services
INSERT INTO mechanic_services (mechanic_id, service_id) 
SELECT '12345678-1234-1234-1234-123456789012', id FROM services WHERE name IN ('Engine Repair', 'Oil Change', 'Brake Service');
```

## 📱 Features

### Find Mechanics Screen
1. **Shows All Mechanics**: Displays all users with `role = 'mechanic'`
2. **Optional Location**: Gets user's location if available (not required)
3. **Distance Calculation**: Shows actual distance when possible
4. **Search**: Search mechanics by name
5. **Refresh**: Pull-to-refresh or tap refresh button
6. **No Permission Required**: Works without location permissions

### Mechanic Card
1. **Profile Picture**: Shows mechanic's profile image or default avatar
2. **Rating & Reviews**: Real data from reviews table
3. **Services**: Dynamic service chips from database
4. **Online Status**: Based on recent activity
5. **Distance**: Shows "Unknown" if location not available (this is OK)
5. **Response Time**: Calculated based on distance

### Functional Buttons
1. **Call**: 
   - Opens phone dialer
   - Uses mechanic's real phone number
   - Error handling if no number available

2. **Chat**: 
   - Opens real-time chat screen
   - Persistent message history
   - Read/unread status
   - Real-time notifications

3. **Profile**: 
   - Detailed mechanic information
   - Tabbed interface (Info, Services, Reviews, Photos)
   - Hero transitions

## 🔧 How It Works

### Data Flow
1. User opens Find Mechanics screen
2. App queries all users with `role = 'mechanic'` from users table
3. Tries to get current GPS coordinates (optional - continues without it)
4. Fetches mechanic details from mechanics table (if exists)
5. Calculates distances if location is available
6. Fetches services, reviews, and online status for each mechanic
7. Displays all mechanics, sorted by distance (if available) or alphabetically

### Real-time Features
- Chat messages appear instantly
- Online status updates
- All registered mechanics shown regardless of location

## 🚀 Next Steps

1. **Run the SQL setup**: Execute `setup_mechanic_services.sql`
2. **Verify your mechanics**: Ensure users table has entries with `role = 'mechanic'`
3. **Test the app**: Should now show all 3 registered mechanics
4. **Optional**: Add location data to mechanics table for distance calculation
5. **Test chat**: Send messages between user and mechanic accounts

## 🐛 Troubleshooting

### No Mechanics Found
1. Check if users table has entries with `role = 'mechanic'`
2. Verify the 3 mechanics you mentioned are in the users table
3. Check database connection and RLS policies
4. Check app logs for any database query errors

### Distance Shows "Unknown"
1. Mechanic doesn't have location_x, location_y values in mechanics table
2. User location could not be obtained (this is OK, app still works)
3. This is normal for mechanics without location data

### Chat Not Working
1. Ensure messages table exists with proper RLS policies
2. Check that both users exist in users table
3. Verify Supabase real-time is enabled

### Location Issues
1. Grant location permissions in device settings
2. Enable GPS/location services
3. Test on physical device (not simulator)

### Call Button Not Working
1. Test on physical device (simulators may not support phone calls)
2. Check mechanic has valid phone number
3. Ensure url_launcher package is properly configured

## 📋 Files Modified

- ✅ `lib/find_mechanics.dart` - Main screen with real data integration
- ✅ `lib/detailed_mechanic_card.dart` - Enhanced card with functional buttons
- ✅ `lib/services/find_mechanic_service.dart` - New service for data fetching
- ✅ `lib/services/mechanic_service.dart` - Updated data conversion
- ✅ `setup_mechanic_services.sql` - Database setup script

The chat screen (`lib/screens/chat/chat_screen.dart`) and profile page (`lib/screens/profile/mechanic_profile_page.dart`) were already implemented and functional.
