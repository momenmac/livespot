import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/utils/time_formatter.dart';
import 'package:flutter_application_2/ui/widgets/thread_item.dart';
import 'package:flutter_application_2/ui/widgets/post_options_popup.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:io';

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
  final TextEditingController _threadController = TextEditingController();
  late MapPageController _mapController;
  bool _mapInitialized = false; // Remove 'late' as it's initialized here
  bool _isLoadingVote = false; // Add loading state for vote operations
  bool _isLoading = false; // Add loading state for save operations

  // Real threads data, initialized empty
  List<Map<String, dynamic>> _threads = [];

  // Variables to track media attachment for thread
  String? _threadImageUrl;
  bool _isAttachingMedia = false;

  @override
  void initState() {
    super.initState();
    // Initialize with values from widget
    _upvotes = widget.upvotes;
    _initializePostData();
    _initializeMap();
    _fetchThreads();
  }

  void _initializePostData() {
    // Use real post data if available
    if (widget.post != null) {
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

      // Log initialization for debugging
      developer.log(
        'Initialized post detail with: upvotes=$_upvotes, downvotes=$_downvotes, '
        'userVote=${widget.post!.userVote}, hasUpvoted=$_hasUpvoted, hasDownvoted=$_hasDownvoted',
        name: 'PostDetailPage',
      );
    }
  }

  void _initializeMap() {
    // Initialize map controller
    _mapController = MapPageController();

    // Delay initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setCenterToPostLocation();
    });
  }

  void _fetchThreads() {
    // Load threads for this post if available
    _loadThreads();
  }

  // Load threads for this post
  Future<void> _loadThreads() async {
    // Defer execution until after the build is complete to avoid setState during build
    if (!mounted) return;

    // Use a post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.post != null) {
        try {
          final postsProvider =
              Provider.of<PostsProvider>(context, listen: false);
          final threads =
              await postsProvider.getThreadsForPost(widget.post!.id);

          if (mounted) {
            setState(() {
              _threads = threads;
            });
          }
        } catch (e) {
          debugPrint('Error loading threads: $e');
          // Show error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load comments: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // No mock data - just show empty threads list
        if (mounted) {
          setState(() {
            _threads = [];
          });
        }
      }
    });
  }

  // Helper method to set map center to post location
  void _setCenterToPostLocation() {
    try {
      _mapController.setContext(context);
      _mapController.initializeLocation();

      // If we have post coordinates, use them
      if (widget.post?.latitude != null && widget.post?.longitude != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _mapController.centerOnLocation(
              widget.post!.latitude, widget.post!.longitude);

          // Get the category from the post, or use a default
          String category = widget.post?.category.toLowerCase() ?? 'news';

          // Set a custom marker with appropriate styling based on the category
          _mapController.setCustomMarker(
            latitude: widget.post!.latitude,
            longitude: widget.post!.longitude,
            eventType: category, // This will determine the styling
            description: widget.post?.title ?? widget.title,
          );

          setState(() {
            _mapInitialized = true;
          });
        });
      } else {
        // Use a longer delay to ensure map is fully initialized before moving
        Future.delayed(const Duration(milliseconds: 1000), () {
          // Use the available method to center on user location as fallback
          _mapController.centerOnUserLocation();
          setState(() {
            _mapInitialized = true;
          });
        });
      }
    } catch (e) {
      debugPrint('Error setting map location: $e');
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
      // Call the API with the correct parameters
      final result = await postsProvider.voteOnPost(widget.post!, isUpvote);

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
        ResponsiveSnackBar.showError(
          context: context,
          message: postsProvider.errorMessage ?? 'Failed to update vote',
        );
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

      ResponsiveSnackBar.showError(
        context: context,
        message: 'Error: ${e.toString()}',
      );
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
      // Call the API with the correct parameters
      // For removing a downvote, we'd need a separate call to reset to neutral
      // which would be similar to the upvote flow but with isUpvote=null
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
        ResponsiveSnackBar.showError(
          context: context,
          message: postsProvider.errorMessage ?? 'Failed to update vote',
        );
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

      ResponsiveSnackBar.showError(
        context: context,
        message: 'Error: ${e.toString()}',
      );
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

      if (!success) {
        // Revert on API failure
        setState(() {
          widget.post!.isSaved = previousSavedState;
        });

        if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  postsProvider.errorMessage ?? 'Failed to update save status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle exceptions
      setState(() {
        widget.post!.isSaved = !(widget.post!.isSaved ?? false);
      });

      if (mounted) {
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

  // Add thread through API
  Future<void> _addThread() async {
    // Check if image is attached - require an image to post a thread
    if (_threadImageUrl == null) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Please attach an image to create a thread",
      );
      return;
    }

    // Check if content is provided
    if (_threadController.text.trim().isEmpty) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Please add some text to your thread",
      );
      return;
    }

    // Verify location if this is a real post
    if (widget.post != null) {
      try {
        final postsProvider =
            Provider.of<PostsProvider>(context, listen: false);

        // First verify the user's location before adding thread
        bool locationVerified = await postsProvider.verifyUserLocation(
          latitude: widget.post!.latitude,
          longitude: widget.post!.longitude,
          maxDistanceInMeters:
              1000, // Allow threads within 1km of the post location
        );

        if (!locationVerified) {
          ResponsiveSnackBar.showError(
            context: context,
            message: "You must be near the post location to add a thread",
          );
          return;
        }

        // Upload the image first and get the URL
        final String? mediaUrl =
            await postsProvider.uploadThreadMedia(_threadImageUrl!);

        if (mediaUrl == null) {
          ResponsiveSnackBar.showError(
            context: context,
            message: "Failed to upload media. Please try again.",
          );
          return;
        }

        // Create thread with the uploaded media
        final newThread = await postsProvider.createThread(
          postId: widget.post!.id,
          content: _threadController.text,
          mediaUrl: mediaUrl,
        );

        if (mounted) {
          setState(() {
            _threads.insert(0, newThread);
            _threadController.clear();
            _threadImageUrl = null; // Clear the image after posting
          });

          ResponsiveSnackBar.showSuccess(
            context: context,
            message: "Thread posted successfully!",
          );
        }
      } catch (e) {
        ResponsiveSnackBar.showError(
          context: context,
          message: "Failed to post thread: ${e.toString()}",
        );
      }
    } else {
      // Fallback to mock behavior for testing
      setState(() {
        _threads.insert(0, {
          'author': 'You',
          'text': _threadController.text,
          'time': 'Just now',
          'likes': 0,
          'replies': 0,
          'isVerified': false,
          'distance': '0.0 mi away',
          'media_url': _threadImageUrl,
        });
        _threadController.clear();
        _threadImageUrl = null; // Clear the image after posting
      });
    }
    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  // Function to handle image selection
  Future<void> _selectThreadImage() async {
    setState(() {
      _isAttachingMedia = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // For a real app, here you would upload the image to your server/storage
        // and get back a URL. For now, we'll just store the local path.
        setState(() {
          _threadImageUrl = image.path;
        });
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: "Image attached successfully",
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error attaching image: $e",
      );
    } finally {
      setState(() {
        _isAttachingMedia = false;
      });
    }
  }

  // Function to handle video selection
  Future<void> _selectThreadVideo() async {
    setState(() {
      _isAttachingMedia = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        // For a real app, here you would upload the video to your server/storage
        // and get back a URL. For now, we'll just store the local path.
        setState(() {
          _threadImageUrl = video.path; // Using same variable for simplicity
        });
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: "Video attached successfully",
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: "Error attaching video: $e",
      );
    } finally {
      setState(() {
        _isAttachingMedia = false;
      });
    }
  }

  // Function to clear selected media
  void _clearSelectedMedia() {
    setState(() {
      _threadImageUrl = null;
    });
  }

  // Enhanced method to get appropriate image URL or path with better fallback handling
  String _getImageUrl() {
    // First try: Check if we have a valid post object with an imageUrl
    if (widget.post?.imageUrl != null && widget.post!.imageUrl.isNotEmpty) {
      return widget.post!.imageUrl;
    }

    // Second try: Check if the post has media URLs
    if (widget.post?.hasMedia == true && widget.post!.mediaUrls.isNotEmpty) {
      return widget.post!.mediaUrls.first;
    }

    // Third try: Use the directly provided imageUrl
    if (widget.imageUrl.isNotEmpty) {
      return widget.imageUrl;
    }

    // Final fallback: Use a placeholder image
    return 'https://via.placeholder.com/400x200?text=No+Image';
  }

  // Helper method to determine if a string is a file path or URL
  bool _isFilePath(String path) {
    // This is a simple heuristic that can be enhanced based on your needs
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  // Widget to display either network image or file image based on the path
  Widget _buildImageWidget(String imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (_isFilePath(imageUrl)) {
      // Handle file paths (useful for locally picked images)
      return Image.file(
        File(imageUrl),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading file image: $error');
          return _buildImageErrorPlaceholder();
        },
      );
    } else {
      // Handle network URLs
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image: $error');
          return _buildImageErrorPlaceholder();
        },
      );
    }
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
    // First check if we have an actual distance value from the post
    if (widget.post?.distance != null && widget.post!.distance > 0) {
      double meters =
          widget.post!.distance * 1609.34; // Convert miles to meters
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

    // Try to extract distance from the distance string if available
    if (widget.distance != null && widget.distance!.isNotEmpty) {
      final RegExp regex = RegExp(r'(\d+\.?\d*)');
      final match = regex.firstMatch(widget.distance!);
      if (match != null) {
        try {
          final double miles = double.parse(match.group(1)!);
          final double meters = miles * 1609.34; // Convert miles to meters
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

    // Try to calculate distance from coordinates if available
    if (widget.post?.latitude != null && widget.post?.longitude != null) {
      try {
        // Try to get the current location
        _mapController.getUserLocation().then((userLocation) {
          if (userLocation != null) {
            // Calculate distance between user and post
            double calculatedDistance = _calculateDistance(
                userLocation.latitude,
                userLocation.longitude,
                widget.post!.latitude,
                widget.post!.longitude);

            // Update post distance
            widget.post!.distance =
                calculatedDistance / 1609.34; // Store in miles for consistency

            // Force rebuild UI with new distance
            if (mounted) setState(() {});
          }
        });
      } catch (e) {
        debugPrint("Error calculating distance: $e");
      }
    }

    // Default: show 300m instead of "Nearby" as requested
    return '300 m';
  }

  // Calculate distance between two coordinates in meters
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const int radiusOfEarth = 6371000; // Earth's radius in meters
    double latDistance = _toRadians(lat2 - lat1);
    double lonDistance = _toRadians(lon2 - lon1);

    double a = (sin(latDistance / 2) * sin(latDistance / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(lonDistance / 2) *
            sin(lonDistance / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return radiusOfEarth * c; // Distance in meters
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
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
      if (widget.post!.author.fullName != null && widget.post!.author.fullName!.isNotEmpty) {
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
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main post image
            Stack(
              children: [
                // Image with shimmer loading placeholder
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: _buildImageWidget(
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
                          Colors.black.withOpacity(0.7),
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
                                  ? NetworkImage(widget.post!.authorProfilePic!)
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
                  // Post title
                  Text(
                    widget.post?.title ?? widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Post description
                  Text(
                    widget.post?.description ?? widget.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Honesty Score Indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _getHonestyScoreColor(honestyScore).withOpacity(0.1),
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

                      // Comments count
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
                            '${_threads.length}',
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
              child: ClipRRectMapContainer(
                child: !_mapInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : MapWidget(mapController: _mapController),
              ),
            ),
            const SizedBox(height: 16),
            // Thread (comments) section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Threads (${_threads.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // List of threads (removed the thread input text field)
            ..._threads.map(
              (thread) => ThreadItem(
                authorName:
                    thread['author_name'] ?? thread['author'] ?? 'Anonymous',
                text: thread['content'] ?? thread['text'] ?? '',
                time: thread['time_ago'] ?? thread['time'] ?? 'Unknown time',
                likes: thread['likes'] ?? 0,
                replies: thread['replies'] ?? 0,
                isVerified:
                    thread['is_verified'] ?? thread['isVerified'] ?? false,
                distance: thread['distance'] ?? '0.0 mi away',
                profilePic: thread['author_profile_pic'],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Attach Image'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectThreadImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text('Attach Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectThreadVideo();
                  },
                ),
                if (_threadImageUrl != null)
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('Clear Attachment'),
                    onTap: () {
                      Navigator.pop(context);
                      _clearSelectedMedia();
                    },
                  ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
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

  @override
  void dispose() {
    _threadController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
