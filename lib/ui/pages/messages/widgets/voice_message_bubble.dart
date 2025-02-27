import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSent;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _progressTimer?.cancel();
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
    setState(() {
      _isPlaying = true;
      _elapsedSeconds = 0;
      _progress = 0.0;
    });

    final totalDuration = widget.message.voiceDuration ?? 30;
    final updateInterval = 100; // milliseconds
    final steps = (totalDuration * 1000) ~/ updateInterval;
    final progressIncrement = 1.0 / steps;

    _progressTimer =
        Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      if (_progress >= 1.0) {
        _stopPlayback();
      } else {
        setState(() {
          _progress += progressIncrement;
          _elapsedSeconds = (_progress * totalDuration).floor();
        });
      }
    });

    // Here you would add actual audio playback code
  }

  void _stopPlayback() {
    _progressTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _progress = 0.0;
      _elapsedSeconds = 0;
    });

    // Here you would stop the actual audio playback
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

    final bubbleColor = widget.isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;

    final textColor =
        widget.isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    final totalDuration = widget.message.voiceDuration ?? 0;
    final displayDuration = _isPlaying
        ? _formatDuration(_elapsedSeconds)
        : _formatDuration(totalDuration);

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: textColor,
              size: 28,
            ),
            onPressed: _togglePlayback,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: textColor?.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayDuration,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor?.withOpacity(0.7),
                      ),
                    ),
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: textColor?.withOpacity(0.7),
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
}
