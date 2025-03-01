import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSent;
  final VoidCallback? onLongPress;
  final Function(Message)? onReply;

  const VoiceMessageBubble({
    Key? key,
    required this.message,
    required this.isSent,
    this.onLongPress,
    this.onReply,
  }) : super(key: key);

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _playbackProgress = 0;
  bool _isHovering = false;
  // Add a key to better control popup menu state
  final GlobalKey _popupMenuKey = GlobalKey();

  @override
  void dispose() {
    // Ensure any menu is dismissed to prevent context errors
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // This safely dismisses any open menu when the widget is disposed
        Navigator.of(context, rootNavigator: true).popUntil((route) {
          return route is! PopupRoute;
        });
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bubbleColor = widget.isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;
    final textColor =
        widget.isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    // Format the audio duration
    final audioDuration = widget.message.voiceDuration ?? 0; // seconds
    final formattedDuration = _formatDuration(audioDuration);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          InkWell(
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.2)
                              : ThemeConstants.primaryColor.withOpacity(0.1),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: widget.isSent
                                ? Colors.white
                                : ThemeConstants.primaryColor,
                            size: 20,
                          ),
                          onPressed: _togglePlayback,
                          padding: EdgeInsets.zero,
                          splashRadius: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Audio waveform visualization
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Waveform visualization
                            SizedBox(
                              height: 24,
                              child: Stack(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      15,
                                      (index) {
                                        // Create a pattern of bars with varying heights
                                        final height = 4 +
                                            (index % 3 == 0
                                                ? 12.0
                                                : index % 2 == 0
                                                    ? 8.0
                                                    : 4.0);
                                        return Container(
                                          width: 2.5,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: _getBarColor(index),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Progress slider
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 8),
                                activeTrackColor: widget.isSent
                                    ? Colors.white
                                    : ThemeConstants.primaryColor,
                                inactiveTrackColor: widget.isSent
                                    ? Colors.white.withOpacity(0.3)
                                    : ThemeConstants.primaryColor
                                        .withOpacity(0.3),
                                thumbColor: widget.isSent
                                    ? Colors.white
                                    : ThemeConstants.primaryColor,
                                overlayColor: widget.isSent
                                    ? Colors.white.withOpacity(0.2)
                                    : ThemeConstants.primaryColor
                                        .withOpacity(0.2),
                              ),
                              child: Slider(
                                value: _playbackProgress,
                                onChanged: (value) {
                                  setState(() {
                                    _playbackProgress = value;
                                  });
                                  // TODO: Implement seek functionality
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Duration
                      Text(
                        formattedDuration,
                        style: TextStyle(
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.7)
                              : textColor?.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Timestamp
                      Text(
                        DateFormat('HH:mm').format(widget.message.timestamp),
                        style: TextStyle(
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.7)
                              : theme.textTheme.bodySmall?.color,
                          fontSize: 11,
                        ),
                      ),
                      // Status indicators
                      if (widget.isSent && widget.message.status != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _buildStatusIcon(widget.message.status!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Options button (three dots) that appears on hover
          if (_isHovering)
            Positioned(
              top: 2,
              // Position based on message direction
              right: widget.isSent ? null : -4,
              left: widget.isSent ? -4 : null,
              child: _buildOptionsButton(context),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(top: 4, right: 4, left: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF383838)
            : const Color(0xFFFFFFFF),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: PopupMenuButton<String>(
          key: _popupMenuKey,
          padding: EdgeInsets.zero,
          tooltip: "Message options",
          icon: Icon(
            Icons.more_horiz,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF444444),
            size: 18,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.under,
          onCanceled: () {
            if (mounted) setState(() {});
          },
          itemBuilder: (context) => [
            // Reply option
            PopupMenuItem<String>(
              value: 'reply',
              child: Row(
                children: [
                  Icon(Icons.reply,
                      color: ThemeConstants.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.reply),
                ],
              ),
            ),

            // Forward option
            PopupMenuItem<String>(
              value: 'forward',
              child: Row(
                children: [
                  Icon(Icons.forward,
                      color: ThemeConstants.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.forward),
                ],
              ),
            ),

            // Delete option
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      color: ThemeConstants.red, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.delete),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (!mounted) return; // Skip if widget is unmounted

            // Get controller from message for direct actions
            final controller = widget.message.controller;

            switch (value) {
              case 'reply':
                // First try to use direct controller method
                if (controller != null) {
                  controller.setReplyToMessage(widget.message);
                }
                // Fallback to the callback if controller isn't available
                else if (widget.onReply != null) {
                  widget.onReply!(widget.message);
                }
                break;
              case 'forward':
                if (controller != null) {
                  // Direct use of _showForwardOptions with the message
                  _showForwardOptions(context, widget.message);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;
              case 'delete':
                if (controller != null) {
                  controller.deleteMessage(widget.message);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;
            }
          },
        ),
      ),
    );
  }

  Color _getBarColor(int index) {
    // Determine if this bar is part of the played section
    final isPlayed = index / 15 <= _playbackProgress;

    if (widget.isSent) {
      return isPlayed ? Colors.white : Colors.white.withOpacity(0.4);
    } else {
      return isPlayed
          ? ThemeConstants.primaryColor
          : ThemeConstants.primaryColor.withOpacity(0.4);
    }
  }

  void _togglePlayback() {
    // Mock playback functionality
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        // Start animation for progress
        _animatePlayback();
      }
    });
  }

  void _animatePlayback() {
    // Mock playback progress
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isPlaying) {
        setState(() {
          _playbackProgress += 0.01;
          if (_playbackProgress >= 1.0) {
            _playbackProgress = 0.0;
            _isPlaying = false;
          } else {
            _animatePlayback();
          }
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlueAccent,
        );
    }
  }

  void _showForwardOptions(BuildContext context, Message message) {
    final controller = message.controller;
    if (controller == null) return;

    // Get the current context which will be used to show the bottom sheet
    final currentContext = context;

    // Create a controller for the search field
    final TextEditingController searchController = TextEditingController();

    // Track filtered conversations
    List<Conversation> filteredConversations =
        List.from(controller.conversations);

    if (controller.conversations.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(TextStrings.noConversationsForward)));
      return;
    }

    // Show modal bottom sheet with forward options
    // ...copy the implementation from MessageBubble...
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}
