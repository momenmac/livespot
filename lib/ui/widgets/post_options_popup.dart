import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:share_plus/share_plus.dart';

class PostOptionsPopup extends StatelessWidget {
  final Post? post;
  final int postId;

  const PostOptionsPopup({
    super.key,
    this.post,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Post Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildOptionItem(
            context: context,
            icon: Icons.share_outlined,
            label: 'Share Post',
            onTap: () {
              Navigator.pop(context);
              _sharePost(context);
            },
          ),
          _buildOptionItem(
            context: context,
            icon: Icons.bookmark_border,
            label: 'Save Post',
            onTap: () {
              Navigator.pop(context);
              _savePost(context);
            },
          ),
          _buildOptionItem(
            context: context,
            icon: Icons.report_outlined,
            label: 'Report Post',
            onTap: () {
              Navigator.pop(context);
              _reportPost(context);
            },
          ),
          _buildOptionItem(
            context: context,
            icon: Icons.block_outlined,
            label: 'Block User',
            onTap: () {
              Navigator.pop(context);
              _blockUser(context);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : null,
        ),
      ),
      onTap: onTap,
    );
  }

  void _sharePost(BuildContext context) {
    final String title = post?.title ?? 'Check out this post!';
    final String content = 'Check out this post: $title';
    Share.share(content);
  }

  void _savePost(BuildContext context) {
    // Implement save post functionality
    ResponsiveSnackBar.showSuccess(
      context: context,
      message: 'Post saved successfully',
    );
  }

  void _reportPost(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text(
          'Why are you reporting this post?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ResponsiveSnackBar.showInfo(
                context: context,
                message: 'Report submitted',
              );
            },
            child: const Text('Submit Report'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _blockUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? You will no longer see their posts or messages.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ResponsiveSnackBar.showInfo(
                context: context,
                message: 'User blocked',
              );
            },
            child: const Text('Block'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
