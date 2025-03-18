import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/reg_exp_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/widgets/verification_code_field.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _codeSent = false;
  final _verificationKey = GlobalKey<VerificationCodeFieldState>();
  final List<GlobalKey<CustomTextFieldState>> _textFieldKeys = [
    GlobalKey<CustomTextFieldState>(),
  ];

  // Add focus node for keyboard control
  final FocusNode _emailFocusNode = FocusNode();

  // Add resend timer functionality
  bool _isResendEnabled = false;
  int _resendTimer = 30;
  Timer? _timer;
  String? _resetToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _isResendEnabled = false;
      _resendTimer = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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

  void _handleSubmit() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    _textFieldKeys[0].currentState?.triggerValidation();

    if (_formKey.currentState!.validate()) {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      setState(() {
        _isLoading = true;
      });

      try {
        // Request password reset code
        final Map<String, dynamic> result =
            await accountProvider.forgotPassword(_emailController.text);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Check if email exists and if the email was sent
          final bool emailExists = result['email_exists'] ?? false;
          final bool emailSent = result['email_sent'] ?? false;

          print(
              "🔑 Password reset status - Email exists: $emailExists, Email sent: $emailSent");

          if (emailExists && emailSent) {
            // Email exists and code was sent successfully
            setState(() {
              _codeSent = true;
            });

            // Start the resend timer
            _startResendTimer();

            ResponsiveSnackBar.showSuccess(
              context: context,
              message: TextStrings.codeSentTo
                  .replaceAll('%s', _emailController.text),
            );
          } else if (emailExists && !emailSent) {
            // Email exists but failed to send code
            ResponsiveSnackBar.showError(
              context: context,
              message:
                  "Failed to send email. Please try again or contact support.",
            );
          } else {
            // Email doesn't exist - for security, we show a generic message
            ResponsiveSnackBar.showInfo(
              context: context,
              message:
                  "If your email is registered, you'll receive a recovery code shortly.",
            );
          }
        } else {
          ResponsiveSnackBar.showError(
            context: context,
            message: accountProvider.error ??
                "Failed to process request. Please try again.",
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        print("🔑 Forgot password error: ${e.toString()}");
        ResponsiveSnackBar.showError(
          context: context,
          message: "Error sending reset code. Please try again.",
        );
      }
    }
  }

  void _handleResendCode() async {
    if (!_isResendEnabled) return;

    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result =
          await accountProvider.forgotPassword(_emailController.text);

      if (!mounted) return;

      if (result['success'] == true) {
        // Reset the timer
        _startResendTimer();

        ResponsiveSnackBar.showSuccess(
          context: context,
          message: TextStrings.verificationCodeResent,
        );
      } else {
        ResponsiveSnackBar.showError(
          context: context,
          message: accountProvider.error ?? "Failed to resend reset code",
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleCodeVerification(String code) async {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      final result =
          await accountProvider.verifyResetCode(_emailController.text, code);

      if (!mounted) return;

      if (result['success']) {
        _resetToken = result['reset_token'];

        // Navigate to reset password screen
        NavigationService().replaceTo(
          AppRoutes.resetPassword,
          arguments: {
            'email': _emailController.text,
            'resetToken': _resetToken,
          },
        );
      } else {
        _verificationKey.currentState?.clearFields();
        ResponsiveSnackBar.showError(
          context: context,
          message: accountProvider.error ?? TextStrings.invalidVerificationCode,
        );
      }
    } catch (e) {
      _verificationKey.currentState?.clearFields();
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.emailRequired;
    }
    if (!RegExpConstants.emailRegex.hasMatch(value)) {
      return TextStrings.invalidEmail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final bool isLoading = _isLoading || accountProvider.isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              children: [
                Positioned(
                  top: -20,
                  left: -20,
                  child: CustomPaint(
                    size: Size(457.0, 450.0),
                    painter: Bubble1(),
                  ),
                ),
                Positioned(
                  right: -135,
                  top: 30,
                  child: CustomPaint(
                    size: Size(274.0, 270.0),
                    painter: Bubble2(),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: bottomInset > 0 ? bottomInset : 20,
                  ),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: ResponsiveContainer(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    TextStrings.forgotPasswordTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge,
                                  ),
                                  SizedBox(height: 16),
                                  if (!_codeSent)
                                    Text(
                                      TextStrings.enterEmailForCode,
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    )
                                  else
                                    Column(
                                      children: [
                                        Text(
                                          TextStrings.verificationCodeSent,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                        Text(
                                          _emailController.text,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  SizedBox(height: 37),
                                  if (!_codeSent) ...[
                                    CustomTextField(
                                      key: _textFieldKeys[0],
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      label: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateEmail,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleSubmit(),
                                    ),
                                    SizedBox(height: 24),
                                    AnimatedButton(
                                      onPressed:
                                          isLoading ? null : _handleSubmit,
                                      text: isLoading
                                          ? 'Sending...'
                                          : TextStrings.sendCode,
                                    ),
                                  ] else ...[
                                    VerificationCodeField(
                                      key: _verificationKey,
                                      onCompleted: (code) {
                                        FocusScope.of(context).unfocus();
                                        _handleCodeVerification(code);
                                      },
                                    ),
                                    SizedBox(height: 20),
                                    // Add resend option with timer
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                    .replaceAll(
                                                    '%d',
                                                    _resendTimer.toString(),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  SizedBox(height: 24),
                                  TextButton(
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      NavigationService().goBack();
                                    },
                                    child: Text(TextStrings.backToLogin),
                                  ),
                                ],
                              ),
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
