import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/core/services/messaging_service.dart';
import 'package:marketsnap/features/auth/application/auth_service.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:marketsnap/core/services/profile_update_notifier.dart';
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
  final ProfileUpdateNotifier _profileUpdateNotifier = ProfileUpdateNotifier();
  String? _currentUserId;
  String? _authError;
  VendorProfile
  _otherUser; // Keep a mutable copy to update when profile changes

  _ChatScreenState()
    : _otherUser = VendorProfile(
        uid: '',
        displayName: '',
        stallName: '',
        marketCity: '',
      );

  @override
  void initState() {
    super.initState();
    _otherUser = widget.otherUser; // Initialize with the passed user
    _initializeUser();
    _listenToProfileUpdates();
  }

  /// Listen to profile updates for the other user
  void _listenToProfileUpdates() {
    _profileUpdateNotifier.allProfileUpdates.listen((update) {
      final uid = update['uid'] as String;

      // Check if this update is for the user we're chatting with
      if (uid == _otherUser.uid) {
        if (update['type'] == 'delete') {
          // Handle user deletion (maybe show a message that user is no longer available)
          debugPrint('[ChatScreen] Other user profile deleted: $uid');
        } else {
          // Update the displayed user information
          setState(() {
            _otherUser = _otherUser.copyWith(
              displayName: update['displayName'] as String,
              avatarURL:
                  (update['avatarURL'] as String?) ?? _otherUser.avatarURL,
            );
          });
          debugPrint(
            '[ChatScreen] 🔄 Updated other user profile: ${_otherUser.displayName}',
          );
        }
      }
    });
  }

  void _initializeUser() {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _authError = 'Not authenticated. Please log in again.';
      });
      return;
    }

    _currentUserId = user.uid;
    debugPrint(
      '[ChatScreen] Initialized for user: $_currentUserId, chatting with: ${_otherUser.uid}',
    );

    // Mark conversation as read when entering the screen
    if (_currentUserId != null) {
      _messagingService
          .markConversationAsRead(
            userId1: _currentUserId!,
            userId2: _otherUser.uid,
            currentUserId: _currentUserId!,
          )
          .catchError((error) {
            debugPrint(
              '[ChatScreen] Error marking conversation as read: $error',
            );
          });
    }
  }

  void _sendMessage(String text) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages')),
      );
      return;
    }

    if (text.trim().isEmpty) return;

    try {
      debugPrint(
        '[ChatScreen] Sending message from $_currentUserId to ${_otherUser.uid}: $text',
      );
      await _messagingService.sendMessage(
        fromUid: _currentUserId!,
        toUid: _otherUser.uid,
        text: text.trim(),
      );
      debugPrint('[ChatScreen] Message sent successfully');
    } catch (error) {
      debugPrint('[ChatScreen] Error sending message: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_otherUser.displayName),
          backgroundColor: AppColors.eggshell,
          foregroundColor: AppColors.soilCharcoal,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Authentication Error',
                style: AppTypography.bodyLG.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _authError!,
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_otherUser.displayName),
          backgroundColor: AppColors.eggshell,
          foregroundColor: AppColors.soilCharcoal,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUser.displayName),
        backgroundColor: AppColors.eggshell,
        foregroundColor: AppColors.soilCharcoal,
        elevation: 0,
      ),
      backgroundColor: AppColors.cornsilk,
      body: Column(
        children: [
          // Ephemeral messaging info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sunsetAmber.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.sunsetAmber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16, color: AppColors.sunsetAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages disappear after 24 hours',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.sunsetAmber,
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagingService.getConversationMessages(
                userId1: _currentUserId!,
                userId2: _otherUser.uid,
              ),
              builder: (context, snapshot) {
                debugPrint(
                  '[ChatScreen] StreamBuilder state: ${snapshot.connectionState}',
                );

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    '[ChatScreen] StreamBuilder error: ${snapshot.error}',
                  );
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: AppTypography.bodyLG.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Rebuild to retry
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                debugPrint('[ChatScreen] Loaded ${messages.length} messages');

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: AppTypography.bodyLG),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello to ${_otherUser.displayName}!',
                          style: AppTypography.body.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.fromUid == _currentUserId;

                    // Debug logging to help diagnose bubble alignment
                    debugPrint(
                      '[ChatScreen] Message $index: fromUid=${message.fromUid}, currentUserId=$_currentUserId, isMe=$isMe, text="${message.text}"',
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChatBubble(message: message, isMe: isMe),
                    );
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
