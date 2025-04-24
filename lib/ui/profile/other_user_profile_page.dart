import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/suggested_people_section.dart';

class OtherUserProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const OtherUserProfilePage({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _showDiscoverPeople = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // TODO: (DATABASE) Check if current user is following this profile
    // TODO: (DATABASE) Load user's posts, saved posts, and upvoted posts
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              title: Text('@${widget.userData['username']}'),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildUserInfoSection(),
                  const SizedBox(height: 16),
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
                    Tab(text: 'Posts', icon: Icon(Icons.article_outlined)),
                    Tab(text: 'Saved', icon: Icon(Icons.bookmark_border)),
                    Tab(text: 'Upvoted', icon: Icon(Icons.thumb_up_outlined)),
                  ],
                ),
                Theme.of(context).brightness == Brightness.dark,
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

  Widget _buildUserInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    widget.userData['profileImage'],
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
                    Text(
                      widget.userData['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${widget.userData['username']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeConstants.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Verification Badge instead of honesty rating
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeConstants.primaryColor.withOpacity(0.1),
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
          if (widget.userData['bio'].isNotEmpty)
            Text(
              widget.userData['bio'],
              style: const TextStyle(fontSize: 15),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                widget.userData['location'],
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, size: 14, color: ThemeConstants.grey),
              const SizedBox(width: 4),
              Text(
                'Joined ${widget.userData['joinDate']}',
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
                      widget.userData['followers'].toString(),
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
                      widget.userData['following'].toString(),
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
              _buildHonestyRating(widget.userData['honesty']),
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
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // TODO: (DATABASE) Update follow status in database
              // TODO: (DATABASE) Update follower counts for both users
              // TODO: (DATABASE) Add/remove from following/followers lists
              setState(() {
                _isFollowing = !_isFollowing;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isFollowing ? Colors.grey[300] : ThemeConstants.primaryColor,
              foregroundColor:
                  _isFollowing ? ThemeConstants.grey : Colors.white,
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
          ),
        ],
      ),
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

  void _showFollowersList() {
    // TODO: (DATABASE) Load and display followers list from database
  }

  void _showFollowingList() {
    // TODO: (DATABASE) Load and display following list from database
  }

  Widget _buildPostsTab() {
    return _buildEmptyStateWithCount(
      icon: Icons.article_outlined,
      message: 'Posts',
      count: widget.userData['posts'] ?? 0,
    );
  }

  Widget _buildSavedTab() {
    return _buildEmptyStateWithCount(
      icon: Icons.bookmark_border,
      message: 'Saved Posts',
      count: widget.userData['saved'] ?? 0,
    );
  }

  Widget _buildUpvotedTab() {
    return _buildEmptyStateWithCount(
      icon: Icons.thumb_up_outlined,
      message: 'Upvoted Posts',
      count: widget.userData['upvoted'] ?? 0,
    );
  }

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
            '$count ${message.toLowerCase()}',
            style: TextStyle(
              fontSize: 14,
              color: ThemeConstants.grey,
            ),
          ),
        ],
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
