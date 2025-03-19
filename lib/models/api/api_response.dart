import 'package:flutter_application_2/models/account.dart';

class ApiResponse<T> {
  final bool success;
  final String? message;
  final String? error;
  final T? data;
  final bool tokenExpired;

  ApiResponse({
    required this.success,
    this.message,
    this.error,
    this.data,
    this.tokenExpired = false,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json,
      T? Function(Map<String, dynamic>?)? dataFromJson) {
    // Check if token expired
    final bool tokenExpired = json['token_expired'] == true;

    // Determine if the response is successful
    final bool success = json['success'] == true;

    // Extract message and error
    final String? message = json['message'];
    final String? error = json['error'];

    // Extract data if available and converter is provided
    T? data;
    if (dataFromJson != null) {
      data = dataFromJson(json['data'] as Map<String, dynamic>?);
    }

    return ApiResponse(
      success: success,
      message: message,
      error: error,
      data: data,
      tokenExpired: tokenExpired,
    );
  }

  // Specialized factory for Account responses
  factory ApiResponse.withUser(Map<String, dynamic> json) {
    final bool success = json['success'] == true || (json['user'] != null);
    final Account? user =
        json['user'] != null ? Account.fromJson(json['user']) : null;

    return ApiResponse(
      success: success,
      message: json['message'],
      error: json['error'],
      data: user as T?,
      tokenExpired: json['token_expired'] == true,
    );
  }

  // Specialized factory for token responses
  factory ApiResponse.withTokens(Map<String, dynamic> json) {
    final bool success = json['success'] == true;

    Map<String, dynamic>? tokens;
    if (json['tokens'] != null) {
      tokens = json['tokens'];
    } else if (json['access'] != null && json['refresh'] != null) {
      tokens = {
        'access': json['access'],
        'refresh': json['refresh'],
      };
    }

    return ApiResponse(
      success: success,
      message: json['message'],
      error: json['error'],
      data: tokens as T?,
      tokenExpired: json['token_expired'] == true,
    );
  }

  // Convert API response to standard format
  Map<String, dynamic> toStandardResponse() {
    final Map<String, dynamic> response = {
      'success': success,
    };

    if (message != null) response['message'] = message;
    if (error != null) response['error'] = error;
    if (data != null) response['data'] = data;
    if (tokenExpired) response['token_expired'] = true;

    return response;
  }
}
