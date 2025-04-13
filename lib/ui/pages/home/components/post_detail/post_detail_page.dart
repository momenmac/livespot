import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'dart:math' as math;
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:latlong2/latlong.dart';

class PostDetailPage extends StatefulWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String location;
  final String time;
  final int honesty;
  final int upvotes;
  final int comments;
  final bool isVerified;

  const PostDetailPage({
    super.key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.time,
    required this.honesty,
    required this.upvotes,
    required this.comments,
    required this.isVerified,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late int _upvotes;
  late int _downvotes;
  bool _hasUpvoted = false;
  bool _hasDownvoted = false;
  final TextEditingController _threadController = TextEditingController();
  late MapPageController _mapController;
  late bool _mapInitialized = false;
  late LatLng _postLocation;

  // Updated image URLs with reliable placeholders
  final List<String> _imageUrls = [
    'https://picsum.photos/seed/picsum1/800/600',
    'https://picsum.photos/seed/picsum2/800/600',
    'https://picsum.photos/seed/picsum3/800/600',
    'https://picsum.photos/seed/picsum4/800/600',
    'https://picsum.photos/seed/picsum5/800/600',
  ];

  // Mock threads data (renamed from comments)
  final List<Map<String, dynamic>> _threads = [
    {
      'author': 'Emily Johnson',
      'text':
          'This is really concerning. Has anyone heard if evacuations are being ordered yet?',
      'time': '45m ago',
      'likes': 24,
      'replies': 3,
      'isVerified': true,
      'distance': '0.3 mi away',
    },
    {
      'author': 'Michael Chen',
      'text':
          'I live close to the area and we\'ve already been told to prepare. The wind is picking up significantly.',
      'time': '32m ago',
      'likes': 18,
      'replies': 1,
      'isVerified': false,
      'distance': '0.1 mi away',
    },
    {
      'author': 'Sarah Williams',
      'text':
          'Just heard from a friend working at the emergency services - they\'re setting up shelters at the community center and high school.',
      'time': '25m ago',
      'likes': 32,
      'replies': 5,
      'isVerified': false,
      'distance': '0.5 mi away',
    },
    {
      'author': 'David Rodriguez',
      'text':
          'My brother works at the weather station, and he says this could be worse than initially predicted. Everyone please stay safe!',
      'time': '18m ago',
      'likes': 15,
      'replies': 2,
      'isVerified': true,
      'distance': '0.2 mi away',
    },
  ];

  @override
  void initState() {
    super.initState();
    _upvotes = widget.upvotes;
    _downvotes = widget.upvotes ~/ 5; // Just a mock value

    // Set a default location (this will be replaced with geocoding in a real app)
    _postLocation = LatLng(40.7128, -74.0060); // NYC coordinates as fallback

    // Initialize map controller
    _mapController = MapPageController();

    // Delay initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setCenterToPostLocation();
    });
  }

  // Helper method to set map center to post location
  void _setCenterToPostLocation() {
    try {
      _mapController.setContext(context);
      _mapController.initializeLocation();

      // Use a longer delay to ensure map is fully initialized before moving
      Future.delayed(const Duration(milliseconds: 1000), () {
        // Use the available method to center on user location as fallback
        _mapController.centerOnUserLocation();

        // Since we can't add markers or center on specific locations with the current controller,
        // we'll use a fixed UI overlay to represent the post location
        setState(() {
          _mapInitialized = true;
        });
      });
    } catch (e) {
      debugPrint('Error setting map location: $e');
    }
  }

  void _handleUpvote() {
    setState(() {
      if (_hasUpvoted) {
        _upvotes--;
        _hasUpvoted = false;
      } else {
        _upvotes++;
        _hasUpvoted = true;
        if (_hasDownvoted) {
          _downvotes--;
          _hasDownvoted = false;
        }
      }
    });
  }

  void _handleDownvote() {
    setState(() {
      if (_hasDownvoted) {
        _downvotes--;
        _hasDownvoted = false;
      } else {
        _downvotes++;
        _hasDownvoted = true;
        if (_hasUpvoted) {
          _upvotes--;
          _hasUpvoted = false;
        }
      }
    });
  }

  void _addThread() {
    if (_threadController.text.trim().isNotEmpty) {
      setState(() {
        _threads.insert(0, {
          'author': 'You',
          'text': _threadController.text,
          'time': 'Just now',
          'likes': 0,
          'replies': 0,
          'isVerified': false,
          'distance': '0.0 mi away',
        });
        _threadController.clear();
      });
      // Hide keyboard
      FocusScope.of(context).unfocus();
    }
  }

  String _getRandomImageUrl() {
    final random = math.Random();
    return _imageUrls[random.nextInt(_imageUrls.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildOptionsSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Post content in a scrollable area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post header with author info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Author avatar
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: ThemeConstants.primaryColor,
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        // Author name and time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'News Network',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (widget.isVerified)
                                    const SizedBox(width: 4),
                                  if (widget.isVerified)
                                    Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: ThemeConstants.primaryColor,
                                    ),
                                ],
                              ),
                              Text(
                                widget.time,
                                style: TextStyle(
                                  color: ThemeConstants.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Follow button
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: ThemeConstants.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: ThemeConstants.primaryColor),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Follow'),
                        ),
                      ],
                    ),
                  ),

                  // Post image (now using a real image)
                  SizedBox(
                    width: double.infinity,
                    height: 240,
                    child: Image.network(
                      _getRandomImageUrl(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: ThemeConstants.greyLight,
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 64,
                              color: ThemeConstants.grey.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Post title and content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        // Expanded description (simulated)
                        const SizedBox(height: 8),
                        Text(
                          "Meteorologists have upgraded the storm to a category 3 hurricane, with sustained winds of over 120 mph. "
                          "Coastal areas are particularly at risk of storm surge, which could reach heights of 9-12 feet above normal tide levels. "
                          "Authorities are urging residents in low-lying areas to evacuate immediately and others to complete storm preparations "
                          "as soon as possible.",
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location and honesty rating
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: ThemeConstants.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: ThemeConstants.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildHonestyRating(widget.honesty),
                      ],
                    ),
                  ),

                  // Map Preview Section (UPDATED)
                  _buildMapSection(),

                  // Action buttons (upvote, downvote, thread, share)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Upvote button (changed icon)
                        _buildActionButton(
                          icon: Icons.arrow_upward,
                          iconFilled: Icons.arrow_upward,
                          label: '$_upvotes',
                          isActive: _hasUpvoted,
                          onPressed: _handleUpvote,
                        ),
                        // Downvote button (changed icon)
                        _buildActionButton(
                          icon: Icons.arrow_downward,
                          iconFilled: Icons.arrow_downward,
                          label: '$_downvotes',
                          isActive: _hasDownvoted,
                          onPressed: _handleDownvote,
                        ),
                        // Thread button
                        _buildActionButton(
                          icon: Icons.forum_outlined,
                          iconFilled: Icons.forum,
                          label: '${widget.comments}',
                          onPressed: () {
                            // Focus on the thread field
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
                        ),
                        // Share button
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          iconFilled: Icons.share,
                          label: TextStrings.share,
                          onPressed: () {
                            // Implement share functionality
                          },
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(height: 1),

                  // Threads header (renamed from Comments)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_threads.length} Threads',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.sort, size: 16),
                          label: const Text('Sort by'),
                          style: TextButton.styleFrom(
                            foregroundColor: ThemeConstants.grey,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Threads list (renamed from Comments)
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _threads.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      return _buildThreadItem(thread);
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Thread input field (renamed from Comment) - UPDATED with SafeArea
          SafeArea(
            minimum: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: ThemeConstants.greyLight, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12), // Increased vertical padding
              child: Row(
                children: [
                  // Author avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ThemeConstants.grey.withOpacity(0.2),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Thread text field (renamed from Comment)
                  Expanded(
                    child: TextField(
                      controller: _threadController,
                      decoration: InputDecoration(
                        hintText: 'Start a thread...',
                        hintStyle: TextStyle(color: ThemeConstants.grey),
                        border: InputBorder.none,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  // Post button
                  TextButton(
                    onPressed: _addThread,
                    style: TextButton.styleFrom(
                      foregroundColor: ThemeConstants.primaryColor,
                    ),
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Add resizeToAvoidBottomInset to handle keyboard properly
      resizeToAvoidBottomInset: true,
    );
  }

  Widget _buildThreadItem(Map<String, dynamic> thread) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: ThemeConstants.grey.withOpacity(0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          // Thread content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name, verification, and distance
                Row(
                  children: [
                    Text(
                      thread['author'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (thread['isVerified']) const SizedBox(width: 4),
                    if (thread['isVerified'])
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: ThemeConstants.primaryColor,
                      ),
                    const Spacer(),
                    // Distance indicator
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 12,
                          color: ThemeConstants.grey,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          thread['distance'],
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeConstants.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  thread['time'],
                  style: TextStyle(
                    color: ThemeConstants.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Thread text
                Text(
                  thread['text'],
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                // Thread actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Handle like
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: ThemeConstants.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${thread['likes']}',
                            style: TextStyle(
                              color: ThemeConstants.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // Handle reply
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: ThemeConstants.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: ThemeConstants.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (thread['replies'] > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: GestureDetector(
                          onTap: () {
                            // Show replies
                          },
                          child: Text(
                            'View ${thread['replies']} ${thread['replies'] == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              color: ThemeConstants.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required IconData iconFilled,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              isActive ? iconFilled : icon,
              size: 20,
              color:
                  isActive ? ThemeConstants.primaryColor : ThemeConstants.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isActive
                    ? ThemeConstants.primaryColor
                    : ThemeConstants.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
            '$rating% ${TextStrings.honestyRating}',
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

  Widget _buildOptionsSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Save Post'),
            onTap: () {
              Navigator.pop(context);
              // Handle save post
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report Post'),
            onTap: () {
              Navigator.pop(context);
              // Handle report post
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Not Interested'),
            onTap: () {
              Navigator.pop(context);
              // Handle not interested
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share Post'),
            onTap: () {
              Navigator.pop(context);
              // Handle share post
            },
          ),
        ],
      ),
    );
  }

  // New method to show expanded map view with proper marker
  void _showExpandedMapView(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: ThemeConstants.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Location header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.place, color: ThemeConstants.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.location,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),

                // Expanded map with proper marker
                Expanded(
                  child: MapView(
                    controller: _mapController,
                    onTap: () {},
                  ),
                ),

                // Related events nearby
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Related Events Nearby',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildNearbyEvent(
                        'Storm Shelter Open',
                        'Community Center',
                        '0.4 miles away',
                      ),
                      _buildNearbyEvent(
                        'Emergency Supply Distribution',
                        'City Hall',
                        '0.7 miles away',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNearbyEvent(String title, String location, String distance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeConstants.greyLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeConstants.primaryColorLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, color: ThemeConstants.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  location,
                  style: TextStyle(
                    color: ThemeConstants.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            distance,
            style: TextStyle(
              color: ThemeConstants.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Location text
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: ThemeConstants.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.location,
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeConstants.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Real map implementation with marker
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThemeConstants.greyLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Actual map view widget with proper marker
                MapView(
                  controller: _mapController,
                  onTap: () {
                    // Do nothing on tap
                  },
                ),

                // Only show the centered pin as fallback when map isn't initialized
                if (!_mapInitialized)
                  const Center(
                    child: Icon(
                      Icons.place,
                      color: ThemeConstants.red,
                      size: 36,
                    ),
                  ),

                // Show more button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showExpandedMapView(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.fullscreen, size: 18),
                    label: const Text('Show More'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _threadController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
