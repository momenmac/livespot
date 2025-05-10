class PostCoordinates {
  final double latitude;
  final double longitude;
  final String? address;

  PostCoordinates({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory PostCoordinates.fromJson(Map<String, dynamic> json) {
    return PostCoordinates(
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      address: json['address'],
    );
  }

  // Helper method to safely convert various types to double
  static double _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.parse(value);
    }
    return 0.0; // Default fallback
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    };
  }
}
