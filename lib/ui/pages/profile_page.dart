import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart'; // Import AccountProvider
import 'package:flutter_application_2/ui/pages/home/components/widgets/date_picker_widget.dart';
import 'package:flutter_application_2/ui/pages/settings/account_settings_page.dart';
import 'package:flutter_application_2/ui/pages/map/map_page.dart'; // Import MapPage
import 'package:provider/provider.dart'; // Import Provider
import 'dart:developer' as developer; // Import developer for logging
import 'package:flutter/services.dart'; // Add this import for clipboard functionality

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  DateTime? _selectedDate;

  // Mock user data - in a real app, this would come from a backend
  final Map<String, dynamic> _userData = {
    'name': 'Alex Johnson',
    'username': 'alex_johnson',
    'profileImage': 'https://picsum.photos/seed/profile/200',
    'bio':
        'Community news reporter | Passionate about local stories | Weather enthusiast',
    'location': 'Boston, MA',
    'honesty': 94,
    'followers': 842,
    'following': 156,
    'joinDate': 'March 2022',
    'posts': 78,
    'comments': 213,
    'saved': 45,
    'upvoted': 124,
  };

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // Changed from 4 to 3 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: _buildUserInfoSection(),
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
                    Tab(text: 'Posts', icon: Icon(Icons.article_outlined)),
                    Tab(text: 'Saved', icon: Icon(Icons.bookmark_border)),
                    Tab(text: 'Upvoted', icon: Icon(Icons.thumb_up_outlined)),
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
            _buildPostsTab(),
            _buildSavedTab(),
            _buildUpvotedTab(),
          ],
        ),
      ),
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

  // Date picker functionality
  Future<void> _pickDate() async {
    // Instead of using the default date picker, show our custom date picker
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
            // Filter content based on selected date
            _filterContentByDate(date);
          },
          selectedDate: _selectedDate ?? DateTime.now(),
        );
      },
    );
  }

  void _filterContentByDate(DateTime date) {
    // Implementation to filter posts/saved/upvoted by date
    // This would typically query your data source with the date filter

    // For demonstration, just show a snackbar with the selected date
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Filtering content for ${date.day}/${date.month}/${date.year}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image
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
                  child: Image.network(
                    _userData['profileImage'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: ThemeConstants.greyLight,
                        child: const Icon(Icons.person,
                            size: 50, color: ThemeConstants.grey),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      _userData['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Username
                    Text(
                      '@${_userData['username']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeConstants.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Honesty Rating
                    _buildHonestyRating(_userData['honesty']),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bio
          if (_userData['bio'].isNotEmpty)
            Text(
              _userData['bio'],
              style: const TextStyle(fontSize: 15),
            ),

          const SizedBox(height: 12),

          // Location and Join Date
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                _userData['location'],
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, size: 14, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                'Joined ${_userData['joinDate']}',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Replace the old stats and follow button row with new layout
          Row(
            children: [
              // Followers count
              InkWell(
                onTap: () => _showFollowersList(),
                child: Column(
                  children: [
                    Text(
                      _userData['followers'].toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeConstants
                            .primaryColor, // Blue theme for followers
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

              // Following count
              InkWell(
                onTap: () => _showFollowingList(),
                child: Column(
                  children: [
                    Text(
                      _userData['following'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        // Keep default color for following
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
            ],
          ),

          const SizedBox(height: 16),

          // New buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showEditProfileModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(0, 48), // Set fixed height
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
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    minimumSize: const Size(0, 48), // Match height
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

          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  // Add new method for share dialog
  void _showShareProfileDialog() {
    final String profileLink =
        'https://yourapp.com/profile/${_userData['username']}';

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
    } else if (rating >= 60)
      color = ThemeConstants.orange;
    else
      color = ThemeConstants.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
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

  // Tab content methods
  Widget _buildPostsTab() {
    // For now, returning a placeholder that would be filled with actual posts
    return _buildEmptyStateWithCount(
      icon: Icons.article_outlined,
      message: 'Your Posts',
      count: _userData['posts'],
    );
  }

  Widget _buildSavedTab() {
    return _buildEmptyStateWithCount(
      icon: Icons.bookmark_border,
      message: 'Saved Posts',
      count: _userData['saved'],
    );
  }

  Widget _buildUpvotedTab() {
    return _buildEmptyStateWithCount(
      icon: Icons.thumb_up_outlined,
      message: 'Upvoted Posts',
      count: _userData['upvoted'],
    );
  }

  // Helper for tab placeholders - would be replaced with actual content
  Widget _buildEmptyStateWithCount({
    required IconData icon,
    required String message,
    required int count,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: ThemeConstants.grey.withOpacity(0.5),
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
    );
  }

  // Action handlers
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
      setState(() {
        _userData['location'] = result;
      });
    }
  }

  void _showEditProfileModal() {
    // Create controllers for form fields
    final nameController = TextEditingController(text: _userData['name']);
    final usernameController =
        TextEditingController(text: _userData['username']);
    final bioController = TextEditingController(text: _userData['bio']);
    final locationController =
        TextEditingController(text: _userData['location']);

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
                      // Profile Picture
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage:
                                  NetworkImage(_userData['profileImage']),
                              onBackgroundImageError: (_, __) {},
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
                                  onPressed: () {
                                    // TODO: Implement image picker
                                    // 1. Show image source dialog (camera/gallery)
                                    // 2. Upload image to storage
                                    // 3. Update user profile with new image URL
                                    // 4. Update UI
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Name Field
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username Field
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixText: '@',
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bio Field
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
                      // Location Field
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
                                locationController.text = _userData['location'];
                              }
                            },
                            tooltip: 'Pick location from map',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement profile update
                    // 1. Validate form fields
                    // 2. Show loading indicator
                    // 3. Update user profile in database
                    // 4. Update local state
                    // 5. Show success message
                    // 6. Close modal

                    // Mock update for now
                    setState(() {
                      _userData['name'] = nameController.text;
                      _userData['username'] = usernameController.text;
                      _userData['bio'] = bioController.text;
                      _userData['location'] = locationController.text;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Profile updated successfully!')),
                    );
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
    // Capture the context that is valid before showing the modal/dialog
    final BuildContext pageContext = context;

    showModalBottomSheet(
      context: pageContext, // Use the captured context for the modal
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
                        onThemeChanged: (ThemeMode value) {},
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
                  developer.log('--- Logout Process Start (ProfilePage) ---',
                      name: 'LogoutTrace');
                  // Close the bottom sheet first using its own context
                  Navigator.pop(modalContext);
                  developer.log('Bottom sheet closed.', name: 'LogoutTrace');

                  // Show confirmation dialog using the page's context
                  developer.log('Showing confirmation dialog...',
                      name: 'LogoutTrace');
                  final confirmed = await showDialog<bool>(
                    context: pageContext, // Use the captured page context
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content:
                            const Text('Are you sure you want to log out?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              developer.log('Logout cancelled by user.',
                                  name: 'LogoutTrace');
                              Navigator.of(dialogContext)
                                  .pop(false); // Return false
                            },
                          ),
                          TextButton(
                            child: const Text('Log Out',
                                style: TextStyle(color: ThemeConstants.red)),
                            onPressed: () {
                              developer.log('Logout confirmed by user.',
                                  name: 'LogoutTrace');
                              Navigator.of(dialogContext)
                                  .pop(true); // Return true
                            },
                          ),
                        ],
                      );
                    },
                  );
                  developer.log('Confirmation dialog result: $confirmed',
                      name: 'LogoutTrace');

                  // IMPORTANT: Check if the widget is still mounted after await
                  if (!pageContext.mounted) {
                    developer.log(
                        'Logout aborted: Widget is no longer mounted after dialog.',
                        name: 'LogoutTrace');
                    return;
                  }

                  // If confirmed, proceed with logout
                  if (confirmed == true) {
                    developer.log('Proceeding with logout call...',
                        name: 'LogoutTrace');
                    try {
                      // Access AccountProvider using the captured page context
                      final accountProvider = Provider.of<AccountProvider>(
                          pageContext,
                          listen: false);
                      developer.log('Calling accountProvider.logout()...',
                          name: 'LogoutTrace');
                      await accountProvider.logout();
                      developer.log('accountProvider.logout() finished.',
                          name: 'LogoutTrace');
                      // Navigation to initial route will be handled by the listener in main.dart
                    } catch (e, stackTrace) {
                      developer.log(
                          'Error calling accountProvider.logout(): $e',
                          name: 'LogoutTrace',
                          error: e,
                          stackTrace: stackTrace);
                    }
                  } else {
                    developer.log('Logout aborted (not confirmed).',
                        name: 'LogoutTrace');
                  }
                  developer.log('--- Logout Process End (ProfilePage) ---',
                      name: 'LogoutTrace');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFollowersList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FollowersPage(
          title: 'Followers',
          isFollowers: true,
          userData: _userData,
        ),
      ),
    );
  }

  void _showFollowingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FollowersPage(
          title: 'Following',
          isFollowers: false,
          userData: _userData,
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
      color: Theme.of(context)
          .scaffoldBackgroundColor, // Use theme background instead of hardcoded white
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
  final Map<String, dynamic> userData;

  const _FollowersPage({
    required this.title,
    required this.isFollowers,
    required this.userData,
  });

  @override
  State<_FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<_FollowersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeUsers() {
    final count = widget.isFollowers
        ? widget.userData['followers']
        : widget.userData['following'];
    _allUsers = List.generate(
      count > 20 ? 20 : count,
      (index) => {
        'id': index,
        'name': 'User ${index + 1}',
        'username': 'user${index + 1}',
        'imageUrl': 'https://picsum.photos/seed/user$index/100',
        'isVerified': index % 5 == 0,
      },
    );
    _filteredUsers = List.from(_allUsers);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = user['name'].toString().toLowerCase();
        final username = user['username'].toString().toLowerCase();
        return name.contains(query) || username.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Search bar
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
          // User list
          Expanded(
            child: _filteredUsers.isEmpty
                ? const Center(
                    child: Text('No users found'),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user['imageUrl']),
                          onBackgroundImageError: (_, __) {},
                          child: const Icon(Icons.person),
                        ),
                        title: Row(
                          children: [
                            Text(user['name']),
                            if (user['isVerified'])
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
                        subtitle: Text('@${user['username']}'),
                        trailing: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isFollowers
                                ? ThemeConstants.greyLight
                                : ThemeConstants.primaryColor,
                            foregroundColor: widget.isFollowers
                                ? ThemeConstants.grey
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child:
                              Text(widget.isFollowers ? 'Remove' : 'Unfollow'),
                        ),
                        onTap: () {
                          // TODO: Navigate to user profile
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
