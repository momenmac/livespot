import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/services/utils/email_utils.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/ui/widgets/verification_code_field.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'package:provider/provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  final Uint8List? profileImage;
  final bool censorEmail;

  const VerifyEmailScreen({
    super.key,
    this.email,
    this.profileImage,
    this.censorEmail = true,
  });

  @override
  VerifyEmailScreenState createState() => VerifyEmailScreenState();
}

class VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isResendEnabled = true;
  int _resendTimer = 30;
  Timer? _timer;

  int _attemptCount = 0;
  static const int _maxAttempts = 4;
  final GlobalKey<VerificationCodeFieldState> _verificationKey = GlobalKey();
  bool _isVerifying = false;

  String? _effectiveEmail;
  bool _hasSentInitialCode = false;
  bool _isInitializing = false; // New flag to prevent multiple initializations

  // Static variable to track screen instances to prevent multiple code sends
  static bool _isScreenActive = false;

  void _startResendTimer() {
    if (!mounted) return;

    setState(() {
      _isResendEnabled = false;
      _resendTimer = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _isResendEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResendCode() async {
    if (!_isResendEnabled || _isVerifying)
      return; // Prevent resend during verification

    setState(() {
      _isResendEnabled = false;
    });

    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      final result = await accountProvider.resendVerificationCode();

      if (mounted && result) {
        setState(() {
          _attemptCount = 0;
        });
        _startResendTimer();

        ResponsiveSnackBar.showInfo(
          context: context,
          message: "Verification code resent! Please check your email.",
        );
      } else if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: accountProvider.error ??
              "Failed to resend verification code. Please try again later.",
        );
        setState(() {
          _isResendEnabled = true;
        });
      }
    } catch (e) {
      print('🔄 Resend code error: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Error sending code: ${e.toString()}",
        );
        setState(() {
          _isResendEnabled = true;
        });
      }
    }
  }

  Future<void> _handleCodeCompletion(String code) async {
    if (_isVerifying) return;

    if (_attemptCount >= _maxAttempts) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Too many attempts. Please request a new code.",
      );
      return;
    }

    setState(() {
      _attemptCount++;
      _isVerifying = true;
    });

    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      // First make sure the token is not expired
      await accountProvider.verifyAndRefreshTokenIfNeeded();

      final result = await accountProvider.verifyEmail(code);

      if (mounted) {
        // Check if widget is still mounted before updating UI
        if (result) {
          ResponsiveSnackBar.showSuccess(
            context: context,
            message: "Your email has been verified successfully!",
          );

          // CRITICAL FIX: Check if user is already authenticated
          // If they are, go to home. If not, go to login.
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted) {
              final accountProvider =
                  Provider.of<AccountProvider>(context, listen: false);
              if (accountProvider.isAuthenticated) {
                print(
                    '✅ User verified and authenticated - registering FCM token and redirecting to home');

                // Register FCM token now that the user is fully verified and authenticated
                try {
                  await FirebaseMessagingService.registerToken();
                  print('✅ FCM token registered after email verification');
                } catch (e) {
                  print(
                      '⚠️ Error registering FCM token after verification: $e');
                }

                NavigationService().replaceAllWith(AppRoutes.home);
              } else {
                print(
                    '✅ User verified but not authenticated - redirecting to login');
                NavigationService().replaceAllWith(AppRoutes.login);
              }
            }
          });
        } else {
          _verificationKey.currentState?.clearFields();

          if (_attemptCount >= _maxAttempts) {
            _showTooManyAttemptsDialog();
          } else {
            ResponsiveSnackBar.showError(
              context: context,
              message: accountProvider.error ??
                  "Invalid code. You have ${_maxAttempts - _attemptCount} attempts left.",
            );
          }
        }
      }
    } catch (e) {
      print('✉️ Verification error: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Verification failed: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showTooManyAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoAlertDialog(
              title: const Text(TextStrings.tooManyAttemptsTitle),
              content: const Text(TextStrings.tooManyAttemptsMessage),
              actions: _buildDialogActions(context),
            )
          : AlertDialog(
              title: const Text(TextStrings.tooManyAttemptsTitle),
              content: const Text(TextStrings.tooManyAttemptsMessage),
              actions: _buildDialogActions(context),
            ),
    );
  }

  List<Widget> _buildDialogActions(BuildContext context) {
    return [
      TextButton(
        onPressed: () {
          // Reset auth transition state before navigating back
          Provider.of<AccountProvider>(context, listen: false)
              .resetAuthTransition();
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Go back from verify screen
        },
        child: const Text(TextStrings.goBack),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _attemptCount = 0;
          });
          _handleResendCode();
        },
        child: const Text(TextStrings.requestNewCode),
      ),
    ];
  }

  void _initializeEmail() {
    // Initialize email synchronously to avoid state issues
    String? email = widget.email;
    if (email == null || email.isEmpty) {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      email = accountProvider.currentUser?.email;
    }
    _effectiveEmail = email;
  }

  void _handleInvalidEmail() {
    print('⚠️ Attempted to access verification screen without valid email');
    Future.microtask(() {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context: context,
        message: "Email verification requires registration first",
      );
      NavigationService().replaceAllWith(AppRoutes.login);
    });
  }

  void _checkVerificationStatusSafely() {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    // Only log status, don't auto-redirect to prevent interference
    if (accountProvider.isUserVerified) {
      print('✅ User is already verified but staying on verification screen');
    } else {
      print('⏳ User not verified. Showing verification screen...');
    }
  }

  @override
  void initState() {
    super.initState();

    // Prevent multiple screen initializations
    if (_isInitializing) {
      print(
          '⚠️ VerifyEmailScreen already initializing, skipping duplicate initialization');
      return;
    }
    _isInitializing = true;

    // Mark screen as active to prevent multiple instances
    if (_isScreenActive) {
      print('⚠️ VerifyEmailScreen already active, skipping code sending');
      return;
    }
    _isScreenActive = true;

    print('🚀 VerifyEmailScreen: Starting initialization');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // Initialize email immediately and synchronously
    _initializeEmail();

    // Only do async operations after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isInitializing = false;
        return;
      }

      // Check if email is valid before proceeding
      if (_effectiveEmail == null || _effectiveEmail!.isEmpty) {
        _handleInvalidEmail();
        _isInitializing = false;
        return;
      }

      print('✅ VerifyEmailScreen: Email validated: $_effectiveEmail');

      // Only check verification status without automatic redirects
      _checkVerificationStatusSafely();

      // Send initial code only if needed and email is valid
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      if (!accountProvider.isUserVerified && !_hasSentInitialCode) {
        print('📧 VerifyEmailScreen: Sending initial verification code');
        _startResendTimer();
        _sendInitialVerificationCode();
      } else {
        print(
            '📧 VerifyEmailScreen: Skipping code send - already verified or already sent');
      }

      _isInitializing = false;
    });
  }

  void _sendInitialVerificationCode() async {
    if (_hasSentInitialCode || !mounted) {
      print(
          '📧 VerifyEmailScreen: Skipping initial code send - already sent or not mounted');
      return;
    }

    _hasSentInitialCode = true;
    print(
        '📧 VerifyEmailScreen: Sending initial verification code to $_effectiveEmail');

    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    try {
      final result = await accountProvider.resendVerificationCode();
      if (!mounted) return; // Prevent setState or snackbar if unmounted

      if (result) {
        print(
            '✅ VerifyEmailScreen: Initial verification code sent successfully');
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: "Verification code sent! Please check your email.",
        );
      } else {
        print('❌ VerifyEmailScreen: Failed to send initial verification code');
        ResponsiveSnackBar.showError(
          context: context,
          message: accountProvider.error ??
              "Failed to send verification code. Please try again.",
        );
      }
    } catch (e) {
      print('📧 Initial code send error: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Error sending initial code: ${e.toString()}",
        );
      }
    }
  }

  @override
  void dispose() {
    print('🗑️ VerifyEmailScreen: Disposing resources');
    _controller.dispose();
    _timer?.cancel();

    // Reset static flags when screen is disposed
    _isScreenActive = false;
    _isInitializing = false;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use _effectiveEmail for display and logic
    final emailToShow = _effectiveEmail ?? widget.email;

    // Return a loading indicator if email is invalid
    // The _checkEmailAndRedirectIfInvalid method will handle the redirection
    if (emailToShow == null || emailToShow.isEmpty) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final defaultWidth = 402.87;
    final defaultHeight = 442.65;

    // Continue with normal build if email is valid
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final verticalPadding =
                orientation == Orientation.portrait ? 100.0 : 20.0;
            final bottomPadding =
                orientation == Orientation.portrait ? 69.0 : 20.0;
            return Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -500,
                  child: Transform(
                    transform: Matrix4.rotationZ(1.5),
                    child: CustomPaint(
                      size: Size(500, 500),
                      painter: Bubble1(),
                    ),
                  ),
                ),
                Positioned(
                  right: -170,
                  top: -290,
                  child: CustomPaint(
                    size: Size(defaultWidth, defaultHeight),
                    painter: Bubble2(),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, verticalPadding, 20, bottomPadding),
                      child: Center(
                        child: ResponsiveContainer(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                            60, 101, 101, 101),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: widget.profileImage != null
                                        ? Image.memory(
                                            widget.profileImage!,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.person,
                                            size: 60,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  TextStrings.verifyEmail,
                                  style:
                                      Theme.of(context).textTheme.displayLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  TextStrings.verificationCodeSent,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  widget.censorEmail
                                      ? censorEmail(emailToShow)
                                      : emailToShow,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 37),
                                VerificationCodeField(
                                  key: _verificationKey,
                                  onCompleted: _handleCodeCompletion,
                                ),
                                const SizedBox(height: 37),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(TextStrings.didntReceiveCode),
                                    TextButton(
                                      onPressed: _isResendEnabled
                                          ? _handleResendCode
                                          : null,
                                      child: Text(
                                        _isResendEnabled
                                            ? TextStrings.resend
                                            : TextStrings.resendTimer
                                                .replaceAll('%d',
                                                    _resendTimer.toString()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 37),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      // Reset auth transition state before navigation
                                      Provider.of<AccountProvider>(context,
                                              listen: false)
                                          .resetAuthTransition();
                                      NavigationService().goBack();
                                    },
                                    child: Text(TextStrings.cancel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
