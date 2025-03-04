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

  //! Messages
  static const String messages = 'Messages';
  static const String searchMessages = 'Search messages';
  static const String searchConversations = 'Search conversations';
  static const String filterMessages = 'Filter messages';
  static const String allMessages = 'All Messages';
  static const String unreadOnly = 'Unread Only';
  static const String archived = 'Archived';
  static const String groups = 'Groups';
  static const String newConversation = 'New Conversation';
  static const String searchUsers = 'Search users';
  static const String recentContacts = 'Recent Contacts';
  static const String startingConversationWith = 'Starting conversation with';
  static const String selectConversationToStart =
      'Select a conversation to start messaging';
  static const String noConversationsYet = 'No conversations yet';
  static const String noConversationsMatchFilter =
      'No conversations match the current filter';
  static const String errorLoadingConversations = 'Error loading conversations';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String online = 'Online';
  static const String typeMessage = 'Type a message...';
  static const String copy = 'Copy';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String deleteConversation = 'Delete Conversation';
  static const String deleteConversationConfirm =
      'Are you sure you want to delete this conversation? This action cannot be undone.';
  static const String mute = 'Mute';
  static const String unmute = 'Unmute';
  static const String searchInConversation = 'Search in conversation';
  static const String viewGroupMembers = 'View group members';
  static const String unarchive = 'Unarchive';
  static const String noMessage = 'No message';
  static const String archive = 'Archive';
  static const String markAsRead = 'Mark as read';
  static const String markAsUnread = 'Mark as unread';
  static const String conversationArchived = 'Conversation archived';
  static const String conversationUnarchived = 'Conversation unarchived';
  static const String undo = 'Undo';
  static const String markedAsUnread = 'Marked as unread';
  static const String markedAsRead = 'Marked as read';
  static const String voiceMessage = '🎤 Voice message';
  static const String recording = 'Recording...';
  static const String holdToRecord = 'Hold to record voice message';
  static const String send = 'Send';
  static const String sentByYou = 'You: ';
  static const String deleteMessageConfirm =
      'Are you sure you want to delete this message?';
  static const String messageDeleted = 'Message deleted';
  static const String recordingCancelled = 'Recording cancelled';
  static const String searchInMessages = 'Search in messages';
  static const String viewProfile = 'View profile';
  static const String reply = 'Reply';
  static const String replyingTo = 'Replying to';
  static const String swipeToReply = 'Swipe to reply';
  static const String swipeToEdit = 'Swipe to edit';
  static const String forward = 'Forward';
  static const String forwardMessage = 'Forward Message';
  static const String selectConversation = 'Select conversation';
  static const String forwarded = 'Forwarded';
  static const String editMessage = 'Edit Message';
  static const String messageEdited = 'Edited';
  static const String messageSaved = 'Message forwareded';
  static const String cancelReply = 'Cancel reply';
  static const String cancelEdit = 'Cancel edit';
  static const String noConversationsForward = 'No conversations to forward to';
  static const String copiedToClipboard = 'Text copied to clipboard';

  static const String conversationMuted = 'Conversation muted';
  static const String conversationUnmuted = 'Conversation unmuted';

  // Image related strings
  static const String imageDownloaded = 'Image saved to gallery';
  static const String imageDownloadedSuccessfully =
      'Image downloaded successfully';
  static const String imageDownloadFailed = 'Failed to download image';
  static const String imageOpenedForDownload = 'Image opened for download';
  static const String imageDownloadInProgress = 'Downloading image...';
  static const String imageSaveManually = 'Right-click to save image manually';
}
