import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

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
                  // View all rooms
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

        // FIXED: Increased height to prevent overflow
        SizedBox(
          height: 170,
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

    // Create room colors
    final Color accentColor = title.contains("Weather")
        ? ThemeConstants.orange
        : (title.contains("Local")
            ? ThemeConstants.green
            : ThemeConstants.primaryColor);

    final Color roomColor = accentColor.withOpacity(0.1);

    // Card background color based on theme
    final cardBackgroundColor = isDarkMode ? theme.cardColor : Colors.white;
    // We'll use this variable instead of backgroundColor
    final backgroundColor = cardBackgroundColor;

    // Shadow color based on theme
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.2)
        : Colors.black.withOpacity(0.05);

    // Text colors based on theme
    final textColor =
        isDarkMode ? theme.textTheme.bodyLarge?.color : ThemeConstants.black;

    final secondaryTextColor = isDarkMode
        ? theme.textTheme.bodyMedium?.color?.withOpacity(0.7)
        : ThemeConstants.black.withOpacity(0.7);

    // Border color for chips
    final borderColor = isDarkMode ? theme.dividerColor : ThemeConstants.grey;

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color accent at top
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          // Content with optimized spacing
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and active status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ThemeConstants.green.withOpacity(0.2),
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

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(flex: 1),

                  // Members & Join button
                  Row(
                    children: [
                      // Members count with icon
                      Row(
                        children: [
                          Icon(Icons.people, size: 14, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            '$participantCount ${participantCount == 1 ? 'person' : 'people'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? theme.textTheme.bodySmall?.color
                                  : ThemeConstants.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Join button
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: const Size(60, 30),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          TextStrings.joinRoom,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
