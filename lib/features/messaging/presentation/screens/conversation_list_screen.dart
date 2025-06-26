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
    final currentUserId = _authService.getCurrentUser()?.uid;
    
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
          child: Text('Please sign in to view messages'),
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
      body: StreamBuilder<List<String>>(
        stream: _messagingService.getConversations(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.appleRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading conversations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.appleRed,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: AppColors.soilTaupe),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.soilTaupe,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.soilTaupe,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with other vendors',
                          style: TextStyle(color: AppColors.soilTaupe),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VendorDiscoveryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Discover Vendors'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.marketBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final conversationIds = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversationIds.length,
                  itemBuilder: (context, index) {
                    final otherUserId = conversationIds[index];
                    
                    return FutureBuilder<VendorProfile?>(
                      future: _profileService.loadProfileFromFirestore(otherUserId),
                      builder: (context, profileSnapshot) {
                        if (profileSnapshot.connectionState == ConnectionState.waiting) {
                          return const Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.soilTaupe,
                              ),
                              title: Text('Loading...'),
                              subtitle: Text('Fetching conversation details'),
                            ),
                          );
                        }

                        final otherUser = profileSnapshot.data;
                        if (otherUser == null) {
                          return const SizedBox.shrink();
                        }

                                                 return StreamBuilder<Message?>(
                           stream: _messagingService.getLastMessage(currentUserId, otherUserId),
                          builder: (context, messageSnapshot) {
                            final lastMessage = messageSnapshot.data;
                            final unreadCount = 0; // TODO: Implement unread count

                            if (lastMessage == null) {
                              return const SizedBox.shrink();
                            }

                            return ConversationListItem(
                              otherParticipant: otherUser,
                              lastMessage: lastMessage,
                              unreadCount: unreadCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(otherUser: otherUser),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VendorDiscoveryScreen(),
            ),
          );
        },
        backgroundColor: AppColors.marketBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
