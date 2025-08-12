import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/user_profile.dart';

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

  /// Upload profile image to Supabase storage
  static Future<String?> uploadProfileImage(String filePath, Uint8List fileBytes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'profiles/${user.id}/$fileName';

      await _supabase.storage
          .from('request-photos')
          .uploadBinary(storagePath, fileBytes);

      final publicUrl = _supabase.storage
          .from('request-photos')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
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
}
