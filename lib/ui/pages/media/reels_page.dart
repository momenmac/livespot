import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/ui/pages/media/tiktok_style_reels_page.dart';

/// This class now serves as a wrapper that redirects to the TikTokStyleReelsPage
/// This approach maintains backward compatibility with existing code that references ReelsPage
class ReelsPage extends StatelessWidget {
  final Post post;
  final int initialIndex;

  const ReelsPage({
    super.key,
    required this.post,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Simply redirect to our enhanced TikTok-style implementation
    return TikTokStyleReelsPage(post: post, initialIndex: initialIndex);
  }
}
