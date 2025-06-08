import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class SuggestedPeopleSection extends StatefulWidget {
  const SuggestedPeopleSection({super.key});

  @override
  State<SuggestedPeopleSection> createState() => _SuggestedPeopleSectionState();
}

class _SuggestedPeopleSectionState extends State<SuggestedPeopleSection> {
  List<Map<String, dynamic>> _suggestedPeople = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedUsers();
  }

  Future<void> _fetchSuggestedUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final users = await userProvider.fetchRandomUsers(limit: 8);

      if (mounted) {
        setState(() {
          _suggestedPeople = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load suggested users';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeUser(int index) async {
    // Remove user from UI immediately for better UX
    setState(() {
      _suggestedPeople.removeAt(index);
    });

    // TODO: Implement API call to dismiss suggestion
    // This could be a separate endpoint like /api/accounts/users/dismiss-suggestion/
    try {
      // For now, we'll just remove from UI
      // In the future, you might want to call:
      // final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
      // await userProvider.dismissSuggestion(removedUser['id']);
    } catch (e) {
      // If API call fails, you might want to re-add the user
      // Note: In production, consider using proper logging instead of print
      debugPrint('Failed to dismiss suggestion: $e');
    }
  }

  Future<void> _followUser(int index) async {
    final user = _suggestedPeople[index];
    final userProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    try {
      // Follow the user via API
      await userProvider.followUser(user['id']);

      // Remove from suggestions after successful follow
      _removeUser(index);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now following ${user['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow ${user['name']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper function to fix image URLs
  String _getFixedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Handle localhost URLs
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }

    // Handle 127.0.0.1 URLs
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }

    // Handle relative paths
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }

    return url;
  }

  // Helper to build profile image widget with proper error handling
  Widget _buildProfileImage(Map<String, dynamic> user) {
    final imageUrl =
        user['profileImage'] ?? user['account']?['profile_picture'];
    final fixedUrl = _getFixedImageUrl(imageUrl);
    final userName =
        user['name'] ?? user['account']?['first_name'] ?? 'Unknown';

    if (fixedUrl.isEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: Colors.grey[300],
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          fixedUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading profile image: $error');
            return Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator(strokeWidth: 2);
          },
        ),
      ),
    );
  }

  // Navigate to user profile
  void _navigateToUserProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(
          userData: user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
            child: const Text(
              'Discover People',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(
            height: 185,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          const Divider(),
        ],
      );
    }

    // Show error state
    if (_error != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
            child: const Text(
              'Discover People',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 185,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
        ],
      );
    }

    // Don't show section if no suggested people
    if (_suggestedPeople.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        // LINE: Above Discover People
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
          child: const Text(
            'Discover People',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // LINE: Below Discover People, above people cards
        SizedBox(
          height: 185, // Increased height to prevent overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _suggestedPeople.length,
            itemBuilder: (context, index) {
              final user = _suggestedPeople[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.fromLTRB(8, 6, 8, 6), // Reduced padding
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  onTap: () => _navigateToUserProfile(user),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfileImage(user),
                          const SizedBox(height: 6), // Reduced space
                          Text(
                            user['name'] ??
                                user['account']?['first_name'] ??
                                'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '@${user['username'] ?? 'unknown'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ThemeConstants.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6), // Reduced space
                          SizedBox(
                            width: double.infinity,
                            height: 30, // Reduced height
                            child: ElevatedButton(
                              onPressed: () => _followUser(index),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: ThemeConstants.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      15), // Adjusted radius
                                ),
                              ),
                              child: const Text(
                                'Follow',
                                style: TextStyle(fontSize: 11), // Smaller font
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Theme.of(context).cardTheme.color ??
                              (Theme.of(context).brightness == Brightness.dark
                                  ? ThemeConstants.darkCardColor
                                  : ThemeConstants.lightCardColor),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onPressed: () => _removeUser(index),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // LINE: Below people cards, above tabs
        const Divider(),
      ],
    );
  }
}
