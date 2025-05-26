import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Import SchedulerBinding
import 'dart:async'; // Import for Timer class
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart'; // Import for category styling
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart'; // Corrected import path
import 'package:flutter_application_2/models/post.dart'; // Import for Post model
import 'package:flutter_application_2/models/coordinates.dart'; // Import for PostCoordinates
import 'package:flutter_application_2/models/user.dart'; // Import for User model
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_search_bar.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_controls.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_date_picker.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_categories.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/legend/map_legend.dart'; // Import the map legend widget
import 'package:flutter_application_2/ui/widgets/animated_speech_bubble.dart'; // Import animated speech bubble widget
import 'package:flutter_application_2/ui/pages/media/reels_page.dart'; // Import reels page
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_2/services/auth/token_manager.dart'; // Import TokenManager
import 'package:flutter_application_2/services/api/account/api_urls.dart'; // Import ApiUrls
import 'dart:math';

class MapPage extends StatefulWidget {
  final VoidCallback? onBackPress;
  final bool showBackButton;

  const MapPage({
    super.key,
    this.onBackPress,
    this.showBackButton = true,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapPageController _controller;
  final FocusNode _focusNode = FocusNode();
  final TokenManager _tokenManager =
      TokenManager(); // Add TokenManager instance

  // Add state variables for location data
  List<dynamic> _mapLocations = [];
  bool _isLoadingLocations = false;
  String? _error;

  // Add a list to store multiple selected categories
  List<String> _selectedCategories = [];

  // List of custom markers on the map
  final List<Marker> _mapMarkers = [];

  // Add a cache for locations and filters
  List<dynamic>? _locationsCache;
  String? _lastCacheDateParam;
  List<String>? _lastCacheCategories;

  // Debounce timer for location fetching
  Timer? _fetchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = MapPageController();
    // Delay initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.setContext(context);
    });
    // Defer map initialization until after the first frame is rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initializeLocation();

        // IMPORTANT: Set today's date as default and ensure it's used in queries
        final today = DateTime.now();
        print(
            '📅 Setting initial date filter to today: ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
        _controller.selectedDate = today;

        // Small delay to ensure controller is fully initialized
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _debouncedFetchLocations();
          }
        });
      }
    });

    // Listen for controller changes and debounce to avoid multiple API calls
    _controller.addListener(() {
      print('🔄 Controller notified changes - Triggering debounced fetch');
      // Debounce to prevent multiple rapid API calls
      _debouncedFetchLocations();
    });
  }

  void _debouncedFetchLocations() {
    // Cancel any previous timer
    _fetchDebounceTimer?.cancel();

    // Start a new timer
    _fetchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchMapLocations();
      }
    });

    // Debug message to verify debounce is working
    print('🕒 Debounce timer started - delaying API request by 500ms');
  }

  // Helper method to compare lists irrespective of order
  bool _areListsEqual(List<String>? list1, List<String>? list2) {
    // Handle null cases
    if (list1 == null && list2 == null) {
      return true;
    }
    if (list1 == null || list2 == null) {
      print('📊 One list is null, not equal');
      return false;
    }

    // If both lists are empty, they're equal
    if (list1.isEmpty && list2.isEmpty) {
      return true;
    }

    // Quick length check
    if (list1.length != list2.length) {
      print('📊 List length mismatch: ${list1.length} vs ${list2.length}');
      return false;
    }

    // Sort copies of the lists for comparison (case insensitive)
    final sorted1 = List<String>.from(list1)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sorted2 = List<String>.from(list2)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Compare each element (case insensitive)
    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i].toLowerCase() != sorted2[i].toLowerCase()) {
        print(
            '📊 List element mismatch at position $i: "${sorted1[i]}" vs "${sorted2[i]}"');
        return false;
      }
    }

    // All elements match
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _fetchDebounceTimer?.cancel();
    super.dispose();
  }

  // Method to fetch location data from the API
  Future<void> _fetchMapLocations() async {
    if (!mounted) return;

    final DateTime selectedDate = _controller.selectedDate;

    // Force setting today's date if no date is selected
    if (selectedDate == null) {
      print(
          '⚠️ No date selected - forcing today\'s date to ensure proper filtering');
      _controller.selectedDate = DateTime.now();
      // Wait for the controller to update before proceeding
      await Future.delayed(const Duration(milliseconds: 50));
      // Try again with the date set
      if (mounted) _fetchMapLocations();
      return;
    }

    // ALWAYS include the date parameter when selectedDate is available
    String dateParam;

    // selectedDate is guaranteed to be non-null at this point due to the check above
    // Format date as YYYY-MM-DD (always include date parameter regardless of whether it's today)
    dateParam = "${selectedDate.year}-"
        "${selectedDate.month.toString().padLeft(2, '0')}-"
        "${selectedDate.day.toString().padLeft(2, '0')}";

    print('📆 Using date parameter: $dateParam');

    // Convert selected categories to a sorted list for consistent comparison
    final sortedCategories = List<String>.from(_selectedCategories)..sort();

    // Print debug info about the current request
    print('🔍 Fetch request - Date: $dateParam, Categories: $sortedCategories');

    // Check if we can use the cache - with deep comparison of category lists
    if (_locationsCache != null &&
        _lastCacheDateParam == dateParam &&
        _areListsEqual(_lastCacheCategories, sortedCategories)) {
      print('✅ Using cache - Avoiding network request');
      print('   Cache hits - Date: "$_lastCacheDateParam" = "$dateParam"');
      print(
          '   Cache hits - Categories: $_lastCacheCategories = $sortedCategories');

      setState(() {
        _mapLocations = _locationsCache!;
        _isLoadingLocations = false;
        _addMarkersToMap();
      });
      return;
    }

    // Cache miss - debug info
    print('⚠️ Cache miss - Making network request');
    if (_lastCacheDateParam != dateParam) {
      print('  - Date changed: $_lastCacheDateParam → $dateParam');
    }
    if (!_areListsEqual(_lastCacheCategories, sortedCategories)) {
      print(
          '  - Categories changed: $_lastCacheCategories → $sortedCategories');
    }

    setState(() {
      _isLoadingLocations = true;
      _error = null;
    });

    try {
      // Create the URL with query parameters
      String url = ApiUrls.posts;
      final queryParams = <String, String>{};

      // ALWAYS add date parameter when available - this is essential for filtering
      queryParams['date'] = dateParam;
      print('🗓️ Adding date filter to URL: date=$dateParam');

      // Send all selected categories as a single comma-separated value
      if (_selectedCategories.isNotEmpty) {
        // Clean up and normalize category values
        final normalizedCategories = _selectedCategories
            .where((cat) => cat.isNotEmpty) // Filter out empty strings
            .map((cat) => cat.trim().toLowerCase()) // Normalize format
            .toList();

        if (normalizedCategories.isNotEmpty) {
          // Based on the server logs, it appears the server is expecting a single category
          // Try the last selected category (most recent selection)
          final lastSelectedCategory = normalizedCategories.last;
          queryParams['category'] = lastSelectedCategory;
          print('📂 Adding category filter: category=$lastSelectedCategory');

          // Also include all categories parameter (just in case server starts supporting it)
          if (normalizedCategories.length > 1) {
            final allCategories = normalizedCategories.join(',');
            queryParams['categories'] = allCategories;
            print(
                '📂 Adding all categories as backup: categories=$allCategories');
          }

          // Debug info to check what's being sent
          print(
              '📂 Category filter type: ${normalizedCategories.runtimeType}, values: $normalizedCategories');
          print(
              '📂 Using most recent category selection: $lastSelectedCategory');
        }
      }

      if (queryParams.isNotEmpty) {
        // Encode URI components properly to handle special characters
        final encodedParams = queryParams.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += '?$encodedParams';

        // Log the final encoded URL
        print('🌐 Encoded API URL: $url');
      }

      // Extra clear logging to help debug API requests
      print('🌐 Final API request URL: $url');

      // Debug the actual URL being sent
      print('🔍 API URL with filters: $url');
      print('📋 Selected categories: $_selectedCategories');

      // Make the HTTP request using TokenManager
      final token = await _tokenManager.getValidAccessToken();

      print('Using token from TokenManager');
      if (token != null) {
        print('Authorization header: Bearer ${token.substring(0, 3)}...');
      } else {
        print('No authentication token available');
      }

      // Debug headers before making request
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token != null ? 'Bearer $token' : '',
      };
      print('🔒 Request headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      // Debug response
      print('📡 Response status code: ${response.statusCode}');
      print('📝 Response headers: ${response.headers}');
      if (response.statusCode != 200) {
        print('❌ Error response body: ${response.body}');
      }

      print(
          'Fetching posts with URL: $url and headers: ${response.request?.headers}');
      print('Posts API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successful response data: $data');

        // Check if response contains paginated data structure
        if (data is Map && data.containsKey('results')) {
          print('📄 Paginated response detected');
          print('📊 Total count: ${data['count']}');
          print('⏭️ Next page: ${data['next']}');
          print('⏮️ Previous page: ${data['previous']}');

          // Get the current page results
          final List<dynamic> currentResults = data['results'];
          final String? nextPageUrl = data['next'];

          // Add current results to our locations
          List<dynamic> allLocations = List.from(_mapLocations)
            ..addAll(currentResults);

          setState(() {
            _mapLocations = allLocations;
          });

          // Display first page results immediately
          setState(() {
            _mapLocations = currentResults;
            _addMarkersToMap(); // Add markers for first page immediately
          });

          // If there's a next page, fetch remaining pages progressively
          if (nextPageUrl != null && mounted) {
            String? currentNextUrl = nextPageUrl;

            // Fetch remaining pages one at a time
            while (currentNextUrl != null && mounted) {
              print('🔄 Fetching next page: $currentNextUrl');
              final nextResponse = await http.get(
                Uri.parse(currentNextUrl),
                headers: headers,
              );

              if (nextResponse.statusCode == 200) {
                final nextData = jsonDecode(nextResponse.body);
                if (nextData is Map && nextData.containsKey('results')) {
                  final newResults = nextData['results'] as List;
                  print('📥 Got page with ${newResults.length} results');

                  // Update UI progressively with new markers
                  setState(() {
                    _mapLocations = [..._mapLocations, ...newResults];
                    _addMarkersToMap(); // Add new markers immediately
                  });

                  currentNextUrl = nextData['next'] as String?;
                  print('📊 Total locations so far: ${_mapLocations.length}');
                } else {
                  break;
                }
              } else {
                print('❌ Failed to fetch page: ${nextResponse.statusCode}');
                break;
              }
            }
          }
          // Set loading to false after all pages are fetched
          setState(() {
            _isLoadingLocations = false;
          });
          print(
              '✅ All pages fetched. Total locations: ${_mapLocations.length}');
          // Cache the results with deep copy to avoid reference issues
          _locationsCache = List<dynamic>.from(_mapLocations);
          _lastCacheDateParam = dateParam;
          _lastCacheCategories = _selectedCategories.isEmpty
              ? []
              : List<String>.from(_selectedCategories);
          print(
              '📦 Updated cache - Date: $dateParam, Categories: $_lastCacheCategories');
        } else {
          print('⚠️ Non-paginated response detected');
          setState(() {
            _mapLocations = data;
            _isLoadingLocations = false;
            _addMarkersToMap();
          });
          // Cache the results with deep copy to avoid reference issues
          _locationsCache = List<dynamic>.from(_mapLocations);
          _lastCacheDateParam = dateParam;
          _lastCacheCategories = _selectedCategories.isEmpty
              ? []
              : List<String>.from(_selectedCategories);
          print(
              '📦 Updated cache (non-paginated) - Date: $dateParam, Categories: $_lastCacheCategories');
        }

        // Always call _addMarkersToMap after updating _mapLocations
        // This ensures the map is updated whether or not we have locations
        setState(() {
          // This will clear markers if _mapLocations is empty
          _addMarkersToMap();
        });
      } else {
        print('❌ Error status code: ${response.statusCode}');
        final errorMessage =
            "Failed to fetch locations: ${response.statusCode} - ${response.body}";
        print('❌ Error message: $errorMessage');
        setState(() {
          _error = errorMessage;
          _isLoadingLocations = false;
        });

        // Show error in snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred while fetching locations: $e";
        _isLoadingLocations = false;
      });
    }
  }

  // Add post markers to the map
  void _addMarkersToMap() {
    // Always clear existing markers first
    _mapMarkers.clear();

    // Early return if no locations - this effectively removes all markers
    if (_mapLocations.isEmpty) {
      print('🗺️ No locations to show on map - all markers cleared');
      setState(() {}); // Ensure UI updates with empty map
      return;
    }

    print('🗺️ Adding ${_mapLocations.length} markers to map');

    // Add new markers for each location
    for (final post in _mapLocations) {
      if (post['location'] != null) {
        try {
          final latitude = post['location']['latitude']?.toDouble();
          final longitude = post['location']['longitude']?.toDouble();

          if (latitude != null && longitude != null) {
            final category = post['category'] ?? 'general';

            // Only add markers that match the selected category filter if any is selected
            final shouldAddMarker = _selectedCategories.isEmpty ||
                _selectedCategories.contains(category.toLowerCase());

            if (shouldAddMarker) {
              // Add marker with just the icon (no text) - smaller size
              _mapMarkers.add(
                Marker(
                  height: 38, // Reduced from 42 to 38
                  width: 38, // Reduced from 42 to 38
                  point: LatLng(latitude, longitude),
                  child: GestureDetector(
                    onTap: () => _showSpeechBubblePopover(
                        context, post, LatLng(latitude, longitude)),
                    child: _buildMarkerIcon(category),
                  ),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint("Error adding marker for post ID ${post['id']}: $e");
        }
      }
    }

    // Force a rebuild to show the new markers
    setState(() {});
  }

  // Build marker icon based on category
  Widget _buildMarkerIcon(String category) {
    // Use the new LiveUAMap-style markers
    return CategoryUtils.buildLiveUAMapMarker(
      category,
      isSelected: false,
      showShadow: true,
    );
  }

  // Show speech bubble popover with post details when marker is tapped
  void _showSpeechBubblePopover(
      BuildContext context, dynamic post, LatLng position) {
    // Get post details with proper encoding for Arabic text
    final category = post['category'] ?? 'general';

    // Get title with proper UTF-8 encoding for Arabic text
    String title = post['title'] ?? '';
    // Try to ensure proper UTF-8 decoding for Arabic text
    if (title.contains('Ù') || title.contains('Ø')) {
      try {
        // Convert to bytes and properly decode as UTF-8
        List<int> bytes = title.codeUnits;
        title = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        debugPrint('Error decoding title: $e');
      }
    }

    // Get content with proper UTF-8 encoding for Arabic text
    String content = post['content'] ?? post['description'] ?? '';
    // Try to ensure proper UTF-8 decoding for Arabic text
    if (content.contains('Ù') || content.contains('Ø')) {
      try {
        // Convert to bytes and properly decode as UTF-8
        List<int> bytes = content.codeUnits;
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        debugPrint('Error decoding content: $e');
      }
    }

    // Extract media information with improved handling for different data structures
    String? thumbnailUrl;
    List<String> mediaUrls = [];

    // Extract all media URLs from the post
    if (post.containsKey('media_urls') &&
        post['media_urls'] is List &&
        (post['media_urls'] as List).isNotEmpty) {
      // Handle direct media_urls array
      mediaUrls = List<String>.from(post['media_urls']);
      thumbnailUrl = mediaUrls[0];
    } else if (post.containsKey('media') &&
        post['media'] is List &&
        (post['media'] as List).isNotEmpty) {
      var mediaList = post['media'];

      // Collect all media URLs from the list
      for (var item in mediaList) {
        String? url;

        // If item is a direct string URL
        if (item is String) {
          url = item;
        }
        // If item is a map with URL in a field
        else if (item is Map) {
          // Try common keys for image URLs
          for (final key in [
            'image_url',
            'url',
            'path',
            'src',
            'uri',
            'thumb',
            'thumbnail'
          ]) {
            if (item.containsKey(key)) {
              url = item[key];
              break;
            }
          }
        }

        // Add valid URL to our list
        if (url != null && url.isNotEmpty) {
          // Make relative URLs absolute
          if (url.startsWith('/')) {
            url = '${ApiUrls.baseUrl}$url';
          }
          mediaUrls.add(url);
        }
      }

      // Use the first media URL as thumbnail
      if (mediaUrls.isNotEmpty) {
        thumbnailUrl = mediaUrls[0];
      }
    } else if (post.containsKey('mediaUrls') &&
        post['mediaUrls'] is List &&
        (post['mediaUrls'] as List).isNotEmpty) {
      // Handle direct mediaUrls array with camelCase
      mediaUrls = List<String>.from(post['mediaUrls']);
      thumbnailUrl = mediaUrls[0];
    } else if (post.containsKey('image_url')) {
      // Handle direct image_url field
      thumbnailUrl = post['image_url'];
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        mediaUrls = [thumbnailUrl];
      }
    } else if (post.containsKey('imageUrl')) {
      // Handle direct imageUrl field with camelCase
      thumbnailUrl = post['imageUrl'];
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        mediaUrls = [thumbnailUrl];
      }
    }

    // Check if thumbnailUrl is a relative URL and make it absolute if needed
    if (thumbnailUrl != null && thumbnailUrl.startsWith('/')) {
      thumbnailUrl = '${ApiUrls.baseUrl}$thumbnailUrl';
    }

    // Fix for honesty rate - handle different possible structures and formats
    double honesty = 0.0;
    if (post.containsKey('honesty_rate')) {
      try {
        if (post['honesty_rate'] is num) {
          honesty = post['honesty_rate'].toDouble();
        } else if (post['honesty_rate'] is String) {
          honesty = double.tryParse(post['honesty_rate']) ?? 0.0;
        }
      } catch (e) {
        honesty = 0.0;
      }
    } else if (post.containsKey('honesty_score')) {
      try {
        if (post['honesty_score'] is num) {
          honesty = post['honesty_score'].toDouble();
        } else if (post['honesty_score'] is String) {
          honesty = double.tryParse(post['honesty_score']) ?? 0.0;
        }
      } catch (e) {
        honesty = 0.0;
      }
    } else if (post.containsKey('honestyScore')) {
      try {
        if (post['honestyScore'] is num) {
          honesty = post['honestyScore'].toDouble();
        } else if (post['honestyScore'] is String) {
          honesty = double.tryParse(post['honestyScore']) ?? 0.0;
        }
      } catch (e) {
        honesty = 0.0;
      }
    }

    final DateTime? postDate =
        post['created_at'] != null ? DateTime.parse(post['created_at']) : null;
    final String formattedDate = postDate != null
        ? "${postDate.day}/${postDate.month}/${postDate.year} at ${postDate.hour}:${postDate.minute.toString().padLeft(2, '0')}"
        : "Unknown date";

    // Debug logging to check is_saved field
    debugPrint('🔖 MapPage: Creating Post object for post ${post['id']}');
    debugPrint('🔖 MapPage: API response is_saved: ${post['is_saved']}');
    debugPrint(
        '🔖 MapPage: API response type: ${post['is_saved'].runtimeType}');

    // Create a Post object for the ReelsPage navigation
    final postObj = Post(
      id: post['id'] ?? 0,
      title: title,
      content: content,
      category: category,
      imageUrl: thumbnailUrl ?? '',
      createdAt: postDate ?? DateTime.now(),
      honestyScore: honesty.toInt(),
      upvotes: post['upvotes'] ?? 0,
      downvotes: post['downvotes'] ?? 0,
      userVote: post['user_vote'] ?? 0,
      mediaUrls: mediaUrls,
      latitude: post['location']['latitude']?.toDouble() ?? 0.0,
      longitude: post['location']['longitude']?.toDouble() ?? 0.0,
      location: _createPostLocation(
        post['location'] != null
            ? (post['location']['name'] ?? 'Unknown location')
            : 'Unknown location',
        post['location']['latitude']?.toDouble(),
        post['location']['longitude']?.toDouble(),
      ),
      author: _createPostAuthor(
        post['author']?['id'] ?? 0,
        post['is_anonymous'] == true
            ? 'Anonymous'
            : (post['author']?['display_name'] ??
                post['author']?['username'] ??
                'Anonymous'),
        post['is_verified'] ?? false,
        profileImage: post['is_anonymous'] == true
            ? null
            : post['author']?['profile_picture'],
      ),
      status: post['status'] ?? 'published',
      isVerifiedLocation: post['is_verified_location'] ?? true,
      takenWithinApp: post['taken_within_app'] ?? true,
      isAnonymous: post['is_anonymous'] ?? false,
      tags: [],
      isSaved: post['is_saved'], // Add isSaved field from API response
    );

    // Calculate position for the bubble
    // We need to convert the map coordinates to screen coordinates
    final screenPoint =
        _controller.mapController.camera.latLngToScreenPoint(position);

    // Show overlay
    OverlayState? overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    void removeOverlay() {
      overlayEntry.remove();
    }

    // Create the overlay entry with the speech bubble
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent full-screen layer to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: removeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Position the speech bubble above the marker with dynamic sizing and adaptive positioning
          Positioned(
            left: max(
                10,
                min(MediaQuery.of(context).size.width - 310,
                    screenPoint.x - 150)), // Keep bubble on screen
            // Adjust vertical position - if near top of screen, put bubble below marker instead
            top: screenPoint.y < MediaQuery.of(context).size.height * 0.3
                ? screenPoint.y + 40 // Place below the marker if close to top
                : max(MediaQuery.of(context).padding.top + 10,
                    screenPoint.y - 210), // Otherwise above
            child: AnimatedSpeechBubble(
              bubbleColor: Theme.of(context).cardColor,
              cornerRadius: 20.0,
              arrowWidth: 22.0,
              arrowHeight: 12.0,
              elevation: 6.0,
              shadowColor: Colors.black26,
              animationDuration: const Duration(milliseconds: 300),
              // Set arrow direction based on bubble position
              arrowAlignment: screenPoint.y <
                      MediaQuery.of(context).size.height * 0.3
                  ? Alignment
                      .topCenter // Arrow points up if bubble is below marker
                  : Alignment
                      .bottomCenter, // Arrow points down if bubble is above marker
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Enhanced title with better typography
                    Container(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Directionality(
                        textDirection: _isArabicText(title)
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: _isArabicText(title)
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      ),
                    ),

                    // Subtle divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Theme.of(context).primaryColor.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Enhanced content preview
                    if (content.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Directionality(
                          textDirection: _isArabicText(content)
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.8),
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: _isArabicText(content)
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),
                      ),

                    // Date and location info
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (post['location'] != null &&
                              post['location']['name'] != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  post['location']['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enhanced button section with better styling
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          // Action buttons row with improved design
                          Row(
                            children: [
                              // View details button with gradient
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).primaryColor,
                                        Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        removeOverlay();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PostDetailPage(
                                              title: title,
                                              description: content,
                                              imageUrl: thumbnailUrl ?? '',
                                              location: post['location'] != null
                                                  ? (post['location']['name'] ??
                                                      'Unknown location')
                                                  : 'Unknown location',
                                              time: formattedDate,
                                              honesty: honesty.toInt(),
                                              upvotes: post['upvotes'] ?? 0,
                                              comments:
                                                  post['comments_count'] ??
                                                      post['threads_count'] ??
                                                      0,
                                              isVerified:
                                                  post['is_verified'] ?? false,
                                              post: postObj,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.article_outlined,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Details',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // View media button with enhanced styling
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: mediaUrls.isEmpty
                                        ? LinearGradient(
                                            colors: [
                                              Colors.grey.shade300,
                                              Colors.grey.shade400
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              ThemeConstants.green,
                                              ThemeConstants.green
                                                  .withOpacity(0.8),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: mediaUrls.isEmpty
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: ThemeConstants.green
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: mediaUrls.isEmpty
                                          ? null
                                          : () {
                                              removeOverlay();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ReelsPage(
                                                    post: postObj,
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _hasVideoContent(mediaUrls)
                                                  ? Icons.play_circle_outline
                                                  : Icons
                                                      .photo_library_outlined,
                                              size: 20,
                                              color: mediaUrls.isEmpty
                                                  ? Colors.grey.shade600
                                                  : Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              mediaUrls.isEmpty
                                                  ? 'No Media'
                                                  : (_hasVideoContent(mediaUrls)
                                                      ? 'Videos'
                                                      : 'Photos'),
                                              style: TextStyle(
                                                color: mediaUrls.isEmpty
                                                    ? Colors.grey.shade600
                                                    : Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Additional info row with stats
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Upvotes
                              _buildStatItem(
                                icon: Icons.thumb_up_outlined,
                                count: post['upvotes'] ?? 0,
                                label: 'Upvotes',
                                color: Colors.blue,
                              ),
                              // Comments
                              _buildStatItem(
                                icon: Icons.comment_outlined,
                                count: post['comments_count'] ??
                                    post['threads_count'] ??
                                    0,
                                label: 'Comments',
                                color: Colors.orange,
                              ),
                              // Verification status
                              if (post['is_verified'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified,
                                          size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }

  // Method to handle category selection - updated for multiple categories
  void _handleCategorySelected(List<CategoryItem> selectedCategories) {
    print(
        '🔖 Received ${selectedCategories.length} categories from MapCategories widget');

    // Convert category items to lowercase strings and normalize
    final newCategories = selectedCategories
        .map((item) => item.name.trim().toLowerCase())
        .toList();

    // Log before state change with more details
    print('🔖 Current categories before update: $_selectedCategories');
    print('🔖 New categories to set: $newCategories');

    // Print each selected category for debugging
    for (int i = 0; i < selectedCategories.length; i++) {
      print(
          '🔖 Category ${i + 1}: ${selectedCategories[i].name} (${selectedCategories[i].icon})');
    }

    // Check if categories actually changed before updating state
    if (!_areListsEqual(_selectedCategories, newCategories)) {
      print('🔖 Categories have changed - updating state and triggering fetch');

      // Clear the cache when categories change to force a new API request
      _locationsCache = null;
      _lastCacheCategories = null;

      setState(() {
        // Direct replacement with the full list from MapCategories
        _selectedCategories = newCategories;
      });

      // Debug log after state change
      print('🔖 Categories changed - State updated');
      print('🔖 Selected categories after update: $_selectedCategories');

      // Use debounced fetch instead of direct fetch to avoid rapid API calls
      print('🔖 Triggering debounced location fetch with new categories');
      _debouncedFetchLocations();
    } else {
      print('🔖 Categories unchanged - No fetch needed');
    }
  }

  // Helper method to create PostCoordinates instance
  PostCoordinates _createPostLocation(
      String address, double? latitude, double? longitude) {
    return PostCoordinates(
      address: address,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
    );
  }

  // Helper method to create User instance
  User _createPostAuthor(int id, String username, bool isVerified,
      {String? profileImage}) {
    return User(
      id: id,
      username: username,
      isVerified: isVerified,
      profileImage: profileImage,
    );
  }

  // Helper method to check if text contains Arabic characters
  bool _isArabicText(String text) {
    // Regular expression to match Arabic Unicode character range
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  // Custom animated location button widget
  Widget _buildCurrentLocationButton() {
    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ThemeConstants.primaryColor, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ThemeConstants.primaryColor.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withOpacity(0.3),
            highlightColor: Colors.white.withOpacity(0.1),
            onTap: _controller.centerOnUserLocation,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                  // Inner dot
                  Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Direction indicators
                  ...List.generate(
                    4,
                    (index) {
                      final angle = index * (pi / 2);
                      return Transform.translate(
                        offset: Offset(
                          sin(angle) * 16,
                          -cos(angle) * 16,
                        ),
                        child: Container(
                          height: 6,
                          width: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping anywhere on the screen
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        // Configure SnackBar behavior for proper display
        bottomNavigationBar: const SizedBox(
            height: 1), // Tiny placeholder to fix SnackBar positioning
        appBar: widget.showBackButton && !isLargeScreen
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // First hide keyboard when back button is pressed
                    FocusScope.of(context).unfocus();

                    // Then perform navigation
                    if (widget.onBackPress != null) {
                      widget.onBackPress!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Text(TextStrings.map,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  if (_controller.destination != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                            context, _controller.locationController.text);
                      },
                      child: const Text('Select Location'),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: MapDatePicker(
                      selectedDate: _controller.selectedDate,
                      onDateChanged: _controller.handleDateChanged,
                    ),
                  ),
                ],
              )
            : null,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Map view
                MapView(
                  controller: _controller,
                  onTap: () {
                    // Dismiss keyboard when map is tapped
                    FocusScope.of(context).unfocus();
                  },
                  // Pass markers to MapView
                  markers: _mapMarkers,
                ),

                // Categories
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: MapCategories(
                    onCategorySelected: _handleCategorySelected,
                  ),
                ),

                // Search bar
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: MapSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                  ),
                ),

                // Left side controls
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom +
                      80, // Increased to make room for SnackBar
                  left: 10,
                  child: MapControls(
                    controller: _controller,
                    isDarkMode: isDarkMode,
                  ),
                ),

                // Date picker for large screens
                if (!widget.showBackButton || isLargeScreen)
                  Positioned(
                    left: 60,
                    bottom: MediaQuery.of(context).padding.bottom +
                        80, // Increased to match controls
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? ThemeConstants.darkCardColor
                            : ThemeConstants.lightBackgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: MapDatePicker(
                        selectedDate: _controller.selectedDate,
                        onDateChanged: _controller.handleDateChanged,
                      ),
                    ),
                  ),

                // Map Legend
                const MapLegend(),

                // Loading indicator
                if (_isLoadingLocations)
                  Positioned(
                    top: 130,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? ThemeConstants.darkCardColor.withOpacity(0.8)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeConstants.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Loading locations...",
                              style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Error message
                if (_error != null)
                  Positioned(
                    top: 130,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => _error = null),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 10),
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // Use min size to avoid taking too much space
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'refresh_button',
                    elevation: 0,
                    backgroundColor: ThemeConstants.green,
                    onPressed: _fetchMapLocations,
                    child: const Icon(
                      Icons.refresh,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCurrentLocationButton(),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'route_button',
                    elevation: 0,
                    onPressed: _controller.toggleRoute,
                    backgroundColor: _controller.showRoute
                        ? ThemeConstants.primaryColor
                        : null,
                    child: const Icon(
                      Icons.route,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to check if any of the media URLs points to a video
  bool _hasVideoContent(List<String> urls) {
    for (final url in urls) {
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.endsWith('.mp4') ||
          lowerUrl.endsWith('.mov') ||
          lowerUrl.endsWith('.avi') ||
          lowerUrl.endsWith('.webm') ||
          lowerUrl.contains('video')) {
        return true;
      }
    }
    return false;
  }

  // Helper method to build stat items for the speech bubble
  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}
