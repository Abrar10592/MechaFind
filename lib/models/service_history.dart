class ServiceHistory {
  final String id;
  final String mechanicId;
  final String mechanicName;
  final DateTime serviceDate;
  final double rating;
  final String userReview;

  ServiceHistory({
    required this.id,
    required this.mechanicId,
    required this.mechanicName,
    required this.serviceDate,
    this.rating = 0.0,
    this.userReview = '',
  });

  factory ServiceHistory.fromJson(Map<String, dynamic> json) {
    return ServiceHistory(
      id: json['id'],
      mechanicId: json['mechanic_id'],
      mechanicName: json['mechanics']?['users']?['full_name'] ?? 'Unknown Mechanic',
      serviceDate: DateTime.parse(json['created_at']),
      rating: (json['rating'] == null) ? 0.0 : json['rating'].toDouble(),
      userReview: json['comment'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mechanic_id': mechanicId,
      'mechanicName': mechanicName,
      'created_at': serviceDate.toIso8601String(),
      'rating': rating,
      'comment': userReview,
    };
  }
}
