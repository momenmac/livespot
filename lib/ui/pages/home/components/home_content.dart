import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'sections/map_preview_section.dart';
import 'sections/categories_section.dart';
import 'sections/news_feed_section.dart';
import 'sections/live_streams_section.dart';
import 'sections/recommended_rooms_section.dart';
import 'sections/external_news_section.dart';
import 'sections/story_section.dart'; // Add this import
import 'widgets/search_bar_widget.dart';
import 'widgets/date_picker_widget.dart';

class HomeContent extends StatefulWidget {
  final VoidCallback? onMapToggle;

  const HomeContent({
    super.key,
    this.onMapToggle,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  DateTime _selectedDate = DateTime.now();
  bool _isDateFilterActive = false;

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _isDateFilterActive = !DateUtils.isSameDay(date, DateTime.now());
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = DateTime.now();
      _isDateFilterActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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

            // Stories Section - NEW: add at the very top
            const StorySection(),

            // Add a divider after stories
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Divider(height: 1),
            ),

            // Categories Section
            const CategoriesSection(),

            // Map Preview Section
            const MapPreviewSection(),

            // News Feed Section
            NewsFeedSection(
              selectedDate: _selectedDate,
              onMapToggle: widget.onMapToggle,
            ),

            // Recommended Rooms Section
            const RecommendedRoomsSection(),

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
