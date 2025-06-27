import 'package:firebase_auth/firebase_auth.dart';
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
import 'dart:async';

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
  
  // Add timeout and error tracking
  Timer? _timeoutTimer;
  bool _hasTimedOut = false;
  String? _debugInfo;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    debugPrint('[ConversationListScreen] Starting 10-second timeout for stream');
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _hasTimedOut = true;
          _debugInfo = 'Stream timed out after 10 seconds';
        });
        debugPrint('[ConversationListScreen] Stream timed out - likely Firestore query issue');
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _hasTimedOut = false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        debugPrint('[ConversationListScreen] Auth state: ${authSnapshot.connectionState}, hasData: ${authSnapshot.hasData}');
        
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentUser = authSnapshot.data;

        if (currentUser == null) {
          debugPrint('[ConversationListScreen] No authenticated user');
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
        
        final currentUserId = currentUser.uid;
        debugPrint('[ConversationListScreen] Building for user: $currentUserId');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
            backgroundColor: AppColors.eggshell,
            foregroundColor: AppColors.soilCharcoal,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  debugPrint('[ConversationListScreen] Manual refresh triggered');
                  setState(() {
                    _hasTimedOut = false;
                    _debugInfo = null;
                  });
                },
              ),
            ],
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
          body: _hasTimedOut 
            ? _buildTimeoutView() 
            : _buildConversationStream(currentUserId),
        );
      },
    );
  }

  Widget _buildTimeoutView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_outlined, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Loading timed out',
            style: AppTypography.bodyLG,
          ),
          const SizedBox(height: 8),
          Text(
            _debugInfo ?? 'The messages failed to load. This might be due to a network issue or database configuration.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              debugPrint('[ConversationListScreen] Retry button pressed');
              setState(() {
                _hasTimedOut = false;
                _debugInfo = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationStream(String currentUserId) {
    return StreamBuilder<List<Message>>(
      stream: _messagingService.getUserConversations(userId: currentUserId),
      builder: (context, snapshot) {
        debugPrint('[ConversationListScreen] Stream state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        if (snapshot.hasError) {
          _cancelTimeout();
          debugPrint('[ConversationListScreen] Stream error: ${snapshot.error}');
          return _buildErrorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Start timeout only on first waiting state
          if (!_hasTimedOut && _timeoutTimer == null) {
            _startTimeout();
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading conversations...',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 8),
                Text(
                  'User: ${currentUserId.substring(0, 8)}...',
                  style: AppTypography.caption.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Cancel timeout once we get data
        _cancelTimeout();

        final conversations = snapshot.data ?? [];
        debugPrint('[ConversationListScreen] Received ${conversations.length} conversations');

        if (conversations.isEmpty) {
          return _buildEmptyView();
        }

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final lastMessage = conversations[index];
            final otherUserId = lastMessage.fromUid == currentUserId
                ? lastMessage.toUid
                : lastMessage.fromUid;

            debugPrint('[ConversationListScreen] Building conversation item ${index + 1}/${conversations.length} with other user: $otherUserId');

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

                if (profileSnapshot.hasError) {
                  debugPrint('[ConversationListScreen] Profile load error for $otherUserId: ${profileSnapshot.error}');
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.error, color: Colors.white),
                    ),
                    title: Text('User $otherUserId'),
                    subtitle: const Text('Profile load failed'),
                    onTap: () {
                      // Still allow navigation even if profile fails to load
                      _navigateToChat(otherUserId, currentUserId);
                    },
                  );
                }

                final otherUser = profileSnapshot.data;
                if (otherUser == null) {
                  debugPrint('[ConversationListScreen] No profile found for user: $otherUserId');
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('User ${otherUserId.substring(0, 8)}...'),
                    subtitle: const Text('Profile not found'),
                    onTap: () {
                      _navigateToChat(otherUserId, currentUserId);
                    },
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
                        .where((msg) =>
                            msg.toUid == currentUserId && !msg.isRead)
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
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading conversations',
            style: AppTypography.bodyLG,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              debugPrint('[ConversationListScreen] Error retry button pressed');
              setState(() {
                _hasTimedOut = false;
                _debugInfo = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const VendorDiscoveryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Find Vendors'),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(String otherUserId, String currentUserId) {
    // Create a minimal vendor profile for navigation
    final fallbackProfile = VendorProfile(
      uid: otherUserId,
      displayName: 'User ${otherUserId.substring(0, 8)}...',
      vendorName: 'Unknown Vendor',
      email: '',
      phoneNumber: '',
      profilePicture: null,
      location: '',
      operatingHours: {},
      categories: [],
      description: '',
      isActive: true,
      followers: [],
      accountLinkedEmail: null,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(otherUser: fallbackProfile),
      ),
    );
  }
}
