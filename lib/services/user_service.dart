import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import '../models/user_profile.dart';
import 'profile_update_notifier.dart';

class UserService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's profile data from database
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        return null;
      }

      final response = await _supabase
          .from('users')
          .select('id, full_name, email, phone, dob, veh_model, image_url, role, created_at')
          .eq('id', user.id)
          .maybeSingle(); // Use maybeSingle to handle case where user doesn't exist

      if (response == null) {
        // Create a default user record if it doesn't exist
        final success = await createUser(
          id: user.id,
          fullName: user.userMetadata?['full_name'] ?? 'User',
          email: user.email ?? '',
          phone: user.userMetadata?['phone'] ?? '',
          role: user.userMetadata?['role'] ?? 'user',
        );

        if (success) {
          final newResponse = await _supabase
              .from('users')
              .select('id, full_name, email, phone, dob, veh_model, image_url, role, created_at')
              .eq('id', user.id)
              .single();
          
          return UserProfile.fromJson(newResponse);
        } else {
          return null;
        }
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      // Keep basic error logging for debugging issues
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Update current user's profile data in database
  static Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        return false;
      }
      
      await _supabase
          .from('users')
          .update(profileData)
          .eq('id', user.id);
      
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  /// Upload profile image to Supabase storage and update database
  static Future<String?> uploadProfileImage(String filePath, Uint8List fileBytes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return null;
      }

      print('👤 User ID: ${user.id}');

      // Extract file extension from original file path, default to jpg if not found
      String fileExtension = 'jpg';
      if (filePath.contains('.')) {
        fileExtension = filePath.split('.').last.toLowerCase();
      }
      
      // Ensure valid image extensions
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        fileExtension = 'jpg';
      }

      final fileName = '${user.id}_profile.$fileExtension';
      
      print('📁 Uploading file: $fileName');
      print('📊 File size: ${fileBytes.length} bytes');

      // First, try to delete existing file to avoid conflicts
      try {
        await _supabase.storage
            .from('user-profile-images')
            .remove([fileName]);
        print('🗑️ Deleted existing file: $fileName');
      } catch (e) {
        print('ℹ️ No existing file to delete: $e');
      }

      // Upload to the bucket: user-profile-images
      print('⬆️ Starting upload...');
      final uploadResponse = await _supabase.storage
          .from('user-profile-images')
          .uploadBinary(
            fileName, 
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/$fileExtension',
            ),
          );

      print('✅ Upload response: $uploadResponse');

      // Get the public URL
      final publicUrl = _supabase.storage
          .from('user-profile-images')
          .getPublicUrl(fileName);

      print('🌐 Generated URL: $publicUrl');

      // Update the database with the new image_url
      print('💾 Updating database image_url column...');
      await _supabase
          .from('users')
          .update({'image_url': publicUrl})
          .eq('id', user.id);

      print('✅ Database updated successfully');
      
      // Clear cached image to force refresh
      try {
        await CachedNetworkImage.evictFromCache(publicUrl);
        print('🗑️ Cleared cached image');
      } catch (e) {
        print('⚠️ Could not clear cached image: $e');
      }
      
      // Notify all CurrentUserAvatar widgets to refresh
      try {
        ProfileUpdateNotifier().notifyProfileUpdated();
        print('📢 Profile update notification sent');
      } catch (e) {
        print('⚠️ Could not send profile update notification: $e');
      }
      
      // Verify the upload and database update
      try {
        final dbResponse = await _supabase
            .from('users')
            .select('image_url')
            .eq('id', user.id)
            .single();
        
        print('✅ Database verification: image_url = ${dbResponse['image_url']}');
        
      } catch (e) {
        print('❌ Database verification failed: $e');
      }
      
      return publicUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      if (e.toString().contains('403')) {
        print('🚫 Permission denied - check authentication and storage policies');
      } else if (e.toString().contains('409')) {
        print('⚠️ Conflict - file might already exist');
      }
      return null;
    }
  }

  /// Delete old profile image from storage
  static Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Instead of parsing URL, use the predictable filename format
      // Try common extensions
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];
      
      for (final ext in extensions) {
        try {
          final fileName = '${user.id}_profile.$ext';
          await _supabase.storage
              .from('user-profile-images')
              .remove([fileName]);
          print('Deleted old profile image: $fileName');
        } catch (e) {
          // Continue trying other extensions
        }
      }
      
      return true;
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  /// Check if user exists in database
  static Future<bool> userExists(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  /// Create new user record in database
  static Future<bool> createUser({
    required String id,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    String? imageUrl,
    String? vehicleModel,
    DateTime? dateOfBirth,
  }) async {
    try {
      final userData = {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
      };

      if (imageUrl != null) userData['image_url'] = imageUrl;
      if (vehicleModel != null) userData['veh_model'] = vehicleModel;
      if (dateOfBirth != null) userData['dob'] = dateOfBirth.toIso8601String().split('T')[0];

      await _supabase.from('users').insert(userData);
      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  /// Get user role
  static Future<String?> getUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'];
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Update user's vehicle models (array)
  static Future<bool> updateVehicleModel(List<String> vehicleModels) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('users')
          .update({'veh_model': vehicleModels})
          .eq('id', user.id);

      return true;
    } catch (e) {
      print('Error updating vehicle models: $e');
      return false;
    }
  }

  /// Get current user's profile picture URL
  static Future<String?> getCurrentUserProfilePicture() async {
    try {
      final user = _supabase.auth.currentUser;
      print('UserService: Current user: ${user?.id}');
      if (user == null) return null;

      final response = await _supabase
          .from('users')
          .select('image_url')
          .eq('id', user.id)
          .maybeSingle();

      print('UserService: Database response: $response');
      final imageUrl = response?['image_url'];
      print('UserService: Image URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Error fetching profile picture: $e');
      return null;
    }
  }

  /// Update current user's profile picture URL only
  static Future<bool> updateProfilePicture(String imageUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('users')
          .update({'image_url': imageUrl})
          .eq('id', user.id);

      return true;
    } catch (e) {
      print('Error updating profile picture: $e');
      return false;
    }
  }

  /// Test if a profile picture URL is accessible
  static Future<bool> testProfilePictureUrl(String url) async {
    try {
      // This is a simple test - in a real app you might want to make an HTTP request
      // For now, just check if it's a valid Supabase storage URL
      final isValid = url.contains('supabase.co') && 
                     url.contains('storage/v1/object/public/user-profile-images');
      print('URL validation result for $url: $isValid');
      return isValid;
    } catch (e) {
      print('Error testing profile picture URL: $e');
      return false;
    }
  }

  /// Test storage access and policies
  static Future<void> testStorageAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      print('🧪 Testing storage access for user: ${user?.id}');
      
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      // Test 1: Try to list files in the bucket
      try {
        final files = await _supabase.storage
            .from('user-profile-images')
            .list();
        print('✅ Can list files: ${files.length} files found');
        
        // Show all files in bucket for debugging
        for (final file in files) {
          print('  📄 ${file.name} (${file.metadata?['size']} bytes) - ${file.createdAt}');
        }
        
        // Look for user-specific files
        final userFiles = files.where((f) => f.name.contains(user.id)).toList();
        print('👤 User-specific files: ${userFiles.length}');
        for (final file in userFiles) {
          print('  🔹 ${file.name}');
        }
        
      } catch (e) {
        print('❌ Cannot list files: $e');
      }

      // Test 2: Try to get info about user's own file
      try {
        final fileName = '${user.id}_profile.jpg';
        final info = await _supabase.storage
            .from('user-profile-images')
            .info(fileName);
        print('✅ Can access own file info: $info');
      } catch (e) {
        print('❌ Cannot access own file: $e');
      }

      // Test 3: Check bucket configuration
      print('🔧 Testing URL generation:');
      final testUrl = _supabase.storage
          .from('user-profile-images')
          .getPublicUrl('${user.id}_profile.jpg');
      print('🌐 Generated URL format: $testUrl');

      // Test 4: Try to download existing file
      try {
        final fileName = '${user.id}_profile.jpg';
        final data = await _supabase.storage
            .from('user-profile-images')
            .download(fileName);
        print('✅ Can download own file: ${data.length} bytes');
      } catch (e) {
        print('❌ Cannot download own file: $e');
      }

    } catch (e) {
      print('❌ Storage access test failed: $e');
    }
  }

  /// Clean up problematic files for current user
  static Future<void> cleanupUserProfileImages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      print('🧹 Cleaning up profile images for user: ${user.id}');

      // List all files for this user
      final files = await _supabase.storage
          .from('user-profile-images')
          .list();

      final userFiles = files.where((f) => f.name.contains(user.id)).toList();
      print('Found ${userFiles.length} files to clean up');

      // Remove all user files
      final fileNames = userFiles.map((f) => f.name).toList();
      if (fileNames.isNotEmpty) {
        await _supabase.storage
            .from('user-profile-images')
            .remove(fileNames);
        print('✅ Removed ${fileNames.length} files: $fileNames');
      } else {
        print('ℹ️ No files to remove');
      }

    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }
}
