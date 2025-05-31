import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api/notification_api_service.dart';

class FriendRequestDialog extends StatefulWidget {
  final String fromUserId;
  final String fromUserName;
  final String fromUserAvatar;
  final String requestId;

  const FriendRequestDialog({
    super.key,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserAvatar,
    required this.requestId,
  });

  @override
  State<FriendRequestDialog> createState() => _FriendRequestDialogState();
}

class _FriendRequestDialogState extends State<FriendRequestDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Friend Request',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                'Someone wants to connect',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // User Avatar and Name
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.2),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: widget.fromUserAvatar.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.fromUserAvatar,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color:
                                          theme.primaryColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.person,
                                        size: 40,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color:
                                          theme.primaryColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.person,
                                        size: 40,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.fromUserName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'wants to be your friend',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    if (_isProcessing)
                      const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Row(
                        children: [
                          // Decline Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleResponse(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                foregroundColor:
                                    isDark ? Colors.white : Colors.black87,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Accept Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleResponse(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleResponse(bool accepted) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Send response to Django backend
      final success = await NotificationApiService.respondToFriendRequest(
        requestId: widget.requestId,
        accepted: accepted,
        message:
            accepted ? 'Friend request accepted' : 'Friend request declined',
      );

      if (mounted) {
        Navigator.of(context).pop();

        // Show success or error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (accepted
                      ? 'Friend request accepted! 🎉'
                      : 'Friend request declined')
                  : 'Failed to respond to friend request',
            ),
            backgroundColor: success
                ? (accepted ? Colors.green : Colors.orange)
                : Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}
