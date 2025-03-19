import 'dart:convert';

class JwtToken {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiry;
  final DateTime refreshTokenExpiry;

  JwtToken({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
    required this.refreshTokenExpiry,
  });

  /// Create a JWT token from a JSON object
  factory JwtToken.fromJson(Map<String, dynamic> json) {
    return JwtToken(
      accessToken: json['access'] ?? '',
      refreshToken: json['refresh'] ?? '',
      accessTokenExpiry: getExpiryFromToken(json['access']),
      refreshTokenExpiry: getExpiryFromToken(json['refresh'], defaultDays: 7),
    );
  }

  /// Convert the token to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'access': accessToken,
      'refresh': refreshToken,
      'access_expiry': accessTokenExpiry.toIso8601String(),
      'refresh_expiry': refreshTokenExpiry.toIso8601String(),
    };
  }

  /// Check if the access token is expired
  bool get isAccessTokenExpired {
    return DateTime.now().isAfter(accessTokenExpiry);
  }

  /// Check if the refresh token is expired
  bool get isRefreshTokenExpired {
    return DateTime.now().isAfter(refreshTokenExpiry);
  }

  /// Get a string representation of the token
  @override
  String toString() {
    return jsonEncode(toJson());
  }

  /// Extract the expiry date from a JWT token
  static DateTime getExpiryFromToken(String? token, {int defaultDays = 1}) {
    if (token == null || token.isEmpty) {
      return DateTime.now().add(Duration(days: defaultDays));
    }

    try {
      // Split the token into its parts
      final parts = token.split('.');
      if (parts.length != 3) {
        return DateTime.now().add(Duration(days: defaultDays));
      }

      // Decode the payload (middle part)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);

      // Get the expiry timestamp
      if (json['exp'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(json['exp'] * 1000);
      }
    } catch (e) {
      print('Error parsing JWT token: $e');
    }

    // Default expiry if parsing fails
    return DateTime.now().add(Duration(days: defaultDays));
  }
}
