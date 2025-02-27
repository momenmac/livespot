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

  //! Google Sign In
  static const String signInWithGoogle = 'Sign in with Google';
  static const String continueWithGoogle = 'Continue with Google';
  static const String googleSignInError = 'Google Sign In Error: ';

  //!create account and login screens
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String confirmPassword = 'Confirm Password';
  static const String createAccount = 'Create Account';
  static const String createAccountTitle = 'Create\nAccount';
  static const String profilePicture = 'Profile Picture';
  static const String login = 'Login';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot password?';
  static const String loginDescription = 'Login to your account';
  static const String loginSucessful = 'Login successful!';
  static const String invalidCredentials = 'Invalid credentials';
  static const String accountCreationStarted = 'Account creation started';
  static const String profileUpdatedSuccessfully =
      'Profile updated successfully';
  static const String profileImageSelected = 'Profile image selected';
  static const String pleaseFixValidationErrors =
      'Please fix the errors in the form';

  //! Validation messages
  static const String firstNameRequied = 'First Name is required';
  static const String lastNameRequied = 'Last Name is required';
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
  static const String pleaseEnterVerificationCode =
      'Please enter the verification code';
  static const String verificationCodeResent =
      'Verification code has been resent';
  static const String maxAttemptsReached =
      'Maximum verification attempts reached';

  static const String newPassword = 'New Password';

  //! Forgot Password Screen
  static const String forgotPasswordTitle = 'Forgot Password';
  static const String enterEmailForCode =
      'Enter your email to receive a verification code';
  static const String enterVerificationCode =
      'Enter the verification code sent to your email';
  static const String sendCode = 'Send Code';
  static const String backToLogin = 'Back to Login';
  static const String codeSentTo = 'Verification code sent to %s';
  static const String invalidVerificationCode = 'Invalid verification code';

  //! Reset Password Screen
  static const String resetPasswordTitle = 'Reset Password';
  static const String createNewPasswordFor = 'Create a new password for\n%s';
  static const String updatePassword = 'Update Password';
  static const String passwordUpdateSuccess = 'Password updated successfully';
  static const String passwordResetCancelled = 'Password reset cancelled';

  //! Map Categories
  static const String allCategories = 'All Categories';
  static const String clearAll = 'Clear All';
  static const String apply = 'Apply';
  static const String applyFilters = 'Apply Filters (%d)';
  static const String more = 'More';

  // Category Names
  static const String following = 'Following';
  static const String events = 'Events';
  static const String food = 'Food';
  static const String shopping = 'Shopping';
  static const String hotels = 'Hotels';
  static const String entertainment = 'Entertainment';
  static const String mainCategories = 'Main Categories';
  static const String activities = 'Activities';
  static const String sports = 'Sports';
  static const String arts = 'Arts';
  static const String music = 'Music';
  static const String places = 'Places';
  static const String parks = 'Parks';
  static const String museums = 'Museums';
  static const String libraries = 'Libraries';

  //! Map Page
  static const String map = 'Map';
  static const String enterYourLocation = 'Enter your location';
  static const String locationPermissionsRequired =
      'Please enable location permissions to use the map features.';
  static const String locationPermissionsDenied =
      'Location permissions are required for full functionality.';
  static const String locationPermissionsDeniedPermanently =
      'Location permissions are permanently denied. Please enable them in your browser settings.';
  static const String locationServicesDisabled =
      'Location services are disabled. Please enable them to use location features.';
  static const String errorCheckingLocationPermissions =
      'Error checking location permissions: ';
  static const String unableToGetCurrentLocation =
      'Unable to get current location. Please check your location permissions.';
  static const String locationNotFound =
      'Location not found. Please try another search.';
  static const String failedToFetchLocation =
      'Failed to fetch location. Try again later.';
  static const String failedToFetchRoute =
      'Failed to fetch route. Try again later.';
  static const String errorGettingLocation = 'Error getting location: ';
  static const String failedToInitializeLocationServices =
      'Failed to initialize location services: ';
  static const String showingDataForDate = 'Showing data for %s';
  static const String destinationSet = 'Destination set, calculating route...';
  static const String mapInitialized = 'Map initialized successfully';
}
