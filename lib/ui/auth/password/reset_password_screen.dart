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
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String? resetToken;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.resetToken,
  });

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
  bool _isLoading = false;

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

    // Check if we have a valid reset token
    if (widget.resetToken == null || widget.resetToken!.isEmpty) {
      // Schedule navigation after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Missing reset token. Please request a new password reset.",
        );

        // Navigate back to forgot password screen
        NavigationService().replaceTo(AppRoutes.forgotPassword);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    for (var key in _textFieldKeys) {
      key.currentState?.triggerValidation();
    }

    if (_formKey.currentState!.validate()) {
      if (widget.resetToken == null || widget.resetToken!.isEmpty) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Reset token is missing. Please try again.",
        );
        return;
      }

      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      setState(() {
        _isLoading = true;
      });

      print(
          "🔑 Attempting password reset with token: ${widget.resetToken!.substring(0, 5)}...");

      try {
        // Reset password using token
        final success = await accountProvider.resetPassword(
          widget.resetToken!,
          _passwordController.text,
        );

        if (!mounted) return;

        if (success) {
          print("🔑 Password reset successful");
          ResponsiveSnackBar.showSuccess(
            context: context,
            message: TextStrings.passwordUpdateSuccess,
          );

          // Delay to show success message
          await Future.delayed(Duration(seconds: 1));

          if (!mounted) return;

          // If user was logged in automatically, go to home
          // Otherwise go to login
          if (accountProvider.isAuthenticated) {
            NavigationService().replaceAllWith(AppRoutes.home);
          } else {
            NavigationService().replaceUntilHome(AppRoutes.login);
          }
        } else {
          print("🔑 Password reset failed: ${accountProvider.error}");
          ResponsiveSnackBar.showError(
            context: context,
            message: accountProvider.error ?? "Failed to reset password",
          );
        }
      } catch (e) {
        print("🔑 Password reset error: ${e.toString()}");
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
    final accountProvider = Provider.of<AccountProvider>(context);
    final bool isLoading = _isLoading || accountProvider.isLoading;

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
                                onPressed: isLoading ? null : _handleSubmit,
                                text: isLoading
                                    ? 'Please wait...'
                                    : TextStrings.updatePassword,
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
