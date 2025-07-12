class Mechanic {
  final String id;
  final String name;
  final String address;
  final double distance;
  final double rating;
  final int reviews;
  final String responseTime;
  final List<String> services;
  final bool isOnline;
  final String phoneNumber;
  final String profileImage;
  final String description;
  final List<String> certifications;
  final String experience;
  final double hourlyRate;
  final Location location;

  Mechanic({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    required this.reviews,
    required this.responseTime,
    required this.services,
    required this.isOnline,
    required this.phoneNumber,
    required this.profileImage,
    required this.description,
    required this.certifications,
    required this.experience,
    required this.hourlyRate,
    required this.location,
  });

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    return Mechanic(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      distance: json['distance'].toDouble(),
      rating: json['rating'].toDouble(),
      reviews: json['reviews'],
      responseTime: json['responseTime'],
      services: List<String>.from(json['services']),
      isOnline: json['isOnline'],
      phoneNumber: json['phoneNumber'],
      profileImage: json['profileImage'],
      description: json['description'],
      certifications: List<String>.from(json['certifications']),
      experience: json['experience'],
      hourlyRate: json['hourlyRate'].toDouble(),
      location: Location.fromJson(json['location']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'distance': distance,
      'rating': rating,
      'reviews': reviews,
      'responseTime': responseTime,
      'services': services,
      'isOnline': isOnline,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'description': description,
      'certifications': certifications,
      'experience': experience,
      'hourlyRate': hourlyRate,
      'location': location.toJson(),
    };
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
