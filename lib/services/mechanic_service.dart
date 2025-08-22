import '../models/mechanic.dart';

class MechanicService {
  static Mechanic convertToMechanic(Map<String, dynamic> data) {
    return Mechanic(
      id: data['id']?.toString() ?? '${data['name']}_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      distance: _parseDistance(data['distance']),
      rating: _parseDouble(data['rating']),
      reviews: _parseInt(data['reviews']),
      responseTime: data['response']?.toString() ?? data['responseTime']?.toString() ?? '',
      services: _parseServices(data['services']),
      isOnline: data['online'] ?? data['isOnline'] ?? false,
      phoneNumber: data['phone']?.toString() ?? data['phoneNumber']?.toString() ?? '+1234567890',
      profileImage: data['image_url']?.toString() ?? data['profileImage']?.toString() ?? '',
      description: data['description']?.toString() ?? 'Professional mechanic with years of experience.',
      certifications: _parseCertifications(data['certifications']),
      experience: data['experience']?.toString() ?? '5+ years of experience',
      hourlyRate: _parseDouble(data['hourlyRate'] ?? 75.0),
      location: Location(
        latitude: _parseDouble(data['latitude'] ?? data['location_x'] ?? 37.7749),
        longitude: _parseDouble(data['longitude'] ?? data['location_y'] ?? -122.4194),
      ),
    );
  }

  static double _parseDistance(dynamic distance) {
    if (distance is double) return distance;
    if (distance is int) return distance.toDouble();
    if (distance is String) {
      final cleanDistance = distance.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanDistance) ?? 0.0;
    }
    return 0.0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _parseServices(dynamic services) {
    if (services is List) {
      return services.map((s) => s?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static List<String> _parseCertifications(dynamic certifications) {
    if (certifications is List) {
      return certifications.map((c) => c?.toString() ?? '').where((c) => c.isNotEmpty).toList();
    }
    return ['ASE Certified', 'Factory Trained'];
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
