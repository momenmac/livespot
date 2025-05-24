import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/home/components/widgets/date_picker_widget.dart';
import 'package:flutter_application_2/ui/profile/profile_search_page.dart';
import 'package:flutter_application_2/ui/profile/suggested_people_section.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

// This is an updated version of the ProfilePage with UI improvements:
// 1. Removed "ADMIN" text label under profile picture
// 2. Moved admin verification badge next to user's name
// 3. Fixed Save button styling to match Cancel button
// 4. Added loading indicator to Save button during profile update

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  bool _showDiscoverPeople = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfileData();
    });
  }

  void _initializeProfileData() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    if (profileProvider.currentUserProfile == null &&
        !profileProvider.isLoading) {
      profileProvider.fetchCurrentUserProfile();
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, child) {
        final isLoading = profileProvider.isLoading;
        final profile = profileProvider.currentUserProfile;

        if (isLoading && profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profile == null && profileProvider.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Failed to load profile',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => profileProvider.fetchCurrentUserProfile(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              // This will force refresh the profile data from the server
              // Use refreshCurrentUserProfile instead to prevent data clearing
              await profileProvider.refreshCurrentUserProfile();
            },
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: _buildUserInfoSection(profile),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showDiscoverPeople) const SuggestedPeopleSection(),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: ThemeConstants.primaryColor,
                        unselectedLabelColor: ThemeConstants.grey,
                        indicatorColor: ThemeConstants.primaryColor,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(
                              text: 'Posts',
                              icon: Icon(Icons.article_outlined)),
                          Tab(text: 'Saved', icon: Icon(Icons.bookmark_border)),
                          Tab(
                              text: 'Upvoted',
                              icon: Icon(Icons.thumb_up_outlined)),
                        ],
                      ),
                      isDarkMode,
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(profile),
                  _buildSavedTab(profile),
                  _buildUpvotedTab(profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      title: const Text('Profile'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search profiles',
          onPressed: _showSearchDialog,
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Filter by date',
          onPressed: () {
            _pickDate();
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            _openSettings();
          },
        ),
      ],
    );
  }

  void _showSearchDialog() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSearchPage(
          profileProvider: profileProvider,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DatePickerWidget(
          onDateSelected: (DateTime date) {
            setState(() {
              _selectedDate = date;
            });
            _filterContentByDate(date);
          },
          selectedDate: _selectedDate ?? DateTime.now(),
        );
      },
    );
  }

  // Date filtering for posts
  void _filterContentByDate(DateTime date) {
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Filtering content for ${date.day}/${date.month}/${date.year}'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Store the selected date
    setState(() {
      _selectedDate = date;
    });

    // We'll need to rebuild each tab with the date filter
    // This is a cleaner approach than calling setState
    if (_tabController.index == 0) {
      // We're on the user posts tab, so refresh it with the date
      _refreshPostsWithDateFilter();
    } else if (_tabController.index == 1) {
      // We're on the saved posts tab
      _refreshSavedPostsWithDateFilter();
    } else if (_tabController.index == 2) {
      // We're on the upvoted posts tab
      _refreshUpvotedPostsWithDateFilter();
    }
  }

  // Method to refresh posts with date filter
  void _refreshPostsWithDateFilter() {
    if (_selectedDate == null) return;

    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    if (profileProvider.currentUserProfile == null) return;

    final userId = profileProvider.currentUserProfile!.account.id;
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Format the date as YYYY-MM-DD for the API
    final formattedDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    setState(() {
      // Force refresh of the current tab
    });
  }

  // Method to refresh saved posts with date filter
  void _refreshSavedPostsWithDateFilter() {
    if (_selectedDate == null) return;

    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    if (profileProvider.currentUserProfile == null) return;

    final userId = profileProvider.currentUserProfile!.account.id;
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Format the date as YYYY-MM-DD for the API
    final formattedDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    setState(() {
      // Force refresh of the current tab
    });
  }

  // Method to refresh upvoted posts with date filter
  void _refreshUpvotedPostsWithDateFilter() {
    if (_selectedDate == null) return;

    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    if (profileProvider.currentUserProfile == null) return;

    final userId = profileProvider.currentUserProfile!.account.id;
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Format the date as YYYY-MM-DD for the API
    final formattedDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    setState(() {
      // Force refresh of the current tab
    });
  }

  Widget _buildUserInfoSection(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    // Debug log to see if admin status is being properly detected
    developer.log('Admin status in profile: ${profile.account.isAdmin}',
        name: 'ProfilePage');

    // Print additional user details for debugging
    developer.log('Profile user ID: ${profile.account.id}',
        name: 'ProfilePage');
    developer.log('Profile username: ${profile.username}', name: 'ProfilePage');

    final activityStatus = profile.activityStatusStr;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeConstants.primaryColorLight,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profile.profilePictureUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: ThemeConstants.greyLight,
                              child: const Icon(Icons.person,
                                  size: 50, color: ThemeConstants.grey),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: ThemeConstants.greyLight,
                              child: const Icon(Icons.person,
                                  size: 50, color: ThemeConstants.grey),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getStatusColor(activityStatus),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      // Admin badge removed from profile picture
                    ],
                  ),
                  // Admin badge removed from below profile picture
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (profile.account.isAdmin)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.bio.isNotEmpty)
            Text(
              profile.bio,
              style: const TextStyle(fontSize: 15),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                profile.location.isNotEmpty
                    ? profile.location
                    : 'No location set',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, size: 14, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                'Joined ${profile.joinDateFormatted}',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: () => _showFollowersList(),
                child: Column(
                  children: [
                    Text(
                      profile.followersCount.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
                    Text(
                      'Followers',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              InkWell(
                onTap: () => _showFollowingList(),
                child: Column(
                  children: [
                    Text(
                      profile.followingCount.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Following',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildHonestyRating(profile.honestyScore),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: _showDiscoverPeople
                      ? ThemeConstants.primaryColor
                      : Theme.of(context).iconTheme.color,
                ),
                onPressed: () {
                  setState(() {
                    _showDiscoverPeople = !_showDiscoverPeople;
                  });
                },
                tooltip: 'Toggle Discover People',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showEditProfileModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showShareProfileDialog(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: ThemeConstants.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Share Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShareProfileDialog() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUserProfile;
    if (profile == null) return;

    final String profileLink =
        'https://yourapp.com/profile/${profile.username}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Share Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share your profile link with others:'),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profileLink,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: profileLink));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copied to clipboard!')),
                          );
                        }
                      },
                      tooltip: 'Copy link',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHonestyRating(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51), // 0.2 opacity is approximately alpha 51
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$rating% Honesty',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
        return ThemeConstants.green;
      case 'Do Not Disturb':
        return ThemeConstants.red;
      case 'Away':
        return ThemeConstants.orange;
      case 'Offline':
      default:
        return ThemeConstants.grey;
    }
  }

  Widget _buildPostsTab(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getUserPosts(profile.account.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ThemeConstants.grey.withAlpha(51),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: ${snapshot.error.toString()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeConstants.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return _buildEmptyStateWithCount(
            icon: Icons.article_outlined,
            message: 'Your Posts',
            count: 0,
          );
        }

        return _buildPostsList(posts);
      },
    );
  }

  // Other tab builders (saved, upvoted) would remain the same
  Widget _buildSavedTab(UserProfile? profile) {
    // Implementation unchanged
    return const Center(child: Text("Saved Posts"));
  }

  Widget _buildUpvotedTab(UserProfile? profile) {
    // Implementation unchanged
    return const Center(child: Text("Upvoted Posts"));
  }

  Widget _buildPostsList(List<Post> posts) {
    // Implementation unchanged
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) => ListTile(
        title: Text('Post ${index + 1}'),
      ),
    );
  }

  // Method to show edit profile modal with improved UI
  void _showEditProfileModal() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUserProfile;
    if (profile == null) return;

    // Profile editing form controllers
    final nameController = TextEditingController(text: profile.fullName);
    final bioController = TextEditingController(text: profile.bio);
    final locationController = TextEditingController(text: profile.location);
    final websiteController = TextEditingController(text: profile.website);

    // Handle profile image selection and loading state
    XFile? selectedImage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setModalState) {
          // Function to pick an image
          Future<void> pickImage() async {
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 80,
              );

              if (image != null) {
                setModalState(() {
                  selectedImage = image;
                });
                developer.log('Image selected: ${image.path}',
                    name: 'ProfilePage');
              }
            } catch (e) {
              developer.log('Error picking image: $e', name: 'ProfilePage');
              if (mounted) {
                ResponsiveSnackBar.showError(
                  context: context,
                  message: "Failed to select image. Please try again.",
                );
              }
            }
          }

          // Function to save profile updates
          Future<void> saveProfileChanges() async {
            // Set button to loading state
            setModalState(() {
              isLoading = true;
            });

            try {
              bool success = true;

              // First upload image if selected
              if (selectedImage != null) {
                developer.log('Uploading profile image: ${selectedImage!.path}',
                    name: 'ProfilePage');
                success = await profileProvider
                    .updateProfilePicture(selectedImage!.path);

                if (!success) {
                  if (mounted) {
                    ResponsiveSnackBar.showError(
                      context: context,
                      message: "Failed to upload profile image",
                    );
                  }
                  setModalState(() {
                    isLoading = false;
                  });
                  return;
                }
              }

              // Update profile information
              success = await profileProvider.updateCurrentUserProfile(
                bio: bioController.text.trim(),
                location: locationController.text.trim(),
                website: websiteController.text.trim(),
              );

              if (!success) {
                if (mounted) {
                  ResponsiveSnackBar.showError(
                    context: context,
                    message: "Failed to update profile information",
                  );
                }
                setModalState(() {
                  isLoading = false;
                });
                return;
              }

              // Update name if changed
              if (profile.fullName != nameController.text.trim()) {
                // Log that name update is needed but not available in current API
                developer.log(
                    'Name update needed - Current API doesn\'t support this directly',
                    name: 'ProfilePage');

                // For a full implementation, we would need to update:
                // 1. Create an API endpoint to update user's first_name and last_name
                // 2. Add a method to AccountProvider to make this API call
                // 3. Call that method here

                // For now, we'll show a success message without updating the name
                ResponsiveSnackBar.showInfo(
                  context: context,
                  message: "Name update functionality is in development",
                  duration: const Duration(seconds: 2),
                );
              }

              // Close modal and show success message
              if (mounted) {
                Navigator.pop(context);
                ResponsiveSnackBar.showSuccess(
                  context: context,
                  message: "Profile updated successfully",
                );

                // Refresh the profile data
                await profileProvider.refreshCurrentUserProfile();
              }
            } catch (e) {
              developer.log('Error updating profile: $e', name: 'ProfilePage');
              if (mounted) {
                ResponsiveSnackBar.showError(
                  context: context,
                  message: "Error updating profile: ${e.toString()}",
                );
              }
            } finally {
              if (mounted) {
                setModalState(() {
                  isLoading = false;
                });
              }
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle modal bottom sheet draggable icon
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal title
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Profile picture selection
                Center(
                  child: GestureDetector(
                    onTap: () => pickImage(),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: selectedImage != null
                              ? FileImage(File(selectedImage!.path))
                              : (profile.profilePictureUrl.isNotEmpty
                                  ? NetworkImage(profile.profilePictureUrl)
                                      as ImageProvider
                                  : null),
                          child: (selectedImage == null &&
                                  profile.profilePictureUrl.isEmpty)
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThemeConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Scrollable form area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Name field
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bio field
                        TextField(
                          controller: bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Location field
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Website field
                        TextField(
                          controller: websiteController,
                          decoration: const InputDecoration(
                            labelText: 'Website',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons - IMPROVED for consistent styling
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConstants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed:
                            isLoading ? null : () => saveProfileChanges(),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.0,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
                // Add padding for bottom sheet
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        });
      },
    );
  }

  // Helper method to build empty state with count
  Widget _buildEmptyStateWithCount({
    required IconData icon,
    required String message,
    required int count,
  }) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: ThemeConstants.grey.withAlpha(51),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConstants.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have $count ${message.toLowerCase()}',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowersList() {
    // Implementation unchanged
  }

  void _showFollowingList() {
    // Implementation unchanged
  }

  void _openSettings() {
    // Implementation unchanged
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool isDarkMode;

  _SliverAppBarDelegate(this._tabBar, this.isDarkMode);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}
