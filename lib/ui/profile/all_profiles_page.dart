import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';

class AllProfilesPage extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;

  const AllProfilesPage({
    super.key,
    required this.profiles,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Discover People'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: profiles.length,
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return Card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfilePage(
                      userData: profile,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(profile['profileImage']),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '@${profile['username']}',
                    style: TextStyle(
                      color: ThemeConstants.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: (DATABASE) Update follow status in database
                      // TODO: (DATABASE) Add to user's following list
                      // TODO: (DATABASE) Update follower count for both users
                      // TODO: (DATABASE) Refresh UI to show updated status
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConstants.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text('Follow'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
