class TextStrings {
  TextStrings._();
  //! General
  static const String appName = 'Get Started';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String skip = 'Skip';
  static const String cancel = 'Cancel';

  //! Get started screen
  static const String appDescription =
      'My App Description and Details to be added here';
  static const String iAlreadyHaveAnAccount = 'I already have an account';
  static const String letsGetStarted = 'Let\'s get started';
  static const String or = 'OR';
  static const String loginWithGoogle = 'Login with Google';
  static const String successfulLoginWithGoogle =
      'Successfully logged in with Google';
  static const String failedToLoginWithGoogle = 'Failed to sign in with Google';

  //!create account and login screens
  static const String confirmPassword = 'Confirm Password';
  static const String createAccount = 'Create Account';
  static const String createAccountTitle = 'Create\nAccount';
  static const String profilePicture = 'Profile Picture';
  static const String login = 'Login';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot password?';
  static const String loginDescription = 'Login to your account';
  static String loginSucessful = 'Login successful!';
  static String invalidCredentials = 'Invalid credentials';

  //! Validation messages
  static const String emailRequired = 'Email is required';
  static const String invalidEmail = 'Enter a valid email address';
  static const String passwordRequired = 'Password is required';
  static const String passwordMinLength =
      'Password must be at least 8 characters long';
  static const String passwordUppercase =
      'Password must contain at least one uppercase letter';
  static const String passwordLowercase =
      'Password must contain at least one lowercase letter';
  static const String passwordNumber =
      'Password must contain at least one number';
  static const String confirmPasswordRequired = 'Confirm Password is required';
  static const String passwordsDoNotMatch = 'Passwords do not match';

  //! Verification screen
  static const String verifyEmail = 'Verify Email';
  static const String verificationCodeSent = 'We sent a verification code to';
  static const String didntReceiveCode = "Didn't receive the code?";
  static const String resend = "Resend";
  static const String resendTimer = "Resend in %d s";
  static const String tooManyAttempts =
      'Too many attempts. Please try again later.';
  static const String verificationSuccessful = 'Verification successful!';
  static const String invalidCode = 'Invalid code. %d attempts remaining.';
  static const String tooManyAttemptsTitle = 'Too Many Attempts';
  static const String tooManyAttemptsMessage =
      'Please wait for the timer or try requesting a new code.';
  static const String goBack = 'Go Back';
  static const String requestNewCode = 'Request New Code';
}
