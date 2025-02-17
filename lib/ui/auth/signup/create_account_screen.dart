import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/custom_textfields.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  CreateAccountScreenState createState() => CreateAccountScreenState();
}

class CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  XFile? _image;

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
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -20,
            left: -20,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * .5),
              painter: Bubble1(),
            ),
          ),
          Positioned(
            right: -135,
            top: 30,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width * .6,
                  MediaQuery.of(context).size.height * .3),
              painter: Bubble2(),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 100),
                    Text(
                      'Create\nAccount',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 37),
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: ThemeConstants.textFieldFillColor,
                        backgroundImage: _image != null
                            ? FileImage(File(_image!.path))
                            : null,
                        child: _image == null
                            ? SvgPicture.asset(
                                'assets/icons/Upload.svg',
                                width: 75,
                                height: 75,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 37),
                    Form(
                      child: Column(
                        children: [
                          CustomTextField(
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Confirm Password',
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 37),
                    AnimatedButton(
                      onPressed: () {
                        // Handle account creation
                      },
                      text: 'Done',
                    ),
                    const SizedBox(height: 37),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontFamily: 'Nunito Sans',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
