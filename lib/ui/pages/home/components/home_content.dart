import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'sections/map_preview_section.dart';
import 'sections/news_feed_section.dart';
import 'sections/live_streams_section.dart';
import 'sections/external_news_section.dart';
import 'sections/story_section.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/date_picker_widget.dart';
// Add authentication related imports
import 'package:provider/provider.dart'; // Make sure to add provider dependency if not already added
import 'package:flutter_application_2/services/auth/auth_service.dart'; // Create or update this import path as needed

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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SearchBarWidget(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return DatePickerWidget(
                    onDateSelected: _onDateSelected,
                    selectedDate: _selectedDate,
                  );
                },
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
              );
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

            // Live Streams Section
            const LiveStreamsSection(),

            // External News Section
            ExternalNewsSection(selectedDate: _selectedDate),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
