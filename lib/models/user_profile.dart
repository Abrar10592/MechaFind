class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImage;
  final String address;
  final DateTime dateOfBirth;
  final String emergencyContact;
  final List<String> vehicleModels;
  final Map<String, dynamic> preferences;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.profileImage = '',
    this.address = '',
    required this.dateOfBirth,
    this.emergencyContact = '',
    this.vehicleModels = const [],
    this.preferences = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      profileImage: json['profileImage'] ?? '',
      address: json['address'] ?? '',
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      emergencyContact: json['emergencyContact'] ?? '',
      vehicleModels: List<String>.from(json['vehicleModels'] ?? []),
      preferences: json['preferences'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'address': address,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'emergencyContact': emergencyContact,
      'vehicleModels': vehicleModels,
      'preferences': preferences,
    };
  }
}
