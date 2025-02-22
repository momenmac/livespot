import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            if (isLargeScreen) {
              // For large screens, show the modal within the right container
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      height: 200,
                      child: const Center(
                        child: Text('Notifications'),
                      ),
                    ),
                  );
                },
              );
            } else {
              // For small screens, show bottom sheet
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Notifications'),
                    ),
                  );
                },
              );
            }
          },
          child: const Text('Show Notifications'),
        ),
      ),
    );
  }
}
