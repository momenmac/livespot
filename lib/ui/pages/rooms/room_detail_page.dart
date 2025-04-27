import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class RoomDetailPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int participantCount;
  final bool isActive;

  const RoomDetailPage({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    required this.participantCount,
    required this.isActive,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  bool _isMuted = false;
  bool _isHandRaised = false;
  bool _isSpeaker = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Create room accent color
    final Color accentColor = widget.type == "weather"
        ? ThemeConstants.orange
        : (widget.type == "local"
            ? ThemeConstants.green
            : ThemeConstants.primaryColor);

    // Text colors based on theme
    final textColor = isDarkMode ? Colors.white : ThemeConstants.black;
    final secondaryTextColor =
        isDarkMode ? Colors.white70 : ThemeConstants.black.withOpacity(0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? theme.scaffoldBackgroundColor : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.type == "weather"
                    ? Icons.cloud
                    : widget.type == "local"
                        ? Icons.location_city
                        : widget.type == "books"
                            ? Icons.book
                            : widget.type == "tech"
                                ? Icons.computer
                                : widget.type == "fitness"
                                    ? Icons.fitness_center
                                    : Icons.forum,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isActive)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: ThemeConstants.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: ThemeConstants.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· ${widget.participantCount} members',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: textColor,
            ),
            onPressed: () {
              // Show room options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Room description card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? theme.cardColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.black12 : Colors.grey.shade200,
              ),
            ),
            child: Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
              ),
            ),
          ),

          // Stage section title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Text(
                  'On Stage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_isSpeaker)
                  OutlinedButton.icon(
                    onPressed: () {
                      // Leave stage
                      setState(() {
                        _isSpeaker = false;
                      });
                    },
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('Leave Stage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThemeConstants.red,
                      side: const BorderSide(color: ThemeConstants.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      // Join stage
                      setState(() {
                        _isSpeaker = true;
                        _isHandRaised = false;
                      });
                    },
                    icon: const Icon(Icons.mic, size: 16),
                    label: const Text('Join Stage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Speakers area
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? theme.cardColor.withOpacity(0.5)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSpeakerAvatar('Jane', 'Host', true, accentColor),
                    _buildSpeakerAvatar('Mike', 'Co-host', false, accentColor),
                    if (_isSpeaker)
                      _buildSpeakerAvatar('You', null, _isMuted, accentColor)
                    else
                      _buildEmptySpeakerSlot(accentColor),
                  ],
                ),
              ],
            ),
          ),

          // Audience section title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                Text(
                  'In Audience (${widget.participantCount - 2})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Audience grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: widget.participantCount - 2,
              itemBuilder: (context, index) {
                // Mock audience member names
                final names = [
                  'Alex',
                  'Taylor',
                  'Jordan',
                  'Sam',
                  'Casey',
                  'Robin',
                  'Morgan',
                  'Drew',
                  'Bailey',
                  'Riley',
                  'Quinn',
                  'Avery',
                  'Cameron',
                  'Blake',
                  'Jesse',
                  'Skyler'
                ];

                final handRaised = index % 5 == 0; // Some have hands raised

                return _buildAudienceMember(
                    names[index % names.length], handRaised, accentColor);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? theme.cardColor : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                  });
                },
                isActive: _isMuted,
                color: _isMuted ? ThemeConstants.red : accentColor,
                enabled: _isSpeaker,
              ),
              _buildControlButton(
                icon: Icons.pan_tool,
                label: _isHandRaised ? 'Lower Hand' : 'Raise Hand',
                onPressed: () {
                  setState(() {
                    _isHandRaised = !_isHandRaised;
                  });
                },
                isActive: _isHandRaised,
                color: accentColor,
                enabled: !_isSpeaker,
              ),
              _buildControlButton(
                icon: Icons.comment,
                label: 'Chat',
                onPressed: () {
                  // Open chat
                  _showChatBottomSheet(context);
                },
                color: accentColor,
              ),
              _buildControlButton(
                icon: Icons.logout,
                label: 'Leave',
                onPressed: () {
                  Navigator.of(context).pop();
                },
                color: ThemeConstants.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerAvatar(
      String name, String? role, bool isMuted, Color accentColor) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: role != null ? accentColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ),
            if (isMuted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: ThemeConstants.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        if (role != null)
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySpeakerSlot(Color accentColor) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.add,
            color: accentColor.withOpacity(0.5),
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Empty slot',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceMember(String name, bool handRaised, Color accentColor) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            if (handRaised)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pan_tool,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isActive = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? color : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : color,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDarkMode ? theme.scaffoldBackgroundColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Chat header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Chat',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Chat messages
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: 10, // Mock messages count
                  itemBuilder: (context, index) {
                    // Mock message data
                    final bool isMe = index % 3 == 0;
                    final String sender = isMe
                        ? 'You'
                        : ['Jane', 'Mike', 'Alex', 'Taylor'][index % 4];
                    final String message = [
                      'Hello everyone!',
                      'Great discussion today!',
                      'I have a question about this topic.',
                      'What do you all think about the latest developments?',
                      'Thanks for sharing your insights!',
                    ][index % 5];

                    return _buildChatMessage(sender, message, isMe);
                  },
                ),
              ),

              // Message input
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
                decoration: BoxDecoration(
                  color: isDarkMode ? theme.cardColor : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeConstants.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          // Send message
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatMessage(String sender, String message, bool isMe) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ThemeConstants.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  sender.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sender,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isMe ? ThemeConstants.primaryColor : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '3m ago',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? ThemeConstants.primaryColor
                        : (isDarkMode ? theme.cardColor : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 40), // Balance the layout
        ],
      ),
    );
  }
}
