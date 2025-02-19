import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/assest_path_constants.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/core/constants/reg_exp_constants.dart';
import 'package:flutter_application_2/ui/auth/signup/verify_email.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'dart:typed_data';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  CreateAccountScreenState createState() => CreateAccountScreenState();
}

class CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Uint8List? _imageBytes;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<GlobalKey<CustomTextFieldState>> _textFieldKeys = [
    GlobalKey<CustomTextFieldState>(),
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleDonePressed() {
    for (var key in _textFieldKeys) {
      key.currentState?.triggerValidation();
    }

    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(
            email: _emailController.text,
            profileImage: _imageBytes,
            censorEmail: false,
          ),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.passwordRequired;
    }
    if (value.length < 8) {
      return TextStrings.passwordMinLength;
    }
    if (!RegExpConstants.uppercaseRegex.hasMatch(value)) {
      return TextStrings.passwordUppercase;
    }
    if (!RegExpConstants.lowercaseRegex.hasMatch(value)) {
      return TextStrings.passwordLowercase;
    }
    if (!RegExpConstants.numberRegex.hasMatch(value)) {
      return TextStrings.passwordNumber;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return TextStrings.confirmPasswordRequired;
    }
    if (value != _passwordController.text) {
      return TextStrings.passwordsDoNotMatch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final defaultWidth = 457.0;
    final defaultHeight = 900.0;

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final verticalPadding =
              orientation == Orientation.portrait ? 100.0 : 20.0;
          final bottomPadding =
              orientation == Orientation.portrait ? 69.0 : 20.0;
          return Stack(
            children: [
              Positioned(
                top: -20,
                left: -20,
                child: CustomPaint(
                  size: Size(defaultWidth, defaultHeight * .5),
                  painter: Bubble1(),
                ),
              ),
              Positioned(
                right: -135,
                top: 30,
                child: CustomPaint(
                  size: Size(defaultWidth * .6, defaultHeight * .3),
                  painter: Bubble2(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, verticalPadding, 20, bottomPadding),
                    child: Center(
                      child: ResponsiveContainer(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                orientation == Orientation.portrait
                                    ? ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxWidth: 400, minWidth: 400),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              TextStrings.createAccountTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge,
                                              textAlign: TextAlign.left,
                                            ),
                                            const SizedBox(height: 37),
                                            _buildProfilePicturePicker(),
                                          ],
                                        ),
                                      )
                                    : ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxWidth: 400, minWidth: 400),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                TextStrings.createAccountTitle,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displayLarge,
                                                textAlign: TextAlign.start,
                                              ),
                                            ),
                                            _buildProfilePicturePicker(),
                                          ],
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
                                const SizedBox(height: 16),
                                CustomTextField(
                                  key: _textFieldKeys[2],
                                  controller: _confirmPasswordController,
                                  label: TextStrings.confirmPassword,
                                  obscureText: true,
                                  validator: _validateConfirmPassword,
                                ),
                                const SizedBox(height: 37),
                                AnimatedButton(
                                  onPressed: _handleDonePressed,
                                  text: TextStrings.next,
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfilePicturePicker() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 45,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? ThemeConstants.textFieldFillColorDark
                : ThemeConstants.textFieldFillColorLight,
            backgroundImage:
                _imageBytes != null ? MemoryImage(_imageBytes!) : null,
            child: _imageBytes == null
                ? SvgPicture.asset(
                    AssestPathConstants.uploadSvg,
                    width: 75,
                    height: 75,
                  )
                : null,
          ),
        ),
        if (_imageBytes != null)
          Positioned(
            top: 0,
            right: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _imageBytes = null;
                  });
                },
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: ThemeConstants.red,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: ThemeConstants.lightBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
