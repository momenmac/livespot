import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/posts/create_post_page.dart';

/// A floating action button for creating new posts that can be added to any screen
/// in your application where users should be able to create posts.
class CreatePostFAB extends StatelessWidget {
  final String? heroTag;
  final VoidCallback? onCreated;

  const CreatePostFAB({
    super.key,
    this.heroTag,
    this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag ?? 'createPostFAB',
      backgroundColor: ThemeConstants.primaryColor,
      onPressed: () async {
        // Navigate to create post page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );

        // If post was created successfully, call the onCreated callback
        if (result == true && onCreated != null) {
          onCreated!();
        }
      },
      child: const Icon(
        Icons.add_comment,
        color: Colors.white,
      ),
    );
  }
}

/// Extended version of CreatePostFAB with speed dial functionality
/// This provides multiple options when pressed
class CreatePostSpeedDial extends StatefulWidget {
  final String? heroTag;
  final VoidCallback? onCreated;
  final VoidCallback? onMapOpened;

  const CreatePostSpeedDial({
    super.key,
    this.heroTag,
    this.onCreated,
    this.onMapOpened,
  });

  @override
  State<CreatePostSpeedDial> createState() => _CreatePostSpeedDialState();
}

class _CreatePostSpeedDialState extends State<CreatePostSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Create text post
        if (_isOpen) ...[
          _buildSpeedDialItem(
            context,
            'Create Text Post',
            Icons.text_fields,
            Colors.blue,
            () => _navigateToCreatePost(context, 'text'),
          ),
          const SizedBox(height: 12),

          // Create photo post
          _buildSpeedDialItem(
            context,
            'Create Photo Post',
            Icons.camera_alt,
            Colors.green,
            () => _navigateToCreatePost(context, 'photo'),
          ),
          const SizedBox(height: 12),

          // View on map
          _buildSpeedDialItem(
            context,
            'View on Map',
            Icons.map,
            Colors.orange,
            () {
              setState(() => _isOpen = false);
              _animationController.reverse();
              if (widget.onMapOpened != null) {
                widget.onMapOpened!();
              }
            },
          ),
          const SizedBox(height: 24),
        ],

        // Main FAB
        FloatingActionButton(
          heroTag: widget.heroTag ?? 'createPostSpeedDialFAB',
          backgroundColor: ThemeConstants.primaryColor,
          onPressed: _toggle,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _animationController,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Button
        FloatingActionButton.small(
          heroTag: '${widget.heroTag ?? 'speedDial'}_$label',
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }

  void _navigateToCreatePost(BuildContext context, String type) async {
    setState(() => _isOpen = false);
    _animationController.reverse();

    // Navigate to create post page with type parameter
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(),
      ),
    );

    // If post was created successfully, call the onCreated callback
    if (result == true && widget.onCreated != null) {
      widget.onCreated!();
    }
  }
}
