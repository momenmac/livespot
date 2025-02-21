import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/reg_exp_constants.dart';

class ValidationHelper {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.emailRequired;
    }
    if (!RegExpConstants.emailRegex.hasMatch(value)) {
      return TextStrings.invalidEmail;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.passwordRequired;
    }
    if (value.length < 8) {
      return TextStrings.passwordMinLength;
    }
    if (!RegExpConstants.uppercaseRegex.hasMatch(value)) {
      return TextStrings.passwordUppercase;
    }
    if (!RegExpConstants.lowercaseRegex.hasMatch(value)) {
      return TextStrings.passwordLowercase;
    }
    if (!RegExpConstants.numberRegex.hasMatch(value)) {
      return TextStrings.passwordNumber;
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return TextStrings.confirmPasswordRequired;
    }
    if (value != password) {
      return TextStrings.passwordsDoNotMatch;
    }
    return null;
  }
}
