import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class AuthResponse {
  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? tokens;
  final Account? user;
  final bool isNewAccount;
  final bool accountLinked;
  final bool tokenExpired;
  final String? resetToken;
  final bool emailSent;
  final bool emailExists;

  AuthResponse({
    required this.success,
    this.message,
    this.error,
    this.tokens,
    this.user,
    this.isNewAccount = false,
    this.accountLinked = false,
    this.tokenExpired = false,
    this.resetToken,
    this.emailSent = false,
    this.emailExists = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Extract tokens
    Map<String, dynamic>? tokens;
    if (json['tokens'] != null) {
      tokens = json['tokens'];
    } else if (json['access'] != null && json['refresh'] != null) {
      tokens = {
        'access': json['access'],
        'refresh': json['refresh'],
      };
    }

    // Extract user data
    Account? user;
    if (json['user'] != null) {
      user = Account.fromJson(json['user']);
    }

    return AuthResponse(
      success: json['success'] == true,
      message: json['message'],
      error: json['error'],
      tokens: tokens,
      user: user,
      isNewAccount: json['is_new_account'] == true,
      accountLinked: json['account_linked'] == true,
      tokenExpired: json['token_expired'] == true,
      resetToken: json['reset_token'],
      emailSent: json['email_sent'] == true,
      emailExists: json['exists'] == true,
    );
  }

  // Convert to standard map response
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> response = {
      'success': success,
    };

    if (message != null) response['message'] = message;
    if (error != null) response['error'] = error;
    if (tokens != null) response['tokens'] = tokens;
    if (user != null) response['user'] = user;
    if (isNewAccount) response['is_new_account'] = true;
    if (accountLinked) response['account_linked'] = true;
    if (tokenExpired) response['token_expired'] = true;
    if (resetToken != null) response['reset_token'] = resetToken;

    response['email_sent'] = emailSent;
    response['exists'] = emailExists;

    return response;
  }
}
