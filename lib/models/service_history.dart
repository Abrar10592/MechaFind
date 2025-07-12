class ServiceHistory {
  final String id;
  final String mechanicId;
  final String mechanicName;
  final String serviceName;
  final DateTime serviceDate;
  final String status; // completed, ongoing, cancelled
  final double cost;
  final String description;
  final double rating;
  final String userReview;
  final String mechanicLocation;

  ServiceHistory({
    required this.id,
    required this.mechanicId,
    required this.mechanicName,
    required this.serviceName,
    required this.serviceDate,
    required this.status,
    required this.cost,
    required this.description,
    this.rating = 0.0,
    this.userReview = '',
    required this.mechanicLocation,
  });

  factory ServiceHistory.fromJson(Map<String, dynamic> json) {
    return ServiceHistory(
      id: json['id'],
      mechanicId: json['mechanicId'],
      mechanicName: json['mechanicName'],
      serviceName: json['serviceName'],
      serviceDate: DateTime.parse(json['serviceDate']),
      status: json['status'],
      cost: json['cost'].toDouble(),
      description: json['description'],
      rating: json['rating']?.toDouble() ?? 0.0,
      userReview: json['userReview'] ?? '',
      mechanicLocation: json['mechanicLocation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'serviceName': serviceName,
      'serviceDate': serviceDate.toIso8601String(),
      'status': status,
      'cost': cost,
      'description': description,
      'rating': rating,
      'userReview': userReview,
      'mechanicLocation': mechanicLocation,
    };
  }
}
