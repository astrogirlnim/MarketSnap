import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/core/services/messaging_service.dart';
import 'package:marketsnap/features/auth/application/auth_service.dart';
import 'package:marketsnap/main.dart';
import 'package:marketsnap/features/messaging/presentation/widgets/chat_bubble.dart';
import 'package:marketsnap/features/messaging/presentation/widgets/message_input_bar.dart';

class ChatScreen extends StatefulWidget {
  final VendorProfile otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = messagingService;
  final AuthService _authService = authService;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser!.uid;

    // Mark conversation as read when entering the screen
    _messagingService.markConversationAsRead(
      userId1: _currentUserId,
      userId2: widget.otherUser.uid,
      currentUserId: _currentUserId,
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isNotEmpty) {
      _messagingService.sendMessage(
        fromUid: _currentUserId,
        toUid: widget.otherUser.uid,
        text: text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.displayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagingService.getConversationMessages(
                userId1: _currentUserId,
                userId2: widget.otherUser.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Say hello!'));
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.fromUid == _currentUserId;
                    return ChatBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),
          MessageInputBar(onSendMessage: _sendMessage),
        ],
      ),
    );
  }
}
