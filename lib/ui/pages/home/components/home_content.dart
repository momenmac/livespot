import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'sections/map_preview_section.dart';
import 'sections/news_feed_section.dart';
import 'sections/external_news_section.dart';
import 'sections/story_section.dart';
import 'comprehensive_search_page.dart';
// Add authentication related imports
import 'package:provider/provider.dart'; // Make sure to add provider dependency if not already added
import 'package:flutter_application_2/services/auth/auth_service.dart'; // Create or update this import path as needed
import 'package:flutter_application_2/ui/pages/notification/notifications_controller.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';

class HomeContent extends StatefulWidget {
  final VoidCallback? onMapToggle;
  final VoidCallback? onAuthError; // Add callback for auth errors

  const HomeContent({
    super.key,
    this.onMapToggle,
    this.onAuthError,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late DateTime _selectedDate;
  bool _isDateFilterActive = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with today's date, set to start of day
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    // Only set date filter active for non-current dates
    _isDateFilterActive = false;
    _checkAuthStatus();
  }

  // Add method to check authentication status
  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Assuming you have an AuthService or similar to validate tokens
      final authService = Provider.of<AuthService>(context, listen: false);
      final isValid = await authService.validateToken();

      if (!isValid && widget.onAuthError != null) {
        widget.onAuthError!();
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (widget.onAuthError != null) {
        widget.onAuthError!();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onDateSelected(DateTime date) {
    // Normalize the selected date to start of day
    final normalizedDate = DateTime(date.year, date.month, date.day);
    // Always update and call setState, even if the date is the same
    setState(() {
      _selectedDate = normalizedDate;
      _isDateFilterActive =
          !DateUtils.isSameDay(normalizedDate, DateTime.now());
    });
  }

  void _clearDateFilter() {
    // Clear filter by setting to start of today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedDate = today;
      // Set date filter to inactive when clearing
      _isDateFilterActive = false;
    });
  }

  // Add method to test notification popup
  void _testNotificationPopup() {
    print('🏠🔥🔥🔥 HOME PAGE TEST NOTIFICATION BUTTON PRESSED! 🔥🔥🔥');
    print('📱 Home page _testNotificationPopup() called');
    print('🎯 About to show notification popup from HOME PAGE...');

    // Test different types of notifications
    final notifications = [
      {
        'title': 'New Message',
        'message': 'You have received a new message from John Doe',
        'icon': Icons.message,
      },
      {
        'title': 'Friend Request',
        'message': 'Sarah wants to be your friend',
        'icon': Icons.person_add,
      },
      {
        'title': 'System Update',
        'message': 'Your app has been updated to the latest version',
        'icon': Icons.system_update,
      },
      {
        'title': 'Like Notification',
        'message': 'Someone liked your recent post',
        'icon': Icons.thumb_up,
      },
    ];

    // Show a random notification
    final randomNotification =
        notifications[DateTime.now().millisecond % notifications.length];

    print(
        '🏠🎲 HOME PAGE - Selected random notification: ${randomNotification['title']}');
    print('🏠💭 HOME PAGE - Message: ${randomNotification['message']}');
    print(
        '🏠🔄 HOME PAGE - Now calling NotificationsController.showNotification...');

    try {
      NotificationsController.showNotification(
        title: randomNotification['title'] as String,
        message: randomNotification['message'] as String,
        icon: randomNotification['icon'] as IconData,
        onTap: () {
          print(
              '🏠🎯 HOME PAGE - NOTIFICATION TAPPED! onTap callback executed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification tapped!')),
          );
        },
      );
      print(
          '🏠✅ HOME PAGE - NotificationsController.showNotification call completed');
    } catch (e) {
      print(
          '🏠❌ HOME PAGE ERROR calling NotificationsController.showNotification: $e');
      print('🏠🔍 HOME PAGE Error details: ${e.toString()}');
    }

    print('🏠🏁 HOME PAGE _testNotificationPopup() function finished');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator if checking auth status
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(TextStrings.appName),
        leading: IconButton(
          onPressed: widget.onMapToggle,
          icon: const Icon(Icons.location_on_outlined),
        ),
        actions: [
          // Test notification button
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _testNotificationPopup,
            tooltip: 'Test Notification',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComprehensiveSearchPage(
                    postsProvider: Provider.of<PostsProvider>(context, listen: false),
                    userProfileProvider: Provider.of<UserProfileProvider>(context, listen: false),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: ThemeConstants.primaryColor,
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != _selectedDate) {
                _onDateSelected(picked);
              }
            },
          ),
          // Add refresh token button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAuthStatus,
            tooltip: 'Refresh authentication',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          children: [
            if (_isDateFilterActive)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  label: Text(
                    '${TextStrings.showingResultsFor} ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                    style: const TextStyle(color: ThemeConstants.black),
                  ),
                  backgroundColor: ThemeConstants.primaryColorLight,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: _clearDateFilter,
                ),
              ),

            // Stories Section - with date filtering
            StorySection(selectedDate: _selectedDate),

            // Add a divider after stories
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Divider(height: 1),
            ),

            // Categories Section
            // Map Preview Section
            const MapPreviewSection(),

            // News Feed Section
            NewsFeedSection(
              key: ValueKey(_selectedDate), // Force rebuild on date change
              selectedDate: _selectedDate,
              onMapToggle: widget.onMapToggle,
            ),

            // External News Section
            ExternalNewsSection(selectedDate: _selectedDate),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
