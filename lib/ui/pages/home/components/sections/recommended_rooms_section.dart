import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class RecommendedRoomsSection extends StatelessWidget {
  const RecommendedRoomsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section - no changes needed
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TextStrings.recommendedRooms,
                style: const TextStyle(
                  fontSize: 18,
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
          height: 170, // Increased from 140px to 170px (+30px)
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildRoomCard(
                  "Current Events Discussion",
                  "Discussion on today's major events",
                  58,
                  true,
                ),
                _buildRoomCard(
                  "Local City Updates",
                  "Latest city developments and news",
                  24,
                  false,
                ),
                _buildRoomCard(
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
    String title,
    String description,
    int participantCount,
    bool isActive,
  ) {
    // Create room colors
    final Color accentColor = title.contains("Weather")
        ? ThemeConstants.orange
        : (title.contains("Local")
            ? ThemeConstants.green
            : ThemeConstants.primaryColor);

    final Color roomColor = accentColor.withOpacity(0.1);

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              padding:
                  const EdgeInsets.fromLTRB(12, 8, 12, 8), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and active status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

                  const SizedBox(height: 4), // Reduced from 6 to 4

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeConstants.black.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(flex: 1), // Use less space

                  // Members & Join button - UPDATED to remove duplication
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
                              color: ThemeConstants.grey,
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

  // Helper to get a random initial for member avatars
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
