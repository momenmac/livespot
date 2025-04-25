import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/rooms/room_detail_page.dart';

class AllRoomsPage extends StatelessWidget {
  const AllRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          TextStrings.recommendedRooms,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : ThemeConstants.black,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filter options section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? theme.cardColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: ThemeConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Filter Rooms',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildFilterChip(context, 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Live'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rooms grid with adjusted aspect ratio
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio:
                  0.7, // Adjusted from 0.75 to 0.7 to give more height
            ),
            itemCount: 6, // Example count
            itemBuilder: (context, index) {
              // Generate different room data
              final List<Map<String, dynamic>> roomData = [
                {
                  "title": "Current Events Discussion",
                  "description": "Discussion on today's major events",
                  "count": 58,
                  "isActive": true,
                  "type": "events"
                },
                {
                  "title": "Local City Updates",
                  "description": "Latest city developments and news",
                  "count": 24,
                  "isActive": false,
                  "type": "local"
                },
                {
                  "title": "Weather Watch Group",
                  "description": "Tracking the incoming storm",
                  "count": 42,
                  "isActive": true,
                  "type": "weather"
                },
                {
                  "title": "Tech Talk Room",
                  "description": "Discuss latest tech trends",
                  "count": 36,
                  "isActive": true,
                  "type": "tech"
                },
                {
                  "title": "Book Club",
                  "description": "Weekly reading discussions",
                  "count": 18,
                  "isActive": false,
                  "type": "books"
                },
                {
                  "title": "Fitness Challenge",
                  "description": "30-day workout group",
                  "count": 52,
                  "isActive": true,
                  "type": "fitness"
                },
              ];

              final room = roomData[index % roomData.length];

              return _buildRoomCard(context, room["title"], room["description"],
                  room["count"], room["isActive"], room["type"]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label) {
    final isSelected = label == 'All'; // Just for demonstration

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? ThemeConstants.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeConstants.primaryColor,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : ThemeConstants.primaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    String title,
    String description,
    int participantCount,
    bool isActive,
    String type,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Create room accent color
    final Color accentColor = type == "weather"
        ? ThemeConstants.orange
        : (type == "local"
            ? ThemeConstants.green
            : ThemeConstants.primaryColor);

    // Card background color based on theme
    final cardBackgroundColor = isDarkMode
        ? Color.lerp(theme.cardColor, accentColor, 0.03)
        : Color.lerp(Colors.white, accentColor, 0.03);

    // Text colors based on theme
    final textColor = isDarkMode ? Colors.white : ThemeConstants.black;
    final secondaryTextColor =
        isDarkMode ? Colors.white70 : ThemeConstants.black.withOpacity(0.6);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cardBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type == "weather"
                        ? Icons.cloud
                        : type == "local"
                            ? Icons.location_city
                            : type == "books"
                                ? Icons.book
                                : type == "tech"
                                    ? Icons.computer
                                    : type == "fitness"
                                        ? Icons.fitness_center
                                        : Icons.forum,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                if (isActive)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: ThemeConstants.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: ThemeConstants.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: ThemeConstants.green,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Title and description - reduced padding
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 4), // Reduced bottom padding from 8 to 4
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Participants info and join button with reduced padding
          Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 to 12
            child: Column(
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$participantCount members',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6), // Reduced from 8 to 6
                SizedBox(
                  width: double.infinity,
                  height: 30, // Add fixed height to button
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to room detail page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomDetailPage(
                            title: title,
                            description: description,
                            type: type,
                            participantCount: participantCount,
                            isActive: isActive,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      TextStrings.joinRoom,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
