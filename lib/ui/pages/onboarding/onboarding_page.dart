import 'package:flutter/material.dart';
import 'animated_icon_widget.dart';

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final String image;
  final List<IconData> animatedIcons;
  final List<Color> iconColors;
  final List<Offset> iconPositions;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.image,
    required this.animatedIcons,
    required this.iconColors,
    required this.iconPositions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 15),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 25),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 400,
                height: 400,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(image),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Colors.grey, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      width: 300,
                      height: 300,
                    ),
                    for (int i = 0; i < animatedIcons.length; i++)
                      Positioned(
                        left: 200 + iconPositions[i].dx - (i == 2 ? 25 : 20),
                        top: 200 + iconPositions[i].dy - (i == 2 ? 25 : 20),
                        child: AnimatedIconWidget(
                          icon: animatedIcons[i],
                          size: 35 + (i * 15).toDouble(),
                          duration: Duration(seconds: 2),
                          color: iconColors[i],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
