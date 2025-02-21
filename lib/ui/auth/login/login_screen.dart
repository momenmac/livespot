import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';

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

  // Temporary credentials for testing
  final String _tempEmail = 'test@example.com';
  final String _tempPassword = 'Password123';

  final List<GlobalKey<CustomTextFieldState>> _textFieldKeys = [
    GlobalKey<CustomTextFieldState>(),
    GlobalKey<CustomTextFieldState>(),
  ];

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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDonePressed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      for (var key in _textFieldKeys) {
        key.currentState?.triggerValidation();
      }

      if (_formKey.currentState!.validate()) {
        if (_emailController.text == _tempEmail &&
            _passwordController.text == _tempPassword) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextStrings.loginSucessful),
              backgroundColor: ThemeConstants.primaryColor,
              margin: EdgeInsets.all(10.0),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ),
          );

          // Add a small delay before navigation
          await Future.delayed(Duration(milliseconds: 1500));

          if (!mounted) return;

          // Use pushReplacement instead of pushAndRemoveUntil for better stability
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Home()),
          );
        } else {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextStrings.invalidCredentials),
              backgroundColor: ThemeConstants.red,
              margin: EdgeInsets.all(10.0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
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
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Handle forgot password
                                  },
                                  child: Text(TextStrings.forgotPassword),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedButton(
                                onPressed: _isLoading
                                    ? () {}
                                    : () {
                                        _handleDonePressed();
                                      },
                                text: _isLoading
                                    ? 'Please wait...'
                                    : TextStrings.done,
                              ),
                              const SizedBox(height: 37),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
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
    );
  }
}
