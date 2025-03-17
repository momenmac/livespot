import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/assest_path_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_application_2/services/utils/validation_helper.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/services/account_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/network_checker.dart';
import 'package:flutter_application_2/utils/api_urls.dart';

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
  bool _isRegistering = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final List<GlobalKey<CustomTextFieldState>> _textFieldKeys = [
    GlobalKey<CustomTextFieldState>(),
    GlobalKey<CustomTextFieldState>(),
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleDonePressed() async {
    // Validate each field
    for (var key in _textFieldKeys) {
      key.currentState?.triggerValidation();
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isRegistering = true;
      });

      // Log registration attempt
      print('📱 Attempting to register user: ${_emailController.text}');
      print('📱 API URL: ${ApiUrls.register}');

      // Check network connectivity and server availability
      try {
        final isServerReachable = await NetworkChecker.isServerReachable();
        if (!isServerReachable) {
          ResponsiveSnackBar.showError(
            context: context,
            message:
                "Cannot connect to server. Please check your internet connection.",
          );
          setState(() {
            _isRegistering = false;
          });

          // Navigate to the debug page if server isn't reachable
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Server Connection Issue'),
                content:
                    Text('Would you like to open the network debugging tools?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      NavigationService().navigateTo(AppRoutes.directApiTest);
                    },
                    child: Text('Yes'),
                  ),
                ],
              ),
            );
          }

          return;
        }

        // Debug network info
        final networkInfo = await NetworkChecker.debugNetworkInfo();
        print('📡 Network debug info: $networkInfo');
      } catch (e) {
        print('📡 Network check error: $e');
      }

      try {
        final accountProvider =
            Provider.of<AccountProvider>(context, listen: false);

        // Debug print for request data
        print('📱 Registration data: ${jsonEncode({
              'email': _emailController.text,
              'password': _passwordController.text,
              'first_name': _firstNameController.text,
              'last_name': _lastNameController.text,
            })}');

        final result = await accountProvider.register(
          email: _emailController.text,
          password: _passwordController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
        );

        print('📱 Registration result: $result');
        print('📱 Provider error: ${accountProvider.error}');
        print(
            '📱 Current user after registration: ${accountProvider.currentUser}');

        if (result) {
          // If registration was successful
          ResponsiveSnackBar.showSuccess(
            context: context,
            message: TextStrings.accountCreatedSuccessfully,
          );

          // Move to the next screen
          NavigationService().navigateTo(
            AppRoutes.verifyEmail,
            arguments: {
              'email': _emailController.text,
              'profileImage': _imageBytes,
              'censorEmail': false,
            },
          );
        } else {
          // If registration failed, show the error
          ResponsiveSnackBar.showError(
            context: context,
            message: accountProvider.error ?? TextStrings.registrationFailed,
          );
        }
      } catch (e) {
        print('📱 Registration exception: $e');
        ResponsiveSnackBar.showError(
          context: context,
          message: "Registration error: ${e.toString()}",
        );
      } finally {
        if (mounted) {
          setState(() {
            _isRegistering = false;
          });
        }
      }
    } else {
      ResponsiveSnackBar.showError(
        context: context,
        message: TextStrings.pleaseFixValidationErrors,
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

      ResponsiveSnackBar.showInfo(
        context: context,
        message: TextStrings.profileImageSelected,
      );
    }
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
                top: 15,
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
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: 400, minWidth: 400),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                const SizedBox(height: 50),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 400,
                                      minWidth: 400,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        CustomTextField(
                                          key: _textFieldKeys[3],
                                          controller: _firstNameController,
                                          label: TextStrings.firstName,
                                          keyboardType: TextInputType.name,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return TextStrings
                                                  .firstNameRequied;
                                            }
                                            return null;
                                          },
                                          maxWidth: 175,
                                        ),
                                        CustomTextField(
                                          key: _textFieldKeys[4],
                                          controller: _lastNameController,
                                          label: TextStrings.lastName,
                                          keyboardType: TextInputType.name,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return TextStrings
                                                  .lastNameRequied;
                                            }
                                            return null;
                                          },
                                          maxWidth: 175,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  key: _textFieldKeys[0],
                                  controller: _emailController,
                                  label: TextStrings.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: ValidationHelper.validateEmail,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  key: _textFieldKeys[1],
                                  controller: _passwordController,
                                  label: TextStrings.password,
                                  obscureText: true,
                                  validator: ValidationHelper.validatePassword,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  key: _textFieldKeys[2],
                                  controller: _confirmPasswordController,
                                  label: TextStrings.confirmPassword,
                                  obscureText: true,
                                  validator: (value) =>
                                      ValidationHelper.validateConfirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                                ),
                                const SizedBox(height: 37),
                                AnimatedButton(
                                  onPressed: _isRegistering
                                      ? null
                                      : _handleDonePressed,
                                  text: _isRegistering
                                      ? TextStrings.creatingAccount
                                      : TextStrings.next,
                                  showLoader: _isRegistering,
                                ),
                                const SizedBox(height: 37),
                                Center(
                                  child: TextButton(
                                    onPressed: _isRegistering
                                        ? null
                                        : () => NavigationService().goBack(),
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
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.light
                    ? ThemeConstants.textFieldFillColorLight
                    : ThemeConstants.textFieldFillColorDark,
                width: 4,
              ),
            ),
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
