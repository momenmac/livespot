import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSent;
  final Function(Message)?
      onLongPress; // Changed from VoidCallback? to Function(Message)?
  final Function(Message)?
      onSwipeReply; // Changed from onReply to onSwipeReply to match MessageBubble

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.onLongPress,
    this.onSwipeReply, // Updated parameter name
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  late AnimationController _animController;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  int _totalSeconds = 0;
  bool _disposed = false;
  // Add a variable to track milliseconds for more precise timing
  int _elapsedMs = 0;

  // Sound wave points for a more realistic waveform
  final List<double> _wavePoints = [
    0.2,
    0.5,
    0.3,
    0.7,
    0.4,
    0.9,
    0.5,
    0.6,
    0.3,
    0.8,
    0.4,
    0.7,
    0.3,
    0.5,
    0.8,
    0.6,
    0.2,
    0.4,
    0.7,
    0.5,
    0.3,
    0.6,
    0.8,
    0.4,
    0.7,
    0.2,
    0.5,
    0.8,
    0.3,
    0.6
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animController.repeat(reverse: true);
    _totalSeconds = widget.message.voiceDuration ?? 30;
  }

  @override
  void dispose() {
    _disposed = true;
    _animController.dispose();
    _stopPlayback(); // Make sure to stop any ongoing timers
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_disposed) return;

    // Reset or continue playback state
    setState(() {
      _isPlaying = true;
      // Start from beginning if we're at the end
      if (_playbackProgress >= 0.99) {
        _elapsedSeconds = 0;
        _elapsedMs = 0;
        _playbackProgress = 0.0;
      }
    });

    // Use a fixed interval for smooth updates
    const updateInterval = 100; // milliseconds (10 updates per second)
    final totalMs = _totalSeconds * 1000;

    _progressTimer =
        Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      // Update elapsed time in milliseconds for more precise tracking
      _elapsedMs += updateInterval;

      if (!_disposed) {
        setState(() {
          // Update seconds display (integer division to get whole seconds)
          _elapsedSeconds = _elapsedMs ~/ 1000;

          // Update progress as a fraction of total time
          _playbackProgress = _elapsedMs / totalMs;

          // Check if playback is complete
          if (_elapsedMs >= totalMs) {
            _playbackProgress = 1.0;
            _elapsedSeconds = _totalSeconds;
            _stopPlayback();
          }
        });
      }
    });
  }

  void _stopPlayback() {
    _progressTimer?.cancel();
    _progressTimer = null;

    if (!_disposed) {
      setState(() {
        _isPlaying = false;
        // We don't reset progress here so it stays where it stopped
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Create gradient for sent messages
    final bubbleGradient = widget.isSent
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThemeConstants.primaryColor,
              ThemeConstants.primaryColor
                  .withBlue(min(255, ThemeConstants.primaryColor.blue + 40)),
            ],
          )
        : null;

    final bubbleColor = widget.isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;

    final textColor = widget.isSent
        ? Colors.white
        : isDarkMode
            ? Colors.white
            : Colors.black87;

    final timeDisplay = _isPlaying
        ? '${_formatDuration(_elapsedSeconds)} / ${_formatDuration(_totalSeconds)}'
        : _formatDuration(widget.message.voiceDuration ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: widget.onLongPress != null
              ? () => widget.onLongPress!(
                  widget.message) // Pass the message to the callback
              : null,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              gradient: bubbleGradient,
              color: bubbleGradient == null ? bubbleColor : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.isSent
                      ? ThemeConstants.primaryColor.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildPlayButton(widget.isSent),
                      const SizedBox(width: 16),
                      Expanded(child: _buildWaveformArea(textColor)),
                    ],
                  ),

                  // Time display and status with better styling
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Time display with icon
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: widget.isSent
                                  ? Colors.white.withOpacity(0.8)
                                  : theme.textTheme.bodySmall?.color
                                          ?.withOpacity(0.7) ??
                                      Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: widget.isSent
                                    ? Colors.white.withOpacity(0.9)
                                    : theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),

                        // Message time and status
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm')
                                  .format(widget.message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isSent
                                    ? Colors.white.withOpacity(0.8)
                                    : theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.8),
                              ),
                            ),
                            if (widget.isSent)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _buildStatusIcon(widget.message.status),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isSent) {
    return GestureDetector(
      onTap: _togglePlayback,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSent
              ? Colors.white.withOpacity(_isPlaying ? 0.3 : 0.2)
              : ThemeConstants.primaryColor.withOpacity(_isPlaying ? 0.2 : 0.1),
          border: Border.all(
            color: isSent
                ? Colors.white.withOpacity(0.5)
                : ThemeConstants.primaryColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: _isPlaying
              ? [
                  BoxShadow(
                    color: isSent
                        ? Colors.white.withOpacity(0.3)
                        : ThemeConstants.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: isSent ? Colors.white : ThemeConstants.primaryColor,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformArea(Color textColor) {
    // Get a more accurate width calculation that doesn't depend on screen size
    final availableWidth = 200.0; // Fixed width for progress bar

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: availableWidth,
            child: Stack(
              children: [
                // Background track
                Container(
                  height: 4,
                  width: availableWidth,
                  color: Colors.white.withOpacity(0.2),
                ),

                // Animated progress indicator with exact width calculation
                AnimatedContainer(
                  duration: const Duration(
                      milliseconds:
                          100), // Faster updates for smoother animation
                  height: 4,
                  width: availableWidth * _playbackProgress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isSent
                          ? [Colors.white.withOpacity(0.9), Colors.white]
                          : [
                              ThemeConstants.primaryColor.withOpacity(0.7),
                              ThemeConstants.primaryColor,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    // ...existing code...
                  ),
                ),

                // Thumb indicator with more precise positioning
                if (_playbackProgress > 0)
                  Positioned(
                    left: (availableWidth * _playbackProgress) - 6,
                    top: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          // ...existing code...
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Beautiful waveform
        SizedBox(
          height: 35,
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(
                  _wavePoints.length,
                  (index) {
                    // Determine if this bar should be highlighted based on progress
                    final isFilled =
                        (index / _wavePoints.length) <= _playbackProgress;

                    // Calculate dynamic amplitude based on the original wave point value
                    double amplitude = _wavePoints[index];

                    // Add animation effect if playing
                    if (_isPlaying) {
                      final animOffset =
                          sin((_animController.value * pi * 2) + (index / 5)) *
                              0.15;

                      amplitude = (amplitude + animOffset).clamp(0.1, 1.0);
                    }

                    // Scale the amplitude to set the bar height
                    final barHeight = 5 + (amplitude * 30);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 2,
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isFilled
                            ? (widget.isSent
                                ? Colors.white.withOpacity(0.9)
                                : ThemeConstants.primaryColor.withOpacity(0.7))
                            : (widget.isSent
                                ? Colors.white.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3)),
                        boxShadow: _isPlaying && isFilled
                            ? [
                                BoxShadow(
                                  color: widget.isSent
                                      ? Colors.white.withOpacity(0.3)
                                      : ThemeConstants.primaryColor
                                          .withOpacity(0.3),
                                  blurRadius: 3,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    Color iconColor = widget.isSent ? Colors.white70 : Colors.grey;

    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time_rounded, size: 12, color: iconColor);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 12, color: iconColor);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 12, color: iconColor);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded,
            size: 12, color: Colors.lightBlueAccent);
      case MessageStatus.failed:
        return Icon(Icons.error_outline_rounded,
            size: 12, color: ThemeConstants.red);
    }
  }
}
