import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/ui/auth/signup/verify_email.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

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
    _loadSavedEmail();

    // Record activity when screen loads to maintain session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AccountProvider>(context, listen: false).recordActivity();
    });
  }

  // Load saved email if remember me was selected
  Future<void> _loadSavedEmail() async {
    // This would be implemented with SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedEmail != null && rememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = rememberMe;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDonePressed() async {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    if (accountProvider.isLoading) return;

    try {
      for (var key in _textFieldKeys) {
        key.currentState?.triggerValidation();
      }

      if (_formKey.currentState!.validate()) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        // Store email if remember me is checked
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_email', email);
        }

        final result = await accountProvider.login(
          email: email,
          password: password,
          rememberMe: _rememberMe,
        );

        if (!mounted) return;

        if (result) {
          // Check if the user is verified
          if (accountProvider.isUserVerified) {
            // User is verified, show success message and navigate to home
            ResponsiveSnackBar.showSuccess(
              context: context,
              message: TextStrings.loginSucessful,
              duration: const Duration(seconds: 1),
            );

            await Future.delayed(Duration(milliseconds: 500));
            if (!mounted) return;
            NavigationService().replaceAllWith(AppRoutes.home);
          } else {
            // User is NOT verified, show verification needed message and navigate to verification screen
            ResponsiveSnackBar.showInfo(
              context: context,
              message: "Please verify your email to continue",
              duration: const Duration(seconds: 2),
            );

            await Future.delayed(Duration(milliseconds: 500));
            if (!mounted) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyEmailScreen(
                  email: email,
                  censorEmail: false, // Don't censor on login flow
                ),
              ),
            );
          }
        } else {
          if (!mounted) return;

          ResponsiveSnackBar.showError(
            context: context,
            message: accountProvider.error ?? TextStrings.invalidCredentials,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
    }
  }

  void _handleCancel() {
    NavigationService().goBack();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.emailRequired;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.passwordRequired;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final bool isLoading = accountProvider.isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final verticalPadding =
              orientation == Orientation.portrait ? 100.0 : 20.0;
          final bottomPadding =
              orientation == Orientation.portrait ? 69.0 : 20.0;
          return Stack(
            children: [
              // Background bubbles
              Positioned(
                top: -10,
                left: -110,
                child: Transform(
                  transform: Matrix4.rotationZ(0.01),
                  child: CustomPaint(
                    size: Size(700, 550),
                    painter: Bubble1(),
                  ),
                ),
              ),
              Positioned(
                left: -135,
                top: -200,
                child: CustomPaint(
                  size: Size(402.87, 442.65),
                  painter: Bubble2(),
                ),
              ),
              Positioned(
                right: -170,
                top: 50,
                child: CustomPaint(
                  size: Size(270, 270),
                  painter: Bubble2(),
                ),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, verticalPadding, 20, bottomPadding),
                    child: ResponsiveContainer(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: (orientation == Orientation.portrait
                                    ? 200
                                    : 0),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: 400, minWidth: 400),
                                child: Text(
                                  'Login',
                                  style:
                                      Theme.of(context).textTheme.displayLarge,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 37),
                              CustomTextField(
                                key: _textFieldKeys[0],
                                controller: _emailController,
                                label: TextStrings.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                key: _textFieldKeys[1],
                                controller: _passwordController,
                                label: TextStrings.password,
                                obscureText: true,
                                validator: _validatePassword,
                              ),
                              SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 400,
                                  minWidth: 400,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                        ),
                                        Text('Remember me'),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.forgotPassword,
                                        );
                                      },
                                      child: Text(TextStrings.forgotPassword),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedButton(
                                onPressed: isLoading
                                    ? () {}
                                    : () {
                                        _handleDonePressed();
                                      },
                                text: isLoading
                                    ? 'Please wait...'
                                    : TextStrings.done,
                              ),
                              const SizedBox(height: 37),
                              Center(
                                child: TextButton(
                                  onPressed: _handleCancel,
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
    );
  }
}
