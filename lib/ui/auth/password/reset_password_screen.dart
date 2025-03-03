import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/services/utils/validation_helper.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ResetPasswordScreenState createState() => ResetPasswordScreenState();
}

class ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<GlobalKey<CustomTextFieldState>> _textFieldKeys = [
    GlobalKey<CustomTextFieldState>(),
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    for (var key in _textFieldKeys) {
      key.currentState?.triggerValidation();
    }

    if (_formKey.currentState!.validate()) {
      ResponsiveSnackBar.showSuccess(
        context: context,
        message: TextStrings.passwordUpdateSuccess,
      );
      NavigationService().replaceUntilHome(AppRoutes.login);
    }
  }

  void _handleCancel() {
    ResponsiveSnackBar.showInfo(
      context: context,
      message: TextStrings.passwordResetCancelled,
    );
    NavigationService().replaceUntilHome(AppRoutes.login);
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
                                TextStrings.resetPasswordTitle,
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              SizedBox(height: 16),
                              Text(
                                TextStrings.createNewPasswordFor.replaceAll(
                                  '%s',
                                  widget.email,
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              SizedBox(height: 37),
                              CustomTextField(
                                key: _textFieldKeys[0],
                                controller: _passwordController,
                                label: TextStrings.newPassword,
                                obscureText: true,
                                validator: ValidationHelper.validatePassword,
                              ),
                              SizedBox(height: 16),
                              CustomTextField(
                                key: _textFieldKeys[1],
                                controller: _confirmPasswordController,
                                label: TextStrings.confirmPassword,
                                obscureText: true,
                                validator: (value) =>
                                    ValidationHelper.validateConfirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                              ),
                              SizedBox(height: 37),
                              AnimatedButton(
                                onPressed: _handleSubmit,
                                text: TextStrings.updatePassword,
                              ),
                              SizedBox(height: 24),
                              TextButton(
                                onPressed: _handleCancel,
                                child: Text(TextStrings.cancel),
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
