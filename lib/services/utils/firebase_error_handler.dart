import 'dart:async';
import 'package:flutter/material.dart';

/// Utility class to handle Firebase errors consistently
class FirebaseErrorHandler {
  /// Process Firebase exceptions and return user-friendly messages
  static String handleError(dynamic error) {
    // When Firebase packages are added, uncommment this section
    // if (error is FirebaseException) {
    //   switch (error.code) {
    //     case 'permission-denied':
    //       return 'You don\'t have permission to perform this action.';
    //     case 'not-found':
    //       return 'The requested resource was not found.';
    //     case 'already-exists':
    //       return 'The resource already exists.';
    //     case 'resource-exhausted':
    //       return 'Too many requests. Please try again later.';
    //     case 'failed-precondition':
    //       return 'Operation failed due to the current state of the system.';
    //     case 'unavailable':
    //       return 'Service currently unavailable. Please check your internet connection.';
    //     case 'unauthenticated':
    //       return 'You must be logged in to perform this action.';
    //     default:
    //       return 'An error occurred: ${error.message}';
    //   }
    // }

    if (error is TimeoutException) {
      return 'The operation timed out. Please check your internet connection.';
    }

    // Generic error handling
    return 'An error occurred: $error';
  }

  /// Retry a Firebase operation with exponential backoff
  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 300),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) {
          debugPrint('Operation failed after $maxRetries attempts: $e');
          rethrow;
        }

        debugPrint(
            'Operation failed (attempt $attempts): $e - retrying in ${delay.inMilliseconds}ms');
        await Future.delayed(delay);

        // Exponential backoff
        delay = delay * 2;
      }
    }
  }
}
