# Profile Picture Implementation Guide

## Overview
This guide explains how the profile picture functionality works in the MechaFind app and how to use it throughout the application.

## Database Schema
Profile pictures are stored in the `profile_pic` column of the `users` table:
```sql
profile_pic text null,
```

## Storage
Images are stored in the Supabase storage bucket: `user-profile-images`

## Key Components

### 1. UserService Methods
```dart
// Get current user's profile picture URL
await UserService.getCurrentUserProfilePicture();

// Update profile picture URL
await UserService.updateProfilePicture(imageUrl);

// Upload new profile image
await UserService.uploadProfileImage(filePath, bytes);

// Delete old profile image
await UserService.deleteProfileImage(imageUrl);
```

### 2. Profile Avatar Widgets

#### ProfileAvatar - For Static Display
```dart
ProfileAvatar(
  radius: 20,
  profilePicUrl: 'https://...', // Direct URL
  showBorder: true,
  borderColor: Colors.blue,
  onTap: () {
    // Handle tap
  },
)
```

#### CurrentUserAvatar - For Logged-in User
```dart
CurrentUserAvatar(
  radius: 20,
  showBorder: true,
  borderColor: Colors.blue,
  onTap: () {
    // Navigate to profile settings
    Navigator.pushNamed(context, '/settings');
  },
)
```

## Usage Examples

### 1. In App Bar (Home Screen)
```dart
AppBar(
  title: Text('Welcome User'),
  actions: [
    Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: CurrentUserAvatar(
        radius: 18,
        showBorder: true,
        borderColor: Colors.white,
        onTap: () => Navigator.pushNamed(context, '/settings'),
      ),
    ),
  ],
)
```

### 2. In Bottom Navigation Bar
The profile tab automatically shows the user's profile picture instead of an icon.

### 3. In Chat/Messages
```dart
ListTile(
  leading: ProfileAvatar(
    radius: 20,
    profilePicUrl: message.senderProfilePic,
  ),
  title: Text(message.senderName),
  subtitle: Text(message.content),
)
```

### 4. In Drawer/Side Menu
```dart
DrawerHeader(
  child: Column(
    children: [
      CurrentUserAvatar(
        radius: 40,
        showBorder: true,
      ),
      SizedBox(height: 10),
      Text(userName),
    ],
  ),
)
```

### 5. In Cards/Lists
```dart
Card(
  child: ListTile(
    leading: CurrentUserAvatar(radius: 25),
    title: Text('Your Profile'),
    subtitle: Text('Manage your account'),
    trailing: Icon(Icons.arrow_forward_ios),
    onTap: () => Navigator.pushNamed(context, '/settings'),
  ),
)
```

## Implementation Features

### ✅ Automatic Loading
- `CurrentUserAvatar` automatically fetches the latest profile picture
- Shows loading indicator while fetching
- Falls back to default person icon if no image

### ✅ Caching
- Uses `CachedNetworkImage` for efficient image loading
- Reduces bandwidth usage
- Improves performance

### ✅ Error Handling
- Gracefully handles network errors
- Shows default icon if image fails to load
- Provides user feedback during upload

### ✅ Image Optimization
- Compresses images to 800x800px
- Reduces file size with 85% quality
- Supports multiple formats (jpg, png, etc.)

### ✅ Security
- Users can only upload/modify their own profile pictures
- Proper RLS policies in Supabase
- Secure file naming prevents conflicts

## File Structure
```
lib/
├── services/
│   └── user_service.dart          # Profile picture upload/download methods
├── models/
│   └── user_profile.dart          # User model with profile_pic field
├── widgets/
│   └── profile_avatar.dart        # Reusable avatar widgets
├── screens/
│   └── settings/
│       └── settings_profile_screen.dart  # Profile picture upload UI
└── user_home.dart                 # Example usage in app bar
```

## Testing Checklist
- [ ] Upload profile picture from settings
- [ ] Picture appears in app bar
- [ ] Picture appears in bottom navigation
- [ ] Picture loads correctly after app restart
- [ ] Error handling works for failed uploads
- [ ] Old images are cleaned up when new ones are uploaded
- [ ] Pictures work on both Android and iOS

## Troubleshooting

### Profile Picture Not Uploading
1. Check Supabase storage policies
2. Verify bucket name is `user-profile-images`
3. Check network connection
4. Ensure user is authenticated

### Profile Picture Not Displaying
1. Check if `profile_pic` field has valid URL
2. Verify Supabase bucket is public
3. Check for CORS issues
4. Ensure image URL is accessible

### Performance Issues
1. Check image sizes (should be optimized to 800x800)
2. Verify caching is working
3. Monitor network requests in dev tools
