import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_detail.dart';

class ChatDetailPage extends StatefulWidget {
  final MessagesController controller;
  final Conversation conversation;

  const ChatDetailPage({
    Key? key,
    required this.controller,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid updating state during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.selectConversation(widget.conversation);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No app bar - the MessageDetail widget will provide its own header
      body: SafeArea(
        child: MessageDetail(
          controller: widget.controller,
          conversation: widget.conversation,
          onBackPressed: () {
            widget.controller.clearSelectedConversation();
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? ThemeConstants.darkBackgroundColor
          : ThemeConstants.lightBackgroundColor,
      // Explicitly set to null to hide the bottom navigation bar
      bottomNavigationBar: null,
    );
  }
}
