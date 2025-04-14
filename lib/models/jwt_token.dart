import 'dart:convert';

class JwtToken {
  final String accessToken;
  final String refreshToken;
  DateTime? lastValidationTime;

  JwtToken({
    required this.accessToken,
    required this.refreshToken,
  });

  factory JwtToken.fromJson(Map<String, dynamic> json) {
    return JwtToken(
      accessToken: json['access'],
      refreshToken: json['refresh'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access': accessToken,
      'refresh': refreshToken,
      'last_validation_time': lastValidationTime?.toIso8601String(),
    };
  }

  // Custom JWT decoding method that doesn't rely on external package
  static Map<String, dynamic> _decodeJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT token format');
      }

      final payload = parts[1];
      String normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded);
    } catch (e) {
      print('Error decoding JWT: $e');
      return {};
    }
  }

  // Check if JWT is expired
  static bool _isExpired(String token) {
    try {
      final decodedToken = _decodeJWT(token);
      final expiryTimestamp = decodedToken['exp'];
      if (expiryTimestamp == null) return true;

      final expiryDate =
          DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      print('Error checking token expiry: $e');
      return true;
    }
  }

  bool get isAccessTokenExpired {
    try {
      return _isExpired(accessToken);
    } catch (e) {
      print('Error checking access token expiry: $e');
      return true;
    }
  }

  bool get isRefreshTokenExpired {
    try {
      return _isExpired(refreshToken);
    } catch (e) {
      print('Error checking refresh token expiry: $e');
      return true;
    }
  }

  // Get access token expiry date
  DateTime get accessTokenExpiryDate {
    try {
      final decodedToken = _decodeJWT(accessToken);
      final timestamp = decodedToken['exp'];
      if (timestamp == null) return DateTime.now();
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    } catch (e) {
      print('Error getting access token expiry date: $e');
      return DateTime.now();
    }
  }

  // Get refresh token expiry date
  DateTime get refreshTokenExpiryDate {
    try {
      final decodedToken = _decodeJWT(refreshToken);
      final timestamp = decodedToken['exp'];
      if (timestamp == null) return DateTime.now();
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    } catch (e) {
      print('Error getting refresh token expiry date: $e');
      return DateTime.now();
    }
  }

  // Add this method to determine if token needs server validation
  bool get needsServerValidation {
    // If token is already expired locally, no need to check with server
    if (isRefreshTokenExpired) {
      return false;
    }

    // Check if it's been more than 30 minutes since our last validation
    final lastValidated =
        lastValidationTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timeSinceValidation = DateTime.now().difference(lastValidated);
    return timeSinceValidation.inMinutes > 30;
  }

  // Update validation timestamp
  void markAsValidated() {
    lastValidationTime = DateTime.now();
  }

  @override
  String toString() {
    return json.encode(toJson());
  }
}
