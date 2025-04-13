import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/story_viewer_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/sections/story_section.dart';

class AllUpdatesPage extends StatelessWidget {
  const AllUpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get users and their stories
    final Map<String, List<Map<String, dynamic>>> userStories =
        StorySection.getUserStories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Stats header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildStatCard(
                  context,
                  'Users',
                  userStories.length.toString(),
                  Icons.people,
                  ThemeConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  context,
                  'Updates',
                  _countAllStories(userStories).toString(),
                  Icons.update,
                  ThemeConstants.green,
                ),
              ],
            ),
          ),

          // Grid of user updates
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            childAspectRatio: 0.85,
            children: userStories.entries.map((entry) {
              final String username = entry.key;
              final List<Map<String, dynamic>> stories = entry.value;

              return _buildUserUpdatesCard(
                context,
                username: username,
                stories: stories,
                imageUrl: _getUserImageUrl(username),
                isLive: username == 'Emily J.' || username == 'David',
                hasMultipleStories: stories.length > 1,
                storiesCount: stories.length,
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Latest updates header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Latest Updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // List of all updates, ordered by time
          _buildAllUpdatesList(context, userStories),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserUpdatesCard(
    BuildContext context, {
    required String username,
    required List<Map<String, dynamic>> stories,
    required String imageUrl,
    required bool isLive,
    required bool hasMultipleStories,
    required int storiesCount,
  }) {
    return GestureDetector(
      onTap: () {
        _navigateToUserStories(
          context,
          username,
          stories,
          imageUrl,
          isLive,
        );
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with story indicator - Use fixed height container
            SizedBox(
              height: 100,
              child: Stack(
                clipBehavior: Clip.none, // Important to allow elements to overflow
                children: [
                  // Cover image
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      image: DecorationImage(
                        image: NetworkImage(
                          stories.first['imageUrl'] ??
                              'https://picsum.photos/200',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Live indicator
                  if (isLive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 8,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // User profile image
                  Positioned(
                    bottom: -20,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        gradient: hasMultipleStories
                            ? LinearGradient(
                                colors: [
                                  ThemeConstants.primaryColor,
                                  ThemeConstants.primaryColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(imageUrl),
                      ),
                    ),
                  ),

                  // Story count indicator
                  if (hasMultipleStories)
                    Positioned(
                      bottom: -10,
                      left: 64,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeConstants.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$storiesCount updates',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // User info section - Flexible container with reduced padding
            Flexible(
              child: Padding(
                // Reduced bottom padding to fix overflow
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Important to prevent overflow
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3), // Reduced spacing
                    Text(
                      stories.first['time'] ?? '1h ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 3), // Reduced spacing
                    Text(
                      stories.first['title'] ?? 'Story update',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllUpdatesList(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> userStories,
  ) {
    // Flatten all stories into a single list and sort by time
    final List<Map<String, dynamic>> allStories = [];

    userStories.forEach((username, stories) {
      for (final story in stories) {
        final Map<String, dynamic> storyWithUser = Map.from(story);
        storyWithUser['username'] = username;
        storyWithUser['userImage'] = _getUserImageUrl(username);
        allStories.add(storyWithUser);
      }
    });

    // Sort by time (most recent first)
    // This is a simple sort - in a real app you would parse the time properly
    allStories.sort((a, b) {
      final String timeA = a['time'] ?? '';
      final String timeB = b['time'] ?? '';
      return timeA.compareTo(timeB);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allStories.length,
      itemBuilder: (context, index) {
        final story = allStories[index];
        return _buildUpdateListItem(context, story);
      },
    );
  }

  Widget _buildUpdateListItem(
      BuildContext context, Map<String, dynamic> story) {
    return InkWell(
      onTap: () {
        _navigateToSingleStory(context, story);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Added to improve alignment
          children: [
            // User avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(story['userImage'] ?? ''),
            ),
            const SizedBox(width: 12),
            // Story info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded( // Wrap in Expanded to prevent overflow
                        child: Text(
                          story['username'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        story['time'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    story['title'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded( // Wrap location text in Expanded
                        child: Text(
                          story['location'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Move pill to avoid overflow
                      _buildMiniHonestyPill(story['honesty'] ?? 0),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Story image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.network(
                  story['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniHonestyPill(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$rating%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _countAllStories(Map<String, List<Map<String, dynamic>>> userStories) {
    int count = 0;
    userStories.forEach((_, stories) {
      count += stories.length;
    });
    return count;
  }

  String _getUserImageUrl(String username) {
    // Map usernames to avatar URLs
    switch (username) {
      case 'Emily J.':
        return 'https://picsum.photos/seed/user1/100/100';
      case 'Michael':
        return 'https://picsum.photos/seed/user2/100/100';
      case 'Sarah':
        return 'https://picsum.photos/seed/user3/100/100';
      case 'David':
        return 'https://picsum.photos/seed/user4/100/100';
      case 'Alex':
        return 'https://picsum.photos/seed/user5/100/100';
      default:
        return 'https://picsum.photos/seed/default/100/100';
    }
  }

  void _navigateToUserStories(
    BuildContext context,
    String username,
    List<Map<String, dynamic>> stories,
    String userImageUrl,
    bool isVerified,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: stories,
          username: username,
          userImageUrl: userImageUrl,
          isUserVerified: isVerified,
        ),
      ),
    );
  }

  void _navigateToSingleStory(
    BuildContext context,
    Map<String, dynamic> story,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: [story],
          username: story['username'] ?? '',
          userImageUrl: story['userImage'] ?? '',
          isUserVerified: story['isVerified'] ?? false,
        ),
      ),
    );
  }
}
