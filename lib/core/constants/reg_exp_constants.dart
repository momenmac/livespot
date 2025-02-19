class RegExpConstants {
  RegExpConstants._();

  static final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final RegExp uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp numberRegex = RegExp(r'[0-9]');
}
