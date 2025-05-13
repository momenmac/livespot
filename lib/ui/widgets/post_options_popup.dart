import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class PostOptionsPopup extends StatefulWidget {
  final Post? post;
  final int postId;

  const PostOptionsPopup({
    super.key,
    this.post,
    required this.postId,
  });

  @override
  State<PostOptionsPopup> createState() => _PostOptionsPopupState();
}

class _PostOptionsPopupState extends State<PostOptionsPopup> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Get the current saved state of the post
    final bool isSaved = widget.post?.isSaved ?? false;

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
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            label: isSaved ? 'Unsave Post' : 'Save Post',
            onTap: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    _toggleSavePost(context);
                  },
            isLoading: _isLoading,
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
    required VoidCallback? onTap,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
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
    final String title = widget.post?.title ?? 'Check out this post!';
    final String content = 'Check out this post: $title';
    Share.share(content);
  }

  void _toggleSavePost(BuildContext context) async {
    if (widget.post == null) {
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Error: Post information is missing',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final bool isSaved = widget.post!.isSaved ?? false;

      // Call the provider to toggle save status
      final success = await postsProvider.toggleSavePost(widget.post!.id);

      if (success) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: isSaved ? 'Post unsaved' : 'Post saved successfully',
        );
      } else {
        ResponsiveSnackBar.showError(
          context: context,
          message: postsProvider.errorMessage ?? 'Failed to update save status',
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Error: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
