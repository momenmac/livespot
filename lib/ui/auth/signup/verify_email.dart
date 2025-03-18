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

  void _startResendTimer() {
    setState(() {
      _isResendEnabled = false;
      _resendTimer = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    setState(() {
      _isResendEnabled = false;
    });

    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      final result = await accountProvider.resendVerificationCode();

      if (result) {
        setState(() {
          _attemptCount = 0;
        });
        _startResendTimer();

        ResponsiveSnackBar.showSuccess(
          context: context,
          message: TextStrings.verificationCodeResent,
        );
      } else {
        ResponsiveSnackBar.showError(
          context: context,
          message:
              accountProvider.error ?? "Failed to resend verification code",
        );
        setState(() {
          _isResendEnabled = true;
        });
      }
    } catch (e) {
      print('🔄 Resend code error: $e');
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
      setState(() {
        _isResendEnabled = true;
      });
    }
  }

  Future<void> _handleCodeCompletion(String code) async {
    if (_isVerifying) return;

    if (_attemptCount >= _maxAttempts) {
      ResponsiveSnackBar.showError(
        context: context,
        message: TextStrings.tooManyAttempts,
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
      final result = await accountProvider.verifyEmail(code);

      if (result) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: TextStrings.verificationSuccessful,
        );
        NavigationService().replaceAllWith(AppRoutes.login);
      } else {
        _verificationKey.currentState?.clearFields();

        if (_attemptCount >= _maxAttempts) {
          _showTooManyAttemptsDialog();
        } else {
          ResponsiveSnackBar.showError(
            context: context,
            message: accountProvider.error ??
                TextStrings.invalidCode
                    .replaceAll('%d', '${_maxAttempts - _attemptCount}'),
          );
        }
      }
    } catch (e) {
      print('✉️ Verification error: $e');
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
    } finally {
      setState(() {
        _isVerifying = false;
      });
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
          Navigator.of(context).pop();
          Navigator.of(context).pop();
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

  void _checkEmailAndRedirectIfInvalid() {
    // Prevent direct access to verification screen without a valid email
    if (widget.email == null || widget.email!.isEmpty) {
      print('⚠️ Attempted to access verification screen without valid email');

      // Use a microtask to avoid build errors during initState
      Future.microtask(() {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Email verification requires registration first",
        );

        // Navigate back to login screen
        NavigationService().replaceAllWith(AppRoutes.login);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // Check if the user is already verified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
    });

    // Security check to prevent direct access without email
    _checkEmailAndRedirectIfInvalid();

    // Only start timer if we have a valid email
    if (widget.email != null && widget.email!.isNotEmpty) {
      _startResendTimer();
    }
  }

  // Check if the user is already verified
  void _checkVerificationStatus() {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    if (accountProvider.isUserVerified) {
      print('✅ User is already verified. Redirecting to home...');
      ResponsiveSnackBar.showSuccess(
        context: context,
        message: "Your email is already verified",
      );

      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          NavigationService().replaceAllWith(AppRoutes.home);
        }
      });
    } else {
      print('⏳ User not verified. Showing verification screen...');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return a loading indicator if email is invalid
    // The _checkEmailAndRedirectIfInvalid method will handle the redirection
    if (widget.email == null || widget.email!.isEmpty) {
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
                                if (widget.email != null)
                                  Text(
                                    widget.censorEmail
                                        ? censorEmail(widget.email!)
                                        : widget.email!,
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
                                    onPressed: () =>
                                        NavigationService().goBack(),
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
