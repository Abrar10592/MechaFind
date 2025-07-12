import '../models/mechanic.dart';

class MechanicService {
  static Mechanic convertToMechanic(Map<String, dynamic> data) {
    return Mechanic(
      id: data['id'] ?? '${data['name']}_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      distance: (data['distance'] as String? ?? '0').replaceAll(' km', '').replaceAll(',', '').isNotEmpty
          ? double.tryParse((data['distance'] as String).replaceAll(' km', '')) ?? 0.0
          : 0.0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviews: data['reviews'] ?? 0,
      responseTime: data['response'] ?? '',
      services: List<String>.from(data['services'] ?? []),
      isOnline: data['online'] ?? false,
      phoneNumber: data['phoneNumber'] ?? '+1234567890',
      profileImage: data['profileImage'] ?? '',
      description: data['description'] ?? 'Professional mechanic with years of experience.',
      certifications: data['certifications'] ?? ['ASE Certified', 'Factory Trained'],
      experience: data['experience'] ?? '5+ years of experience',
      hourlyRate: (data['hourlyRate'] ?? 75.0).toDouble(),
      location: Location(
        latitude: data['latitude'] ?? 37.7749,
        longitude: data['longitude'] ?? -122.4194,
      ),
    );
  }

  static List<Mechanic> getMockMechanics() {
    return [
      Mechanic(
        id: 'mech_1',
        name: 'AutoCare Plus',
        address: '123 Main St, Downtown',
        distance: 0.8,
        rating: 4.9,
        reviews: 156,
        responseTime: '5 min',
        services: ['Engine Repair', 'Brake Service', 'Oil Change'],
        isOnline: true,
        phoneNumber: '+1234567890',
        profileImage: '',
        description: 'Professional auto repair shop with certified technicians and state-of-the-art equipment. We specialize in all types of automotive repairs and maintenance.',
        certifications: ['ASE Certified', 'Factory Trained', 'AAA Approved'],
        experience: '15+ years of experience',
        hourlyRate: 85.0,
        location: Location(latitude: 37.7749, longitude: -122.4194),
      ),
      Mechanic(
        id: 'mech_2',
        name: 'QuickFix Motors',
        address: '456 Oak Ave, Midtown',
        distance: 1.2,
        rating: 4.7,
        reviews: 89,
        responseTime: '8 min',
        services: ['Towing', 'Jump Start', 'Tire Change'],
        isOnline: true,
        phoneNumber: '+1234567891',
        profileImage: '',
        description: 'Mobile mechanic service offering quick fixes and emergency roadside assistance. Available 24/7 for all your automotive needs.',
        certifications: ['ASE Certified', 'Mobile Service Certified'],
        experience: '10+ years of experience',
        hourlyRate: 75.0,
        location: Location(latitude: 37.7849, longitude: -122.4094),
      ),
      Mechanic(
        id: 'mech_3',
        name: 'Elite Auto Workshop',
        address: '789 Pine Rd, Uptown',
        distance: 2.1,
        rating: 4.8,
        reviews: 234,
        responseTime: '12 min',
        services: ['Transmission', 'AC Repair', 'Electrical'],
        isOnline: false,
        phoneNumber: '+1234567892',
        profileImage: '',
        description: 'Premium automotive service center specializing in luxury and high-performance vehicles. Expert diagnostics and repairs.',
        certifications: ['ASE Master Certified', 'BMW Certified', 'Mercedes Certified'],
        experience: '20+ years of experience',
        hourlyRate: 120.0,
        location: Location(latitude: 37.7949, longitude: -122.3994),
      ),
    ];
  }
}
