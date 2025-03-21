import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class NewsPostCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String location;
  final String time;
  final int honesty;
  final int upvotes;
  final int comments;
  final bool isVerified;

  const NewsPostCard({
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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: ThemeConstants.greyLight,
                alignment: Alignment.center,
                child: const Icon(Icons.image,
                    size: 64, color: ThemeConstants.grey),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Verification Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeConstants.primaryColorLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified,
                                size: 16, color: ThemeConstants.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              TextStrings.verified,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ThemeConstants.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Location and Time
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: ThemeConstants.grey),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeConstants.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time,
                        size: 16, color: ThemeConstants.grey),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Honesty Rating
                Row(
                  children: [
                    Text(
                      '${TextStrings.honestyRating}: ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    _buildHonestyRating(honesty),
                  ],
                ),

                const SizedBox(height: 12),

                // Actions - Replace Row with Wrap to handle overflow
                Wrap(
                  spacing: 12, // horizontal spacing
                  runSpacing: 8, // vertical spacing
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                        Icons.thumb_up_outlined, TextStrings.upvote),
                    _buildActionButton(
                        Icons.thumb_down_outlined, TextStrings.downvote),
                    _buildActionButton(
                        Icons.chat_bubble_outline, TextStrings.comments),
                    _buildActionButton(Icons.share_outlined, TextStrings.share),
                    _buildActionButton(
                        Icons.flag_outlined, TextStrings.reportPost),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonestyRating(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$rating%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Use minimum required width
          children: [
            Icon(icon, size: 16, color: ThemeConstants.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ThemeConstants.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
