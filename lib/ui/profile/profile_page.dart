import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/theme_provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/widgets/date_picker_widget.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/profile/settings/account_settings_page.dart';
import 'package:flutter_application_2/ui/pages/map/map_page.dart';
import 'package:flutter_application_2/ui/profile/profile_search_page.dart';
import 'package:flutter_application_2/ui/profile/suggested_people_section.dart';
import 'package:flutter_application_2/ui/profile/settings/privacy_settings_page.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

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

  void _filterContentByDate(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Filtering content for ${date.day}/${date.month}/${date.year}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildUserInfoSection(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    final activityStatus = profile.activityStatusStr;
    final isVerified = profile.isVerified;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeConstants.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeConstants.primaryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: ThemeConstants.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ThemeConstants.primaryColor,
                              ),
                            ),
                          ],
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
    return _buildEmptyStateWithCount(
      icon: Icons.article_outlined,
      message: 'Your Posts',
      count: profile.postsCount,
    );
  }

  Widget _buildSavedTab(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();
    return _buildEmptyStateWithCount(
      icon: Icons.bookmark_border,
      message: 'Saved Posts',
      count: profile.savedPostsCount,
    );
  }

  Widget _buildUpvotedTab(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();
    return _buildEmptyStateWithCount(
      icon: Icons.thumb_up_outlined,
      message: 'Upvoted Posts',
      count: profile.upvotedPostsCount,
    );
  }

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
                color: ThemeConstants.grey
                    .withAlpha(51), // 0.2 opacity is approximately alpha 51
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

  Future<void> _pickLocationFromMap() async {
    final BuildContext currentContext = context;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          showBackButton: true,
          onBackPress: () {
            if (currentContext.mounted) {
              Navigator.pop(currentContext);
            }
          },
        ),
      ),
    );

    if (result != null && result is String && mounted) {
      final profileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      profileProvider.updateCurrentUserProfile(location: result);
    }
  }

  void _showEditProfileModal() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUserProfile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.fullName);
    final usernameController = TextEditingController(text: profile.username);
    final bioController = TextEditingController(text: profile.bio);
    final locationController = TextEditingController(text: profile.location);
    final websiteController =
        TextEditingController(text: profile.website ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            Consumer<UserProfileProvider>(
                              builder: (context, provider, _) {
                                final profilePictureUrl = provider
                                        .currentUserProfile
                                        ?.profilePictureUrl ??
                                    '';
                                // Add a cache-busting parameter to the URL
                                final cacheBustedUrl =
                                    '$profilePictureUrl?t=${DateTime.now().millisecondsSinceEpoch}';

                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: ThemeConstants.greyLight,
                                  backgroundImage: profilePictureUrl.isNotEmpty
                                      ? NetworkImage(cacheBustedUrl)
                                      : null,
                                  child: profilePictureUrl.isEmpty
                                      ? Icon(Icons.person,
                                          size: 50, color: ThemeConstants.grey)
                                      : null,
                                  onBackgroundImageError: (_, __) {
                                    // Display fallback icon when error occurs
                                  },
                                );
                              },
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: ThemeConstants.primaryColor,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      size: 18, color: Colors.white),
                                  onPressed: () async {
                                    // Show image source selection dialog
                                    final ImageSource? source =
                                        await showModalBottomSheet<ImageSource>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return SafeArea(
                                          child: Wrap(
                                            children: <Widget>[
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.photo_camera),
                                                title:
                                                    const Text('Take a photo'),
                                                onTap: () => Navigator.pop(
                                                    context,
                                                    ImageSource.camera),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.photo_library),
                                                title: const Text(
                                                    'Choose from gallery'),
                                                onTap: () => Navigator.pop(
                                                    context,
                                                    ImageSource.gallery),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                    if (source == null) return;

                                    try {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image =
                                          await picker.pickImage(
                                        source: source,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );

                                      if (image == null) return;

                                      // Show uploading indicator
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Dialog(
                                            child: Padding(
                                              padding: EdgeInsets.all(20.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 16),
                                                  Text(
                                                      'Uploading profile picture...'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final profileProvider =
                                          Provider.of<UserProfileProvider>(
                                              context,
                                              listen: false);

                                      final success = await profileProvider
                                          .updateProfilePicture(image.path);

                                      // Close the loading dialog
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }

                                      // Force refresh the profile to ensure UI updates properly
                                      if (success) {
                                        await profileProvider
                                            .refreshCurrentUserProfile();
                                      }

                                      // Show result message
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(success
                                                ? 'Profile picture updated successfully!'
                                                : 'Failed to update profile picture: ${profileProvider.error ?? "Unknown error"}'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Close loading dialog if open
                                      if (context.mounted &&
                                          Navigator.of(context).canPop()) {
                                        Navigator.pop(context);
                                      }

                                      // Show error message
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Error updating profile picture: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixText: '@',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: () async {
                              await _pickLocationFromMap();
                              if (mounted) {
                                final updatedProfile =
                                    profileProvider.currentUserProfile;
                                if (updatedProfile != null) {
                                  locationController.text =
                                      updatedProfile.location;
                                }
                              }
                            },
                            tooltip: 'Pick location from map',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    final success =
                        await profileProvider.updateCurrentUserProfile(
                      username: usernameController.text,
                      bio: bioController.text,
                      location: locationController.text,
                      website: websiteController.text,
                    );

                    if (context.mounted) Navigator.pop(context);

                    if (context.mounted) Navigator.pop(context);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Profile updated successfully!'
                              : 'Failed to update profile: ${profileProvider.error}'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSettings() {
    final BuildContext pageContext = context;

    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Account Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(modalContext);
                  Navigator.push(
                    pageContext,
                    MaterialPageRoute(
                      builder: (context) => AccountSettingsPage(
                        onThemeChanged: (ThemeMode value) {
                          Provider.of<ThemeProvider>(context, listen: false)
                              .setThemeMode(value);
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification Preferences'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(modalContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Privacy Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(modalContext);
                  Navigator.push(
                    pageContext,
                    MaterialPageRoute(
                      builder: (context) => const PrivacySettingsPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report History'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(modalContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blocked Users'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(modalContext);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: ThemeConstants.red),
                title: const Text('Log Out',
                    style: TextStyle(color: ThemeConstants.red)),
                onTap: () async {
                  Navigator.pop(modalContext);
                  _handleLogout(pageContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext pageContext) async {
    developer.log('--- Logout Process Start (ProfilePage) ---',
        name: 'LogoutTrace');
    developer.log('Showing confirmation dialog...', name: 'LogoutTrace');

    final confirmed = await showDialog<bool>(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                developer.log('Logout cancelled by user.', name: 'LogoutTrace');
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Log Out',
                  style: TextStyle(color: ThemeConstants.red)),
              onPressed: () {
                developer.log('Logout confirmed by user.', name: 'LogoutTrace');
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    developer.log('Confirmation dialog result: $confirmed',
        name: 'LogoutTrace');

    if (!pageContext.mounted) {
      developer.log('Logout aborted: Widget is no longer mounted after dialog.',
          name: 'LogoutTrace');
      return;
    }

    if (confirmed == true) {
      developer.log('Proceeding with logout call...', name: 'LogoutTrace');

      try {
        try {
          final googleSignIn = GoogleSignIn();
          final isSignedIn = await googleSignIn.isSignedIn();
          developer.log('Google Sign-In status before logout: $isSignedIn',
              name: 'LogoutTrace');

          if (isSignedIn) {
            await googleSignIn.signOut();
            developer.log('Successfully signed out from GoogleSignIn',
                name: 'LogoutTrace');

            try {
              await googleSignIn.disconnect();
              developer.log('Successfully disconnected from GoogleSignIn',
                  name: 'LogoutTrace');
            } catch (e) {
              developer.log('GoogleSignIn disconnect failed (non-critical): $e',
                  name: 'LogoutTrace');
            }
          } else {
            developer.log('User was not signed in with Google',
                name: 'LogoutTrace');
          }
        } catch (e) {
          developer.log('Error handling GoogleSignIn during logout: $e',
              name: 'LogoutTrace');
        }

        final accountProvider =
            Provider.of<AccountProvider>(pageContext, listen: false);

        ResponsiveSnackBar.showInfo(
            context: pageContext, message: 'Logging out...');

        developer.log('Calling accountProvider.logout()...',
            name: 'LogoutTrace');

        await accountProvider.logout();

        developer.log('accountProvider.logout() finished.',
            name: 'LogoutTrace');
      } catch (e, stackTrace) {
        ResponsiveSnackBar.showError(
          context: pageContext,
          message: 'Logout failed: ${e.toString()}',
        );

        developer.log('Error calling accountProvider.logout(): $e',
            name: 'LogoutTrace', error: e, stackTrace: stackTrace);
      }
    } else {
      developer.log('Logout aborted (not confirmed).', name: 'LogoutTrace');
    }

    developer.log('--- Logout Process End (ProfilePage) ---',
        name: 'LogoutTrace');
  }

  void _showFollowersList() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FollowersPage(
          title: 'Followers',
          isFollowers: true,
          profileProvider: profileProvider,
        ),
      ),
    );
  }

  void _showFollowingList() {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FollowersPage(
          title: 'Following',
          isFollowers: false,
          profileProvider: profileProvider,
        ),
      ),
    );
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

class _FollowersPage extends StatefulWidget {
  final String title;
  final bool isFollowers;
  final UserProfileProvider profileProvider;

  const _FollowersPage({
    required this.title,
    required this.isFollowers,
    required this.profileProvider,
  });

  @override
  State<_FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<_FollowersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _users = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  final Map<int, bool> _followingStates = {}; // Track follow state for each user
  final Map<int, bool> _loadingStates = {};  // Track loading state for each user

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<UserProfile> users;

      if (widget.isFollowers) {
        users = await widget.profileProvider.getFollowers();
      } else {
        users = await widget.profileProvider.getFollowing();
      }

      // Initialize follow states
      for (var user in users) {
        _followingStates[user.account.id] = !widget.isFollowers;
        _loadingStates[user.account.id] = false;
      }

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = List.from(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Failed to load ${widget.isFollowers ? 'followers' : 'following'}: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user.fullName.toLowerCase();
        final username = user.username.toLowerCase();
        return name.contains(query) || username.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleFollow(int userId) async {
    // Don't do anything if already loading
    if (_loadingStates[userId] == true) return;
    
    // Set loading state for this user
    setState(() {
      _loadingStates[userId] = true;
    });

    try {
      bool success;
      final isFollowing = _followingStates[userId] ?? false;
      
      if (isFollowing) {
        // User is already following, so unfollow
        success = await widget.profileProvider.unfollowUser(userId);
        if (success) {
          setState(() {
            _followingStates[userId] = false;
            
            // If we're on the following page and unfollow is successful,
            // we should remove this user from the list
            if (!widget.isFollowers) {
              _filteredUsers.removeWhere((user) => user.account.id == userId);
              _users.removeWhere((user) => user.account.id == userId);
            }
          });
        }
      } else {
        // User is not following, so follow
        success = await widget.profileProvider.followUser(userId);
        if (success) {
          setState(() {
            _followingStates[userId] = true;
          });
        }
      }
    } catch (e) {
      developer.log('Error toggling follow state: $e', name: 'FollowersPage');
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[userId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: ThemeConstants.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Text(_users.isEmpty
            ? 'No ${widget.isFollowers ? 'followers' : 'following'} yet'
            : 'No users found'),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final userId = user.account.id;
        final isFollowing = _followingStates[userId] ?? false;
        final isLoading = _loadingStates[userId] ?? false;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.profilePictureUrl.isNotEmpty
                ? NetworkImage(user.profilePictureUrl)
                : null,
            child: user.profilePictureUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Row(
            children: [
              Text(user.fullName),
              if (user.isVerified)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.verified,
                    size: 16,
                    color: ThemeConstants.primaryColor,
                  ),
                ),
            ],
          ),
          subtitle: Text('@${user.username}'),
          trailing: ElevatedButton(
            onPressed: isLoading ? null : () => _toggleFollow(userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing
                  ? ThemeConstants.greyLight
                  : ThemeConstants.primaryColor,
              foregroundColor:
                  isFollowing ? ThemeConstants.grey : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: isLoading 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : Text(isFollowing ? 'Unfollow' : 'Follow'),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(
                  userData: {
                    'id': user.account.id,
                    'name': user.fullName,
                    'username': user.username,
                    'profileImage': user.profilePictureUrl,
                    'bio': user.bio,
                    'location': user.location,
                    'honesty': user.honestyScore,
                    'followers': user.followersCount,
                    'following': user.followingCount,
                    'joinDate': user.joinDateFormatted,
                    'posts': user.postsCount,
                    'comments': user.commentsCount,
                    'saved': user.savedPostsCount,
                    'upvoted': user.upvotedPostsCount,
                    'activityStatus': user.activityStatusStr,
                    'website': user.website,
                    'interests': user.interests,
                    'is_verified': user.isVerified,
                    'isFollowing': _followingStates[user.account.id] ?? false, // Pass the current follow state
                  },
                ),
              ),
            ).then((_) {
              // Refresh the list when returning from profile page
              _loadUsers();
            });
          },
        );
      },
    );
  }
}
