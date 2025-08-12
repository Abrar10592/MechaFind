class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String? imageUrl;
  final DateTime? dateOfBirth;
  final List<String> vehicleModels;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.imageUrl,
    this.dateOfBirth,
    this.vehicleModels = const [],
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> vehicles = [];
    if (json['veh_model'] != null) {
      if (json['veh_model'] is List) {
        vehicles = List<String>.from(json['veh_model']);
      } else if (json['veh_model'] is String) {
        // Handle legacy single string format
        String singleVehicle = json['veh_model'];
        if (singleVehicle.isNotEmpty) {
          vehicles = [singleVehicle];
        }
      }
    }

    return UserProfile(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      imageUrl: json['image_url'],
      dateOfBirth: json['dob'] != null ? DateTime.parse(json['dob']) : null,
      vehicleModels: vehicles,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'image_url': imageUrl,
      'dob': dateOfBirth?.toIso8601String().split('T')[0],
      'veh_model': vehicleModels,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Method to convert to database update format
  Map<String, dynamic> toUpdateJson() {
    Map<String, dynamic> data = {
      'full_name': fullName,
      'phone': phone,
      'veh_model': vehicleModels,
    };

    if (imageUrl != null) data['image_url'] = imageUrl;
    if (dateOfBirth != null) data['dob'] = dateOfBirth!.toIso8601String().split('T')[0];

    return data;
  }
}
