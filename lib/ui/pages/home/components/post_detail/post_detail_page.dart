import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:flutter_application_2/ui/pages/posts/create_post_page.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/utils/time_formatter.dart';
import 'package:flutter_application_2/ui/widgets/post_options_popup.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'dart:io';
import 'package:flutter_application_2/services/location/location_service.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/media/media_preview_page.dart';
import 'package:video_player/video_player.dart';

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
  final Post? post; // Add post parameter
  final String? distance; // Add optional distance parameter
  final String? authorName; // Add optional author name parameter
  final int? downvotes; // Add optional downvotes parameter
  final int?
      originalPostId; // Add originalPostId for tracking parent post ID for related posts

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
    this.post, // Make it optional for backward compatibility
    this.distance,
    this.authorName,
    this.downvotes, // Optional downvotes parameter
    this.originalPostId, // Optional original post ID for related posts
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  // Initialize with default values from widget to avoid LateInitializationError
  int _upvotes = 0;
  int _downvotes = 0;
  bool _hasUpvoted = false;
  bool _hasDownvoted = false;
  late MapPageController _mapController;
  bool _mapInitialized = false; // Remove 'late' as it's initialized here
  bool _isLoadingVote = false; // Add loading state for vote operations
  bool _isLoading = false; // Add loading state for save operations

  // Add state for related posts
  List<Post> _relatedPosts = [];
  bool _isLoadingRelatedPosts = false;

  // Video player controller
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with values from widget
    _upvotes = widget.upvotes;
    // Initialize downvotes from widget if available
    _downvotes = widget.downvotes ?? 0;

    // Debug prints for Arabic text
    developer.log('🔍 Initializing Post Detail Page with:',
        name: 'ArabicDebug');
    developer.log('Title: "${widget.title}"', name: 'ArabicDebug');
    developer.log('Description: "${widget.description}"', name: 'ArabicDebug');
    developer.log('Location: "${widget.location}"', name: 'ArabicDebug');

    // Print raw bytes for debugging
    developer.log('Title bytes: ${widget.title.codeUnits}',
        name: 'ArabicDebug');
    developer.log('Description bytes: ${widget.description.codeUnits}',
        name: 'ArabicDebug');

    _initializePostData();
    _initializeMap();
    // Add related posts loading
    _loadRelatedPosts();
    _initializeVideoPlayer();
  }

  void _initializePostData() async {
    // Add debug prints for text content
    debugPrint('🔍 Post Title: ${widget.title}');
    debugPrint('🔍 Post Description: ${widget.description}');
    debugPrint('🔍 Post Location: ${widget.location}');

    // Print the raw bytes of the text to check encoding
    debugPrint('📝 Title bytes: ${widget.title.codeUnits}');
    debugPrint('📝 Description bytes: ${widget.description.codeUnits}');

    // Use real post data if available
    if (widget.post != null) {
      debugPrint('📦 Post object data:');
      debugPrint('   - ID: ${widget.post!.id}');
      debugPrint('   - Title: ${widget.post!.title}');
      debugPrint('   - Content: ${widget.post!.content}');

      setState(() {
        // Initialize vote counts from the actual post data
        _upvotes = widget.post!.upvotes;
        _downvotes = widget.post!.downvotes;

        // Initialize vote state from the post's userVote field
        if (widget.post!.userVote == 1) {
          _hasUpvoted = true;
          _hasDownvoted = false;
        } else if (widget.post!.userVote == -1) {
          _hasUpvoted = false;
          _hasDownvoted = true;
        } else {
          _hasUpvoted = false;
          _hasDownvoted = false;
        }
      });

      // Always recalculate distance from user's current location if not set or zero
      if ((widget.post!.distance == 0.0 || widget.post!.distance.isNaN)) {
        final locationService = LocationService();
        try {
          final userPosition = await locationService.getCurrentPosition();
          final double calculatedDistance = locationService.calculateDistance(
            userPosition.latitude,
            userPosition.longitude,
            widget.post!.latitude,
            widget.post!.longitude,
          );
          setState(() {
            widget.post!.distance = calculatedDistance; // Store in meters
          });
        } catch (e) {
          // Could not get user location, leave distance as 0
        }
      }

      // Log initialization for debugging
      developer.log(
        'Initialized post detail with: upvotes=$_upvotes, downvotes=$_downvotes, '
        'userVote=${widget.post!.userVote}, hasUpvoted=$_hasUpvoted, hasDownvoted=$_hasDownvoted, distance=${widget.post!.distance}',
        name: 'PostDetailPage',
      );
    }
  }

  void _initializeMap() {
    // Initialize map controller without automatic location initialization
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

      // If we have post coordinates, use them directly without calling initializeLocation
      if (widget.post?.latitude != null && widget.post?.longitude != null) {
        // Set initialized to true immediately to prevent any automatic centering
        setState(() {
          _mapInitialized = true;
        });

        // Set the location and marker immediately without delay
        _mapController.centerOnLocation(
            widget.post!.latitude, widget.post!.longitude);

        // Get the category from the post, or use a default
        String category = widget.post?.category.toLowerCase() ?? 'news';

        // Set a custom marker with appropriate styling based on the category
        _mapController.setCustomMarker(
          latitude: widget.post!.latitude,
          longitude: widget.post!.longitude,
          eventType: category,
          description: widget.post?.title ?? widget.title,
        );
      } else {
        // Only for fallback when no post coordinates are available
        _mapController.initializeLocation();
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _mapController.centerOnUserLocation();
            setState(() {
              _mapInitialized = true;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error setting map location: $e');
      setState(() {
        _mapInitialized = true; // Set to true even on error to show the map
      });
    }
  }

  // Handle upvote with proper API interaction
  void _handleUpvote() async {
    if (_isLoadingVote) return; // Prevent multiple simultaneous votes

    setState(() => _isLoadingVote = true);

    // Get the posts provider
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    final int previousVote = widget.post!.userVote;

    // For upvotes, we're using isUpvote=true
    // If already upvoted, this would normally remove the upvote (neutral)
    // If not upvoted, it would add an upvote
    final bool isUpvote = true;

    // Optimistically update UI
    setState(() {
      if (_hasUpvoted) {
        // Removing an upvote
        _upvotes--;
        _hasUpvoted = false;
      } else {
        // Adding an upvote
        _upvotes++;
        // If was downvoted before, also remove the downvote
        if (_hasDownvoted) {
          _downvotes--;
          _hasDownvoted = false;
        }
        _hasUpvoted = true;
      }
    });

    try {
      // Check if this is a related post and log the attempt
      if (widget.post!.relatedPostId != null) {
        debugPrint(
            'Upvoting related post ${widget.post!.id} with original post ID ${widget.post!.relatedPostId}');
      } else {
        debugPrint('Upvoting main post ${widget.post!.id}');
      }

      // Call the API with the correct parameters - the provider will handle the related post case
      final result = await postsProvider.voteOnPost(widget.post!, isUpvote);

      if (!mounted) return; // Add check before using context

      if (result.isNotEmpty) {
        // Log success for debugging
        developer.log(
          'Successfully updated vote: postId=${widget.post!.id}, isUpvote=true',
          name: 'PostDetailPage',
        );

        // Update the post's vote counts from the result
        setState(() {
          _upvotes = result['upvotes'];
          _downvotes = result['downvotes'];

          // Update the underlying post object
          widget.post!.upvotes = result['upvotes'];
          widget.post!.downvotes = result['downvotes'];
          widget.post!.honestyScore = result['honesty_score'];

          // Set the user vote based on the action taken
          widget.post!.userVote = _hasUpvoted ? 1 : (_hasDownvoted ? -1 : 0);
        });
      } else {
        // Revert UI changes if API call failed
        setState(() {
          // Reset state based on the previous vote value
          if (previousVote == 1) {
            _hasUpvoted = true;
            _hasDownvoted = false;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          } else if (previousVote == -1) {
            _hasUpvoted = false;
            _hasDownvoted = true;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          } else {
            _hasUpvoted = false;
            _hasDownvoted = false;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          }
        });

        // Show error message
        if (mounted) {
          // Add check before using context
          ResponsiveSnackBar.showError(
            context: context,
            message: postsProvider.errorMessage ?? 'Failed to update vote',
          );
        }
      }
    } catch (e) {
      // Revert UI on exception and show error
      setState(() {
        // Reset to previous vote state
        _hasUpvoted = previousVote == 1;
        _hasDownvoted = previousVote == -1;
        _upvotes = widget.post!.upvotes;
        _downvotes = widget.post!.downvotes;
      });

      if (mounted) {
        // Add check before using context
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      setState(() => _isLoadingVote = false);
    }
  }

  // Handle downvote with proper API interaction
  void _handleDownvote() async {
    if (_isLoadingVote) return; // Prevent multiple simultaneous votes

    setState(() => _isLoadingVote = true);

    // Get the posts provider
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    final int previousVote = widget.post!.userVote;

    // For downvotes, we need to handle differently
    // If already downvoted, we're removing the downvote (neutral)
    // If not downvoted, we're adding a downvote
    // The provider expects isUpvote=false for downvotes
    final bool isUpvote = false;

    // Optimistically update UI
    setState(() {
      if (_hasDownvoted) {
        // Removing a downvote
        _downvotes--;
        _hasDownvoted = false;
      } else {
        // Adding a downvote
        _downvotes++;
        // If was upvoted before, also remove the upvote
        if (_hasUpvoted) {
          _upvotes--;
          _hasUpvoted = false;
        }
        _hasDownvoted = true;
      }
    });

    try {
      // Check if this is a related post and log the attempt
      if (widget.post!.relatedPostId != null) {
        debugPrint(
            'Downvoting related post ${widget.post!.id} with original post ID ${widget.post!.relatedPostId}');
      } else {
        debugPrint('Downvoting main post ${widget.post!.id}');
      }

      // Call the API with the correct parameters
      // The provider will handle using the original post ID if this is a related post
      final result = await postsProvider.voteOnPost(widget.post!, isUpvote);

      if (result.isNotEmpty) {
        // Log success for debugging
        developer.log(
          'Successfully updated vote: postId=${widget.post!.id}, isDownvote=true',
          name: 'PostDetailPage',
        );

        // Update the post's vote counts from the result
        setState(() {
          _upvotes = result['upvotes'];
          _downvotes = result['downvotes'];

          // Update the underlying post object
          widget.post!.upvotes = result['upvotes'];
          widget.post!.downvotes = result['downvotes'];
          widget.post!.honestyScore = result['honesty_score'];

          // Set the user vote based on the action taken
          widget.post!.userVote = _hasDownvoted ? -1 : (_hasUpvoted ? 1 : 0);
        });
      } else {
        // Revert UI changes if API call failed
        setState(() {
          // Reset state based on the previous vote value
          if (previousVote == 1) {
            _hasUpvoted = true;
            _hasDownvoted = false;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          } else if (previousVote == -1) {
            _hasUpvoted = false;
            _hasDownvoted = true;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          } else {
            _hasUpvoted = false;
            _hasDownvoted = false;
            _upvotes = widget.post!.upvotes;
            _downvotes = widget.post!.downvotes;
          }
        });

        // Show error message
        if (mounted) {
          // Add check before using context
          ResponsiveSnackBar.showError(
            context: context,
            message: postsProvider.errorMessage ?? 'Failed to update vote',
          );
        }
      }
    } catch (e) {
      // Revert UI on exception and show error
      setState(() {
        // Reset to previous vote state
        _hasUpvoted = previousVote == 1;
        _hasDownvoted = previousVote == -1;
        _upvotes = widget.post!.upvotes;
        _downvotes = widget.post!.downvotes;
      });

      if (mounted) {
        // Add check before using context
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      setState(() => _isLoadingVote = false);
    }
  }

  // Handle save post functionality with improved error handling
  void _toggleSavePost() async {
    if (_isLoading || widget.post == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the posts provider
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // Optimistically update UI for better user experience
      final previousSavedState = widget.post!.isSaved ?? false;
      setState(() {
        widget.post!.isSaved = !previousSavedState;
      });

      // Call API through provider
      final success = await postsProvider.toggleSavePost(widget.post!.id);

      if (!mounted) return; // Add check before using context

      if (!success) {
        // Revert on API failure
        setState(() {
          widget.post!.isSaved = previousSavedState;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                postsProvider.errorMessage ?? 'Failed to update save status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle exceptions
      setState(() {
        widget.post!.isSaved = !(widget.post!.isSaved ?? false);
      });

      if (mounted) {
        // Add check before using context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  // Enhanced method to get appropriate media URL
  String _getImageUrl() {
    // First try: Check if we have a valid post object with an imageUrl
    if (widget.post?.imageUrl != null && widget.post!.imageUrl.isNotEmpty) {
      return _getFixedImageUrl(widget.post!.imageUrl);
    }

    // Second try: Check if the post has media URLs
    if (widget.post?.hasMedia == true && widget.post!.mediaUrls.isNotEmpty) {
      return _getFixedImageUrl(widget.post!.mediaUrls.first);
    }

    // Third try: Use the directly provided imageUrl
    if (widget.imageUrl.isNotEmpty) {
      return _getFixedImageUrl(widget.imageUrl);
    }

    // Final fallback: Use a placeholder image
    return 'https://via.placeholder.com/400x200?text=No+Image';
  }

  // Helper method to check if media is a video
  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm');
  }

  // Helper method to check if a string is a file path or URL
  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  // Initialize video player for the main media
  void _initializeVideoPlayer() async {
    final String mediaUrl = _getImageUrl();
    if (_isVideoFile(mediaUrl)) {
      try {
        if (_isFilePath(mediaUrl)) {
          _videoController = VideoPlayerController.file(File(mediaUrl));
        } else {
          _videoController = VideoPlayerController.network(mediaUrl);
        }

        await _videoController!.initialize();
        setState(() {
          _isVideoInitialized = true;
        });
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  // Widget to display either network image, file image, or video
  Widget _buildMediaWidget(String mediaUrl,
      {BoxFit fit = BoxFit.cover, bool isClickable = true}) {
    final String fixedMediaUrl = _getFixedImageUrl(mediaUrl);

    Widget mediaWidget;

    if (_isVideoFile(fixedMediaUrl)) {
      // Video widget
      mediaWidget = _buildVideoThumbnail(fixedMediaUrl, fit);
    } else {
      // Image widget
      if (_isFilePath(fixedMediaUrl)) {
        mediaWidget = Image.file(
          File(fixedMediaUrl),
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading file image: $error');
            return _buildImageErrorPlaceholder();
          },
        );
      } else {
        mediaWidget = Image.network(
          fixedMediaUrl,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading network image: $error');
            return _buildImageErrorPlaceholder();
          },
        );
      }
    }

    if (isClickable) {
      return GestureDetector(
        onTap: () => _openMediaPreview(fixedMediaUrl),
        child: mediaWidget,
      );
    }

    return mediaWidget;
  }

  // Build video thumbnail with play button overlay
  Widget _buildVideoThumbnail(String videoUrl, BoxFit fit) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Video thumbnail or placeholder
        _videoController != null && _isVideoInitialized
            ? VideoPlayer(_videoController!)
            : Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(
                    Icons.video_file,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),
        // Play button overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
        ),
      ],
    );
  }

  // Open media preview page
  void _openMediaPreview(String mediaUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(
          mediaUrl: mediaUrl,
          title: widget.title,
          isVideo: _isVideoFile(mediaUrl),
        ),
      ),
    );
  }

  // Widget for showing a placeholder when image loading fails
  Widget _buildImageErrorPlaceholder() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.grey[800] : ThemeConstants.greyLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 48,
              color: isDarkMode ? Colors.grey[600] : ThemeConstants.grey,
            ),
            const SizedBox(height: 8),
            Text(
              "Image unavailable",
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format distance properly in km or m
  String _formatDistance(double? distanceInMeters) {
    // Always use post.distance in meters if available
    if (widget.post?.distance != null && widget.post!.distance > 0) {
      double meters = widget.post!.distance;
      if (meters < 1000) {
        return '${meters.toInt()} m';
      } else {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
    }
    // Then check if we're given a valid distance parameter
    if (distanceInMeters != null && distanceInMeters > 0) {
      if (distanceInMeters < 1000) {
        return '${distanceInMeters.toInt()} m';
      } else {
        return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
      }
    }
    // Try to extract distance from the distance string if available (legacy)
    if (widget.distance != null && widget.distance!.isNotEmpty) {
      final RegExp regex = RegExp(r'(\d+\.?\d*)');
      final match = regex.firstMatch(widget.distance!);
      if (match != null) {
        try {
          final double meters = double.parse(match.group(1)!);
          if (meters < 1000) {
            return '${meters.toInt()} m';
          } else {
            return '${(meters / 1000).toStringAsFixed(1)} km';
          }
        } catch (e) {
          // Fall through to default
        }
      }
    }
    // Default: show 300m instead of "Nearby"
    return '300 m';
  }

  // Navigate to the user's profile
  void _navigateToUserProfile() {
    // Don't navigate for anonymous users
    if (widget.post != null && widget.post!.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot view anonymous user's profile"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if we have a post with author information
    if (widget.post != null) {
      // Create the user data map required by OtherUserProfilePage
      Map<String, dynamic> userData = {
        'id': widget.post!.author.id,
        'username': widget.post!.authorName,
        'profile_pic': widget.post!.authorProfilePic ?? '', // Ensure not null
        'is_verified': widget.post?.isAuthorVerified ?? widget.isVerified,
      };

      // Add extra fields if they are available
      if (widget.post!.author.fullName != null &&
          widget.post!.author.fullName!.isNotEmpty) {
        userData['full_name'] = widget.post!.author.fullName;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(userData: userData),
        ),
      );
    } else if (widget.authorName != null && widget.authorName!.isNotEmpty) {
      // Fallback if we only have the author name
      Map<String, dynamic> userData = {
        'username': widget.authorName,
        'is_verified': widget.isVerified,
        'profile_pic': '', // Provide empty string as default
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(userData: userData),
        ),
      );
    } else {
      // Show a message if we can't navigate to the profile
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot view anonymous user's profile"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Update method to load related posts using the server's endpoint
  Future<void> _loadRelatedPosts() async {
    if (!mounted || widget.post == null) return;

    setState(() {
      _isLoadingRelatedPosts = true;
    });

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // Use the dedicated API endpoint for related posts
      // This works for both main posts and related posts
      _relatedPosts = await postsProvider.getRelatedPosts(widget.post!.id);

      // Filter out the current post from the results
      _relatedPosts =
          _relatedPosts.where((p) => p.id != widget.post!.id).toList();

      developer.log(
          'Loaded ${_relatedPosts.length} related posts for post ${widget.post!.id}',
          name: 'PostDetailPage');
    } catch (e) {
      debugPrint('Error loading related posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRelatedPosts = false;
        });
      }
    }
  }

  // Add method to check if user is within 100m of the post
  bool _isWithinRange() {
    if (widget.post?.distance == null) return false;
    // Convert distance to meters if needed and check if within 100m
    double distanceInMeters = widget.post!.distance;
    return distanceInMeters <= 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final honestyScore = widget.post?.honestyScore ?? widget.honesty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(77), // Replaced withOpacity
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(77), // Replaced withOpacity
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // Show post options popup
                showModalBottomSheet(
                  context: context,
                  builder: (context) => PostOptionsPopup(
                    post: widget.post,
                    postId: widget.post?.id ?? -1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      // Add floating action button
      floatingActionButton: widget.post != null
          ? FloatingActionButton(
              onPressed: _isWithinRange()
                  ? () {
                      // Navigate to create post screen with thread info
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostPage(
                            // If this is a main post, use its ID
                            // If this is already a related post, use its main post's ID
                            relatedToPostId:
                                widget.post!.relatedPostId ?? widget.post!.id,
                          ),
                        ),
                      );
                    }
                  : null, // Disable button if not within range
              backgroundColor:
                  _isWithinRange() ? ThemeConstants.primaryColor : Colors.grey,
              tooltip: _isWithinRange()
                  ? 'Add to Thread'
                  : 'You must be within 100m to add to this thread',
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main post image/video - now clickable
            Stack(
              children: [
                // Media with shimmer loading placeholder
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: _buildMediaWidget(
                    _getImageUrl(),
                    fit: BoxFit.cover,
                  ),
                ),
                // Dark gradient overlay at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(
                              178), // Replaced withOpacity (0.7 * 255 = 178.5)
                        ],
                      ),
                    ),
                  ),
                ),
                // Post details overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _navigateToUserProfile,
                        child: CircleAvatar(
                          backgroundImage:
                              widget.post?.authorProfilePic != null &&
                                      widget.post!.authorProfilePic!.isNotEmpty
                                  ? NetworkImage(_getFixedImageUrl(
                                      widget.post!.authorProfilePic!))
                                  : null,
                          radius: 18,
                          child: (widget.post?.authorProfilePic == null ||
                                  widget.post!.authorProfilePic!.isEmpty)
                              ? const Icon(Icons.person)
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
                                GestureDetector(
                                  onTap: _navigateToUserProfile,
                                  child: Text(
                                    // Use getDisplayName helper to respect isAnonymous flag
                                    widget.post?.getDisplayName() ??
                                        widget.authorName ??
                                        "Anonymous",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (widget.post?.isAuthorVerified == true ||
                                    widget.isVerified)
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
                            Text(
                              widget.post?.timePosted != null
                                  ? TimeFormatter.getFormattedTime(
                                      widget.post!.timePosted)
                                  : widget.time,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeConstants.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.post?.distance != null
                                  ? _formatDistance(widget.post!.distance *
                                      1000) // Convert miles to meters
                                  : _formatDistance(
                                      300), // Default reasonable distance if none provided
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
            // Post content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),

                  // Honesty Score Indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getHonestyScoreColor(honestyScore).withAlpha(
                          26), // Replaced withOpacity (0.1 * 255 = 25.5)
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getHonestyScoreColor(honestyScore),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: _getHonestyScoreColor(honestyScore),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Honesty: $honestyScore%',
                          style: TextStyle(
                            color: _getHonestyScoreColor(honestyScore),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Engagement metrics
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // Upvotes - Using arrow up instead of thumb up
                      GestureDetector(
                        onTap: widget.post != null ? _handleUpvote : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasUpvoted
                                  ? Icons.arrow_upward
                                  : Icons.arrow_upward_outlined,
                              color: _hasUpvoted
                                  ? ThemeConstants.primaryColor
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            _isLoadingVote
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    '$_upvotes',
                                    style: TextStyle(
                                      color: _hasUpvoted
                                          ? ThemeConstants.primaryColor
                                          : Colors.grey,
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Downvotes - Using arrow down instead of thumb down
                      GestureDetector(
                        onTap: widget.post != null ? _handleDownvote : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasDownvoted
                                  ? Icons.arrow_downward
                                  : Icons.arrow_downward_outlined,
                              color: _hasDownvoted
                                  ? Colors.redAccent
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            _isLoadingVote
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    '$_downvotes',
                                    style: TextStyle(
                                      color: _hasDownvoted
                                          ? Colors.redAccent
                                          : Colors.grey,
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Comments count - now shows thread count
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.comment_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_relatedPosts.length}', // Show thread count instead of comments
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      // Share and Save buttons
                      _buildAdditionalActionButtons(),
                    ],
                  ),
                ],
              ),
            ),
            // Location map
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  ignoring: false, // Allow user interaction with map
                  child: !_mapInitialized
                      ? const Center(child: CircularProgressIndicator())
                      : MapWidget(mapController: _mapController),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Related posts section
            if (widget.post != null &&
                (widget.post!.hasRelatedPosts || _relatedPosts.isNotEmpty))
              _buildRelatedPostsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Updated method to build thread section - more like comments
  Widget _buildRelatedPostsSection() {
    // Check if current post is a related post (has a parent)
    final bool isChildPost = widget.post?.relatedPostId != null;
    final String sectionTitle =
        isChildPost ? 'Thread' : 'Thread (${_relatedPosts.length})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Add "View Main Post" button if this is a related post
              if (isChildPost)
                TextButton.icon(
                  onPressed: _navigateToMainPost,
                  icon: Icon(
                    Icons.keyboard_arrow_up,
                    color: ThemeConstants.primaryColor,
                    size: 18,
                  ),
                  label: Text(
                    'Main Post',
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _isLoadingRelatedPosts
            ? const Center(child: CircularProgressIndicator())
            : _relatedPosts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      isChildPost
                          ? 'No other posts in this thread'
                          : 'No thread posts found',
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _relatedPosts.length,
                    itemBuilder: (context, index) {
                      final relatedPost = _relatedPosts[index];
                      return _buildRelatedPostItem(relatedPost);
                    },
                  ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Add method to navigate to main post
  void _navigateToMainPost() async {
    if (widget.post?.relatedPostId == null) return;

    try {
      // Fetch the main post details
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final mainPost =
          await postsProvider.fetchPostDetails(widget.post!.relatedPostId!);

      if (mainPost != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              title: mainPost.title,
              description: mainPost.content,
              imageUrl: mainPost.imageUrl,
              location: mainPost.location.address ?? "Unknown location",
              time: TimeFormatter.getFormattedTime(mainPost.createdAt),
              honesty: mainPost.honestyScore,
              upvotes: mainPost.upvotes,
              comments: 0,
              isVerified: mainPost.isVerifiedLocation,
              post: mainPost,
              authorName: mainPost.getDisplayName(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load main post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Updated method to build a thread post item with video support
  Widget _buildRelatedPostItem(Post post) {
    final bool isMainPost = post.relatedPostId == null;

    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                title: post.title,
                description: post.content,
                imageUrl: post.imageUrl,
                location: post.location.address ?? "Unknown location",
                time: TimeFormatter.getFormattedTime(post.createdAt),
                honesty: post.honestyScore,
                upvotes: post.upvotes,
                downvotes: post.downvotes,
                comments: 0,
                isVerified: post.isVerifiedLocation,
                post: post,
                authorName: post.getDisplayName(),
                distance: _formatDistance(post.distance * 1000),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMainPost
                ? (Theme.of(context).brightness == Brightness.dark
                    ? ThemeConstants.primaryColor.withAlpha(26)
                    : ThemeConstants.primaryColor.withAlpha(13))
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMainPost
                  ? ThemeConstants.primaryColor.withAlpha(77)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!),
              width: isMainPost ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author and time row
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post.authorProfilePic != null &&
                            post.authorProfilePic!.isNotEmpty
                        ? NetworkImage(
                            _getFixedImageUrl(post.authorProfilePic!))
                        : null,
                    radius: 12,
                    child: (post.authorProfilePic == null ||
                            post.authorProfilePic!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.getDisplayName(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (post.isAuthorVerified)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  size: 12,
                                  color: ThemeConstants.primaryColor,
                                ),
                              ),
                            if (isMainPost)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeConstants.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'MAIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          TimeFormatter.getFormattedTime(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ThemeConstants.primaryColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDistance(post.distance * 1000),
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Post title
              Text(
                post.title,
                style: TextStyle(
                  fontWeight: isMainPost ? FontWeight.bold : FontWeight.w600,
                  fontSize: isMainPost ? 15 : 14,
                  color: isMainPost ? ThemeConstants.primaryColor : null,
                ),
              ),
              const SizedBox(height: 4),
              // Post content (truncated)
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              // Show media if available
              if (post.hasMedia) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _buildMediaWidget(post.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Post stats row
              Row(
                children: [
                  // Upvotes
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_outlined,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${post.upvotes}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Honesty score
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getHonestyScoreColor(post.honestyScore)
                          .withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${post.honestyScore}%',
                      style: TextStyle(
                        color: _getHonestyScoreColor(post.honestyScore),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Tap to view full post
                  Text(
                    'Tap to view full post',
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  // Modify _buildAdditionalActionButtons to send correct related post ID
  Widget _buildAdditionalActionButtons() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Share button
          GestureDetector(
            onTap: () {
              // Share post functionality
              Share.share(
                'Check out this post: ${widget.post?.title ?? widget.title}',
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.share_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  'Share',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Save button
          if (widget.post != null)
            GestureDetector(
              onTap: _isLoading ? null : _toggleSavePost,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          widget.post!.isSaved == true
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: widget.post!.isSaved == true
                              ? Colors.amber
                              : Colors.grey,
                          size: 20,
                        ),
                  const SizedBox(width: 4),
                  Text(
                    widget.post!.isSaved == true ? 'Unsave' : 'Save',
                    style: TextStyle(
                      color: widget.post!.isSaved == true
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get color based on honesty score
  Color _getHonestyScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.amber;
    } else if (score >= 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}
