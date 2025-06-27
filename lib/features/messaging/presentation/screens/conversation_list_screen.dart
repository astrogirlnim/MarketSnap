import 'package:flutter/material.dart';
import 'dart:developer' as developer;
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

  @override
  Widget build(BuildContext context) {
    developer.log(
      '[ConversationListScreen] Building conversation list screen',
      name: 'ConversationListScreen',
    );

    // Get current user directly instead of using stream that might not emit properly
    final currentUser = _authService.currentUser;
    developer.log(
      '[ConversationListScreen] Current user from authService.currentUser: ${currentUser?.uid}',
      name: 'ConversationListScreen',
    );

    if (currentUser == null) {
      developer.log(
        '[ConversationListScreen] No current user - showing login prompt',
        name: 'ConversationListScreen',
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppColors.eggshell,
          foregroundColor: AppColors.soilCharcoal,
          elevation: 0,
        ),
        backgroundColor: AppColors.cornsilk,
        body: const Center(child: Text('Please log in to see messages.')),
      );
    }

    final currentUserId = currentUser.uid;
    developer.log(
      '[ConversationListScreen] Building message list for user: $currentUserId',
      name: 'ConversationListScreen',
    );

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
          developer.log(
            '[ConversationListScreen] Messages stream - connection: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}',
            name: 'ConversationListScreen',
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
            developer.log(
              '[ConversationListScreen] Messages stream waiting - showing loading',
              name: 'ConversationListScreen',
            );
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            developer.log(
              '[ConversationListScreen] Messages stream error: ${snapshot.error}',
              name: 'ConversationListScreen',
            );
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
          developer.log(
            '[ConversationListScreen] Received ${conversations.length} conversations',
            name: 'ConversationListScreen',
          );

          if (conversations.isEmpty) {
            developer.log(
              '[ConversationListScreen] No conversations - showing empty state',
              name: 'ConversationListScreen',
            );
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
                  Text('No conversations yet', style: AppTypography.bodyLG),
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

          developer.log(
            '[ConversationListScreen] Building conversation list with ${conversations.length} items',
            name: 'ConversationListScreen',
          );
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final lastMessage = conversations[index];
              final otherUserId = lastMessage.fromUid == currentUserId
                  ? lastMessage.toUid
                  : lastMessage.fromUid;

              return FutureBuilder<VendorProfile?>(
                future: _profileService.loadAnyUserProfileFromFirestore(otherUserId),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState ==
                      ConnectionState.waiting) {
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
                          .where(
                            (msg) => msg.toUid == currentUserId && !msg.isRead,
                          )
                          .length;

                      return ConversationListItem(
                        otherParticipant: otherUser,
                        lastMessage: lastMessage,
                        currentUserId: currentUserId,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatScreen(otherUser: otherUser),
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
