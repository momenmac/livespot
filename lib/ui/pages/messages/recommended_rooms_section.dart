import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'dart:math'; // Add this for the min() function
import 'package:flutter_application_2/ui/pages/rooms/all_rooms_page.dart'; // Add this import
import 'package:flutter_application_2/ui/pages/rooms/room_detail_page.dart'; // Add this import

class RecommendedRoomsSection extends StatelessWidget {
  const RecommendedRoomsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TextStrings.recommendedRooms,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to All Rooms page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllRoomsPage(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      TextStrings.viewAll,
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Reduced height to eliminate white space
        SizedBox(
          height: 180, // Reduced height to 180px
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildRoomCard(
                  context,
                  "Current Events Discussion",
                  "Discussion on today's major events",
                  58,
                  true,
                ),
                _buildRoomCard(
                  context,
                  "Local City Updates",
                  "Latest city developments and news",
                  24,
                  false,
                ),
                _buildRoomCard(
                  context,
                  "Weather Watch Group",
                  "Tracking the incoming storm",
                  42,
                  true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    String title,
    String description,
    int participantCount,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Create room accent color
    final Color accentColor = title.contains("Weather")
        ? ThemeConstants.orange
        : (title.contains("Local")
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
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          // Header section with accent and status
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room icon with accent
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    title.contains("Weather")
                        ? Icons.cloud
                        : title.contains("Local")
                            ? Icons.location_city
                            : Icons.forum,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title and description
                Expanded(
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

                // Live status indicator
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThemeConstants.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: ThemeConstants.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: ThemeConstants.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Participants section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                // Stack of participant avatars
                SizedBox(
                  width: 65,
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(
                      min(3, participantCount),
                      (index) => Positioned(
                        left: index * 18.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color.lerp(accentColor, Colors.white, 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardBackgroundColor!,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getInitial(index),
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Small spacing
                const SizedBox(width: 4),

                // Participant count
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black12
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$participantCount ${participantCount == 1 ? 'member' : 'members'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Join button with fixed styling
                ElevatedButton(
                  onPressed: () {
                    // Navigate to room detail page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailPage(
                          title: title,
                          description: description,
                          type: title.contains("Weather")
                              ? "weather"
                              : title.contains("Local")
                                  ? "local"
                                  : "events",
                          participantCount: participantCount,
                          isActive: isActive,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TextStrings.joinRoom,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitial(int index) {
    const List<String> initials = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'J',
      'K',
      'M',
      'S',
      'T'
    ];
    return initials[index % initials.length];
  }
}
