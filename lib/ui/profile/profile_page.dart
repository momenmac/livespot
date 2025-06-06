import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/theme_provider.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/widgets/date_picker_widget.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/profile/settings/account_settings_page.dart';
import 'package:flutter_application_2/ui/profile/profile_search_page.dart';
import 'package:flutter_application_2/ui/profile/suggested_people_section.dart';
import 'package:flutter_application_2/ui/profile/settings/privacy_settings_page.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_2/ui/widgets/safe_snackbar.dart';
import 'package:flutter_application_2/ui/widgets/safe_hero.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// Helper to fix image URLs that use localhost, 127.0.0.1, or are relative
String _getFixedImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://localhost:8000')) {
    return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
  }
  if (url.startsWith('http://127.0.0.1:8000')) {
    return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
  }
  if (url.startsWith('/')) {
    return ApiUrls.baseUrl + url;
  }
  return url;
}

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
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Filtering content for ${date.day}/${date.month}/${date.year}'),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      _selectedDate = date;
    });
    if (_tabController.index == 0) {
      _refreshPostsWithDateFilter();
    } else if (_tabController.index == 1) {
      _refreshSavedPostsWithDateFilter();
    } else if (_tabController.index == 2) {
      _refreshUpvotedPostsWithDateFilter();
    }
  }

  // Method to refresh posts with date filter
  void _refreshPostsWithDateFilter() {
    if (_selectedDate == null) return;
    setState(() {});
  }

  // Method to refresh saved posts with date filter
  void _refreshSavedPostsWithDateFilter() {
    if (_selectedDate == null) return;
    setState(() {});
  }

  // Method to refresh upvoted posts with date filter
  void _refreshUpvotedPostsWithDateFilter() {
    if (_selectedDate == null) return;
    setState(() {});
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
                            imageUrl:
                                _getFixedImageUrl(profile.profilePictureUrl),
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
                            color: _getStatusColor(profile.activityStatusStr),
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

  Widget _buildSavedTab(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getSavedPosts(profile.account.id),
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
                  'Failed to load saved posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
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
            icon: Icons.bookmark_border,
            message: 'Saved Posts',
            count: 0,
          );
        }

        return _buildPostsList(posts);
      },
    );
  }

  Widget _buildUpvotedTab(UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getUpvotedPosts(profile.account.id),
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
                  'Failed to load upvoted posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
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
            icon: Icons.thumb_up_outlined,
            message: 'Upvoted Posts',
            count: 0,
          );
        }

        return _buildPostsList(posts);
      },
    );
  }

  // Helper method to build a list of posts
  Widget _buildPostsList(List<Post> posts) {
    return RefreshIndicator(
      onRefresh: () async {
        // Use Future.delayed to avoid setState during build
        return Future.delayed(Duration.zero, () {
          if (mounted) {
            setState(() {}); // This will refresh the FutureBuilder
          }
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  // Helper method to build a post card with working buttons
  Widget _buildPostCard(Post post) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author section with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getCategoryColor(post.category).withOpacity(0.1),
                  cardBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      _getCategoryColor(post.category).withOpacity(0.2),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: post
                                .author.profilePictureUrl?.isNotEmpty ==
                            true
                        ? NetworkImage(
                            _getFixedImageUrl(post.author.profilePictureUrl))
                        : null,
                    backgroundColor: cardBackground,
                    child: post.author.profilePictureUrl?.isEmpty ?? true
                        ? Icon(Icons.person,
                            color: _getCategoryColor(post.category))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.isAnonymous
                                ? 'Anonymous'
                                : (post.author.fullName ?? post.author.name),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          if (post.author.isAdmin && !post.isAnonymous)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified_user,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: subtitleColor),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeAgo(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(post.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalizeFirstLetter(post.category),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getCategoryColor(post.category),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Post content - make the InkWell only cover content section
          InkWell(
            onTap: () => _navigateToPostDetail(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media content
                if (post.mediaUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(0)),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _buildMediaWidget(post.mediaUrls.first),
                        ),
                        // Honesty badge on image
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildHonestyBadge(post.honestyScore),
                        ),
                      ],
                    ),
                  ),

                // Post content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with custom styling
                      Text(
                        post.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Content with better contrast
                      Text(
                        post.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      // Location with cleaner display
                      if (post.location.address != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: _getCategoryColor(post.category)
                                  .withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location.address ?? 'Unknown location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      // Tags with nicer styling
                      if (post.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: post.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(post.category)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _getCategoryColor(post.category)
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getCategoryColor(post.category)
                                        .withOpacity(0.8),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider before actions
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),

          // Redesigned action buttons - Modified to only display stats, not allow direct voting
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black12 : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Upvotes display - non-interactive
                _buildInfoButton(
                  icon: Icons.arrow_upward,
                  label: post.upvotes.toString(),
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Downvotes display - non-interactive
                _buildInfoButton(
                  icon: Icons.arrow_downward,
                  label: post.downvotes.toString(),
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Save status - non-interactive
                _buildInfoButton(
                  icon: post.isSaved == true
                      ? Icons.bookmark
                      : Icons.bookmark_outline,
                  color: post.isSaved == true ? Colors.amber : Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Comments - navigate to detail
                _buildInfoButton(
                  icon: Icons.mode_comment_outlined,
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Share
                _buildInfoButton(
                  icon: Icons.ios_share,
                  color: Colors.grey,
                  onTap: () => _sharePost(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Info button builder for post actions
  Widget _buildInfoButton({
    required IconData icon,
    String? label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: color,
              ),
              if (label != null) const SizedBox(height: 4),
              if (label != null)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Post action methods
  void _sharePost(Post post) {
    // Implementation for sharing post
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing post: ${post.title}')),
    );
  }

  // Helper method to build honesty badge
  Widget _buildHonestyBadge(int honesty) {
    Color color;
    if (honesty >= 80) {
      color = ThemeConstants.green;
    } else if (honesty >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$honesty%',
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

  // Helper method to get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to get category color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return ThemeConstants.primaryColor;
      case 'alert':
        return ThemeConstants.red;
      case 'event':
        return ThemeConstants.orange;
      case 'community':
        return ThemeConstants.green;
      case 'traffic':
        return Colors.amber;
      case 'weather':
        return Colors.blue;
      case 'crime':
        return Colors.purple;
      default:
        return ThemeConstants.grey;
    }
  }

  // Helper method to capitalize first letter
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  // Helper method to navigate to post detail
  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: post.title,
          description: post.content,
          imageUrl: post.hasMedia && post.mediaUrls.isNotEmpty
              ? _getFixedImageUrl(post.mediaUrls.first)
              : '',
          location: post.location.address ?? "Unknown location",
          time: _getTimeAgo(post.createdAt),
          honesty: post.honestyScore,
          upvotes: post.upvotes,
          comments:
              0, // This information might not be available in the post model
          isVerified: post.author.isAdmin,
          post: post,
        ),
      ),
    );
  }

  // Method to open settings bottom sheet
  void _openSettings() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text('Account Settings',
                    style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountSettingsPage(
                        onThemeChanged: (ThemeMode mode) {
                          final themeProvider = Provider.of<ThemeProvider>(
                              context,
                              listen: false);
                          themeProvider.setThemeMode(mode);
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text('Privacy Settings',
                    style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacySettingsPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: ThemeConstants.red),
                title:
                    Text('Logout', style: TextStyle(color: ThemeConstants.red)),
                onTap: () => _showLogoutConfirmationDialog(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Show logout confirmation dialog
  void _showLogoutConfirmationDialog() {
    Navigator.pop(context); // Close the bottom sheet first

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: TextButton.styleFrom(
              foregroundColor: ThemeConstants.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Handle logout process
  Future<void> _handleLogout() async {
    try {
      // Show loading indicator using SafeSnackBar
      SafeSnackBar.showInfo(
        context,
        "Logging out...",
        duration: const Duration(seconds: 1),
      );

      // Get account provider
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      // Get GoogleSignIn instance
      final googleSignIn = Provider.of<GoogleSignIn>(context, listen: false);

      // Perform logout
      await accountProvider.logout();

      // Sign out from Google
      try {
        await googleSignIn.signOut();
        developer.log('Google Sign-In: Signed out successfully',
            name: 'ProfilePage');
      } catch (e) {
        developer.log('Google Sign-In: Error signing out: $e',
            name: 'ProfilePage');
      }

      // Hide any existing SnackBar before showing success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Wait a moment to ensure the previous SnackBar is cleared
        await Future.delayed(const Duration(milliseconds: 100));

        // Show success message using SafeSnackBar
        SafeSnackBar.showSuccess(
          context,
          "Logged out successfully",
          duration: const Duration(milliseconds: 600),
        );

        // Wait for the success message to be shown briefly, then navigate
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          developer.log(
              'ProfilePage: Explicitly navigating to initial screen after logout',
              name: 'ProfilePage');

          // Clear any remaining SnackBars before navigation to prevent Hero tag conflicts
          ScaffoldMessenger.of(context).clearSnackBars();

          // Reset Hero tag registry to prevent conflicts
          HeroTagRegistry.reset();

          // Small delay to ensure SnackBars are cleared
          await Future.delayed(const Duration(milliseconds: 50));

          // Use Navigator to go to the initial screen, clearing the entire stack
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.initial,
            (route) => false,
          );
        }
      }
    } catch (e) {
      developer.log('Error during logout: $e', name: 'ProfilePage', error: e);

      if (mounted) {
        // Clear any existing SnackBars before showing error
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await Future.delayed(const Duration(milliseconds: 100));

        SafeSnackBar.showError(
          context,
          "Error logging out. Please try again.",
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  // Method to show edit profile modal
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
                SafeSnackBar.showError(
                  context,
                  "Failed to select image. Please try again.",
                );
              }
            }
          }

          // Function to save profile changes
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
                    SafeSnackBar.showError(
                      context,
                      "Failed to upload profile image",
                    );
                  }
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
                  SafeSnackBar.showError(
                    context,
                    "Failed to update profile information",
                  );
                }
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
                SafeSnackBar.showInfo(
                  context,
                  "Name update functionality is in development",
                  duration: const Duration(seconds: 2),
                );
              }

              // Close modal and show success message
              if (mounted) {
                Navigator.pop(context);
                SafeSnackBar.showSuccess(
                  context,
                  "Profile updated successfully",
                );

                // Refresh the profile data
                await profileProvider.refreshCurrentUserProfile();
              }
            } catch (e) {
              developer.log('Error updating profile: $e', name: 'ProfilePage');
              if (mounted) {
                SafeSnackBar.showError(
                  context,
                  "Error updating profile: ${e.toString()}",
                );
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
                                  ? NetworkImage(_getFixedImageUrl(
                                          profile.profilePictureUrl))
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

                // Action buttons
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

  // Check if a URL/path points to a video file
  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm') ||
        lowerUrl.contains('.m4v') ||
        lowerUrl.contains('.3gp');
  }

  // Extract thumbnail URL from video URL - Direct server approach
  String? _extractThumbnailUrl(String videoUrl) {
    try {
      String relativePath = '';

      if (videoUrl.contains('attachments/video/')) {
        int pathIndex = videoUrl.indexOf('attachments/video/');
        relativePath = videoUrl.substring(pathIndex);
        relativePath = relativePath.replaceAll(
            'attachments/video/', 'media/attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        return thumbnailUrl;
      } else if (videoUrl.contains('attachments/image/') &&
          videoUrl.endsWith('.mp4')) {
        int pathIndex = videoUrl.indexOf('attachments/image/');
        relativePath = videoUrl.substring(pathIndex);
        relativePath = relativePath.replaceAll(
            'attachments/image/', 'attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        return thumbnailUrl;
      }
    } catch (e) {
      print('🎥 Error extracting thumbnail URL: $e');
    }
    return null;
  }

  // Build video thumbnail with play overlay
  Widget _buildVideoThumbnail(String videoUrl, {BoxFit fit = BoxFit.cover}) {
    String? thumbnailUrl = _extractThumbnailUrl(videoUrl);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: fit,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _buildVideoLoading();
              },
              errorBuilder: (context, error, stackTrace) {
                return FutureBuilder<Widget>(
                  future: _buildVideoThumbnailWidget(videoUrl, fit),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    } else if (snapshot.hasError) {
                      return _buildVideoPattern();
                    } else {
                      return _buildVideoLoading();
                    }
                  },
                );
              },
            )
          else
            FutureBuilder<Widget>(
              future: _buildVideoThumbnailWidget(videoUrl, fit),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                } else if (snapshot.hasError) {
                  return _buildVideoPattern();
                } else {
                  return _buildVideoLoading();
                }
              },
            ),

          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),

          // Video indicator badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build video thumbnail widget with client-side generation fallback
  Future<Widget> _buildVideoThumbnailWidget(String videoUrl, BoxFit fit) async {
    try {
      final thumbnailData = await _generateVideoThumbnail(videoUrl);
      if (thumbnailData != null && thumbnailData.isNotEmpty) {
        return Image.memory(
          thumbnailData,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildVideoPattern();
          },
        );
      }
    } catch (e) {
      print('🎥 Video thumbnail generation failed: $e');
    }
    return _buildVideoPattern();
  }

  // Generate video thumbnail with multiple attempts
  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    try {
      String processedVideoUrl = _getFixedImageUrl(videoUrl);

      List<Map<String, dynamic>> attempts = [
        {'timeMs': 1000, 'quality': 75},
        {'timeMs': 2000, 'quality': 85},
        {'timeMs': 500, 'quality': 65},
        {'timeMs': 0, 'quality': 75},
      ];

      for (var attempt in attempts) {
        try {
          final uint8list = await VideoThumbnail.thumbnailData(
            video: processedVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 400,
            maxHeight: 300,
            timeMs: attempt['timeMs'],
            quality: attempt['quality'],
          );

          if (uint8list != null && uint8list.isNotEmpty) {
            return uint8list;
          }
        } catch (e) {
          continue;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create video pattern background
  Widget _buildVideoPattern() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.grey[700]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Video Preview',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading widget for video thumbnails
  Widget _buildVideoLoading() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // Build media widget that handles both images and videos
  Widget _buildMediaWidget(String mediaUrl, {BoxFit fit = BoxFit.cover}) {
    final String fixedMediaUrl = _getFixedImageUrl(mediaUrl);

    if (_isVideoFile(fixedMediaUrl)) {
      return _buildVideoThumbnail(fixedMediaUrl, fit: fit);
    } else {
      return CachedNetworkImage(
        imageUrl: fixedMediaUrl,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported,
                    size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text('Media not available',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ...existing code...
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
  final Map<int, bool> _followingStates =
      {}; // Track follow state for each user
  final Map<int, bool> _loadingStates = {}; // Track loading state for each user

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
                ? NetworkImage(_getFixedImageUrl(user.profilePictureUrl))
                : null,
            child: user.profilePictureUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Row(
            children: [
              Text(user.fullName),
              if (user.account.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.verified_user,
                    size: 16,
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
              foregroundColor: isFollowing ? ThemeConstants.grey : Colors.white,
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
                    child: CircularProgressIndicator(strokeWidth: 2))
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
                    'isFollowing': _followingStates[user.account.id] ??
                        false, // Pass the current follow state
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
