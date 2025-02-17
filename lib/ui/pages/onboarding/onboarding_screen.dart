import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/ui/auth/login_screen.dart';
import 'package:flutter_application_2/ui/pages/onboarding/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  final List<List<Color>> _gradients = [
    [Colors.blue.shade100, Colors.white],
    [Colors.purple.shade100, Colors.white],
    [Colors.green.shade100, Colors.white],
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome',
      description: 'Discover amazing features in our app.',
      image: 'assets/images/onboarding1.jpg',
      animatedIcons: [Icons.star, Icons.favorite, Icons.thumb_up],
      iconColors: [Colors.red, Colors.green, Colors.blue],
      iconPositions: [
        Offset(150 * cos(pi / 4), 150 * sin(pi / 4)),
        Offset(150 * cos(3 * pi / 4), 150 * sin(3 * pi / 4)),
        Offset(150 * cos(5 * pi / 4), 150 * sin(5 * pi / 4)),
      ],
    ),
    OnboardingPage(
      title: 'Explore',
      description: 'Find what you need with ease.',
      image: 'assets/images/onboarding2.jpg',
      animatedIcons: [Icons.search, Icons.map, Icons.explore],
      iconColors: [Colors.orange, Colors.purple, Colors.yellow],
      iconPositions: [
        Offset(150 * cos(3 * pi / 4), 150 * sin(3 * pi / 4)),
        Offset(150 * cos(5 * pi / 4), 150 * sin(5 * pi / 4)),
        Offset(150 * cos(7 * pi / 4), 150 * sin(7 * pi / 4)),
      ],
    ),
    OnboardingPage(
      title: 'Get Started',
      description: 'Join us and start your journey today.',
      image: 'assets/images/onboarding3.jpg',
      animatedIcons: [Icons.play_arrow, Icons.check, Icons.flag],
      iconColors: [Colors.cyan, Colors.pink, Colors.lime],
      iconPositions: [
        Offset(150 * cos(5 * pi / 4), 150 * sin(5 * pi / 4)),
        Offset(150 * cos(7 * pi / 4), 150 * sin(7 * pi / 4)),
        Offset(150 * cos(pi / 4), 150 * sin(pi / 4)),
      ],
    ),
  ];

  void _onSkip() async {
    await SharedPrefs.setOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _onSkip();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.black45,
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: Text('Skip'),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradients[_currentPage],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _pages[index];
                },
              ),
            ),
            SlideTransition(
              position: _offsetAnimation,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 12 : 8,
                      height: _currentPage == index ? 12 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.black12,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _currentPage == index
                              ? Colors.cyan
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: FilledButton(
                onPressed: _onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                ),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    key: ValueKey<String>(_currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next'),
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
