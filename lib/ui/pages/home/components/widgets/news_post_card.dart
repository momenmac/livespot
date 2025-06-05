import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class NewsPostCard extends StatelessWidget {
  final Post post;
  final Function(Post, bool)? onVote;

  const NewsPostCard({
    super.key,
    required this.post,
    this.onVote,
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
              child: post.hasMedia
                  ? Image.network(
                      post.mediaUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildPlaceholderImage(
                            showProgressIndicator: true,
                            progress: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null);
                      },
                    )
                  : _buildPlaceholderImage(),
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
                        post.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (post.author.isVerified)
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
                  post.content,
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
                      post.location.address ?? "Unknown location",
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
                      timeago.format(post.createdAt),
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
                    _buildHonestyRating(post.honestyScore),
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
                      Icons.thumb_up_outlined,
                      '${post.upvotes}',
                      onPressed: () => onVote?.call(post, true),
                    ),
                    _buildActionButton(
                      Icons.thumb_down_outlined,
                      '${post.downvotes}',
                      onPressed: () => onVote?.call(post, false),
                    ),
                    _buildActionButton(
                      Icons.chat_bubble_outline,
                      TextStrings.comments,
                      onPressed: () => _navigateToDetail(context),
                    ),
                    _buildActionButton(
                      Icons.share_outlined,
                      TextStrings.share,
                    ),
                    _buildActionButton(
                      Icons.flag_outlined,
                      TextStrings.reportPost,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(
      {bool showProgressIndicator = false, double? progress}) {
    return Container(
      color: ThemeConstants.greyLight,
      alignment: Alignment.center,
      child: showProgressIndicator
          ? CircularProgressIndicator(value: progress)
          : const Icon(Icons.image, size: 64, color: ThemeConstants.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51), // 0.2 * 255 = 51
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$rating%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: post.title,
          description: post.content,
          imageUrl: post.hasMedia ? post.mediaUrls.first : '',
          location: post.location.address ?? "Unknown location",
          time: timeago.format(post.createdAt),
          honesty: post.honestyScore,
          upvotes: post.upvotes,
          comments: post.isInThread
              ? 0
              : 0, // Fixed to use isInThread instead of inThread
          isVerified: post.author.isVerified,
        ),
      ),
    );
  }
}
