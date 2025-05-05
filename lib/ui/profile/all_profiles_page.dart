import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class AllProfilesPage extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;

  const AllProfilesPage({
    super.key,
    required this.profiles,
  });

  @override
  State<AllProfilesPage> createState() => _AllProfilesPageState();
}

class _AllProfilesPageState extends State<AllProfilesPage> {
  // Track follow status for each profile
  final Map<int, bool> _isFollowingMap = {};
  final Map<int, bool> _isLoadingMap = {};

  @override
  void initState() {
    super.initState();
    // Initialize follow status maps
    for (var profile in widget.profiles) {
      final userId = profile['id'] as int;
      _isFollowingMap[userId] = profile['isFollowing'] ?? false;
      _isLoadingMap[userId] = false;
    }
  }

  Future<void> _toggleFollow(
      BuildContext context, int userId, int index) async {
    // Set loading state
    setState(() {
      _isLoadingMap[userId] = true;
    });

    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final isCurrentlyFollowing = _isFollowingMap[userId] ?? false;

    try {
      bool success;
      if (isCurrentlyFollowing) {
        // Unfollow user
        success = await profileProvider.unfollowUser(userId);
        if (success) {
          developer.log('Unfollowed user: $userId', name: 'AllProfilesPage');
          // Update local state
          setState(() {
            _isFollowingMap[userId] = false;
            // Update the profile data
            widget.profiles[index]['followersCount'] =
                (widget.profiles[index]['followersCount'] ?? 1) - 1;
          });
        }
      } else {
        // Follow user
        success = await profileProvider.followUser(userId);
        if (success) {
          developer.log('Followed user: $userId', name: 'AllProfilesPage');
          // Update local state
          setState(() {
            _isFollowingMap[userId] = true;
            // Update the profile data
            widget.profiles[index]['followersCount'] =
                (widget.profiles[index]['followersCount'] ?? 0) + 1;
          });
        }
      }

      if (success && mounted) {
        ResponsiveSnackBar.showInfo(
          context: context,
          message: isCurrentlyFollowing
              ? 'Unfollowed @${widget.profiles[index]['username']}'
              : 'Now following @${widget.profiles[index]['username']}',
        );
      } else if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message:
              'Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user',
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
      developer.log('Error toggling follow status: $e',
          name: 'AllProfilesPage');
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoadingMap[userId] = false;
        });
      }
    }
  }

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
        itemCount: widget.profiles.length,
        itemBuilder: (context, index) {
          final profile = widget.profiles[index];
          final userId = profile['id'] as int;
          final isFollowing = _isFollowingMap[userId] ?? false;
          final isLoading = _isLoadingMap[userId] ?? false;

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfilePage(
                      userData: profile,
                    ),
                  ),
                ).then((_) {
                  // Refresh data when returning from profile page
                  final profileProvider =
                      Provider.of<UserProfileProvider>(context, listen: false);
                  profileProvider.fetchCurrentUserProfile();
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: profile['profileImage'] != null &&
                              profile['profileImage'].isNotEmpty
                          ? NetworkImage(profile['profileImage'])
                          : null,
                      child: profile['profileImage'] == null ||
                              profile['profileImage'].isEmpty
                          ? const Icon(Icons.person,
                              size: 40, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${profile['username'] ?? 'username'}',
                      style: TextStyle(
                        color: ThemeConstants.grey,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (profile['bio'] != null && profile['bio'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          profile['bio'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _toggleFollow(context, userId, index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? Colors.grey[200]
                            : ThemeConstants.primaryColor,
                        foregroundColor:
                            isFollowing ? ThemeConstants.grey : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
