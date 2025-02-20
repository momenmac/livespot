import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/core/utils/email_utils.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
import 'package:flutter_application_2/ui/paint/bubble2.dart';
import 'package:flutter_application_2/ui/paint/bubble1.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/ui/widgets/verification_code_field.dart';

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

  final String _tempVerificationCode = '000000';
  bool _isResendEnabled = true;
  int _resendTimer = 30;
  Timer? _timer;

  int _attemptCount = 0;
  static const int _maxAttempts = 4;
  final GlobalKey<VerificationCodeFieldState> _verificationKey = GlobalKey();

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

  void _handleResendCode() {
    setState(() {
      _attemptCount = 0;
    });
    _startResendTimer();
  }

  void _handleCodeCompletion(String code) {
    if (_attemptCount >= _maxAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextStrings.tooManyAttempts),
          backgroundColor: ThemeConstants.red,
          margin: EdgeInsets.all(10.0),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _attemptCount++;
    });

    if (code == _tempVerificationCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TextStrings.verificationSuccessful,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: ThemeConstants.primaryColor,
          margin: EdgeInsets.all(10.0),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );
    } else {
      _verificationKey.currentState?.clearFields();

      if (_attemptCount >= _maxAttempts) {
        _showTooManyAttemptsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TextStrings.invalidCode
                  .replaceAll('%d', '${_maxAttempts - _attemptCount}'),
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: ThemeConstants.red,
            margin: EdgeInsets.all(10.0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showTooManyAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoAlertDialog(
              title: Text(TextStrings.tooManyAttemptsTitle),
              content: Text(TextStrings.tooManyAttemptsMessage),
              actions: _buildDialogActions(context),
            )
          : AlertDialog(
              title: Text(TextStrings.tooManyAttemptsTitle),
              content: Text(TextStrings.tooManyAttemptsMessage),
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
        child: Text(TextStrings.goBack),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _attemptCount = 0;
          });
          _handleResendCode();
        },
        child: Text(TextStrings.requestNewCode),
      ),
    ];
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultWidth = 402.87;
    final defaultHeight = 442.65;

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
      ),
    );
  }
}
