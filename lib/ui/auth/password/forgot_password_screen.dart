import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/reg_exp_constants.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/widgets/verification_code_field.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/core/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';

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
    super.dispose();
  }

  void _handleSubmit() {
    _textFieldKeys[0].currentState?.triggerValidation();

    if (_formKey.currentState!.validate()) {
      // TODO: Check if email exists in database
      // TODO: Generate and store verification code
      // TODO: Send verification email through backend
      // TODO: Set expiration time for verification code
      setState(() {
        _codeSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TextStrings.codeSentTo.replaceAll('%s', _emailController.text),
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: ThemeConstants.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCodeVerification(String code) {
    // TODO: Verify code against stored code in database
    // TODO: Check if code has expired
    // TODO: Track failed attempts in database
    if (code == "123456") {
      NavigationService().replaceTo(
        AppRoutes.resetPassword,
        arguments: {'email': _emailController.text},
      );
    } else {
      _verificationKey.currentState?.clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextStrings.invalidVerificationCode,
              style: TextStyle(color: Colors.white)),
          backgroundColor: ThemeConstants.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Add email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.emailRequired;
    }
    if (!RegExpConstants.emailRegex.hasMatch(value)) {
      return TextStrings.invalidEmail;
    }
    // TODO: Add database check for email existence
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Center(
                child: SingleChildScrollView(
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
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _codeSent
                                    ? TextStrings.enterVerificationCode
                                    : TextStrings.enterEmailForCode,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              SizedBox(height: 37),
                              if (!_codeSent) ...[
                                CustomTextField(
                                  key: _textFieldKeys[0],
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                SizedBox(height: 24),
                                AnimatedButton(
                                  onPressed: _handleSubmit,
                                  text: TextStrings.sendCode,
                                ),
                              ] else ...[
                                VerificationCodeField(
                                  key: _verificationKey,
                                  onCompleted: _handleCodeVerification,
                                ),
                              ],
                              SizedBox(height: 24),
                              TextButton(
                                onPressed: () => NavigationService().goBack(),
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
            ],
          );
        },
      ),
    );
  }
}
