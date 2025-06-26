import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/services/messaging_service.dart';
import 'package:marketsnap/features/profile/application/profile_service.dart';
import 'package:marketsnap/features/auth/application/auth_service.dart';
import 'package:marketsnap/features/messaging/presentation/widgets/conversation_list_item.dart';
import 'package:marketsnap/features/messaging/presentation/screens/chat_screen.dart';
import 'package:marketsnap/features/messaging/presentation/screens/vendor_discovery_screen.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:marketsnap/main.dart'; // Import main to access global services

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  // Use global service instances from main.dart
  final MessagingService _messagingService = messagingService;
  final ProfileService _profileService = profileService;
  final AuthService _authService = authService;

  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid ?? '';
    if (_currentUserId.isEmpty) {
      // Handle case where user is not logged in
      // This screen should not be accessible if user is not logged in
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid;
    
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppColors.eggshell,
          foregroundColor: AppColors.soilCharcoal,
          elevation: 0,
        ),
        backgroundColor: AppColors.cornsilk,
        body: const Center(
          child: Text('Please log in to see messages.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.eggshell,
        foregroundColor: AppColors.soilCharcoal,
        elevation: 0,
      ),
      backgroundColor: AppColors.cornsilk,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const VendorDiscoveryScreen(),
            ),
          );
        },
        backgroundColor: AppColors.marketBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Message>>(
        stream: _messagingService.getUserConversations(userId: currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading conversations',
                    style: AppTypography.bodyLG,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: AppTypography.bodyLG,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to start a new conversation',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final lastMessage = conversations[index];
              final otherUserId = lastMessage.fromUid == currentUserId 
                  ? lastMessage.toUid 
                  : lastMessage.fromUid;

              return FutureBuilder<VendorProfile?>(
                future: _profileService.loadProfileFromFirestore(otherUserId),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading...'),
                      subtitle: Text(''),
                    );
                  }

                  final otherUser = profileSnapshot.data;
                  if (otherUser == null) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Unknown User'),
                      subtitle: Text('Profile not found'),
                    );
                  }

                  // Calculate unread count for this conversation
                  return StreamBuilder<List<Message>>(
                    stream: _messagingService.getConversationMessages(
                      userId1: currentUserId,
                      userId2: otherUserId,
                    ),
                    builder: (context, messagesSnapshot) {
                      final messages = messagesSnapshot.data ?? [];
                      final unreadCount = messages
                          .where((msg) => msg.toUid == currentUserId && !msg.isRead)
                          .length;

                      return ConversationListItem(
                        otherParticipant: otherUser,
                        lastMessage: lastMessage,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(otherUser: otherUser),
                            ),
                          );
                        },
                        isUnread: unreadCount > 0,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
