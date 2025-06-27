import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

/// Service for handling ephemeral messaging between vendors and shoppers.
/// Manages 24-hour auto-expiring messages with proper security.
class MessagingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  MessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;



  /// Sends a new message between users
  /// Returns the message ID if successful
  Future<String> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
  }) async {
    debugPrint(
      '[MessagingService] Sending message from $fromUid to $toUid: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
    );

    // Quick authentication check to avoid token validation overhead
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid != fromUid) {
      throw Exception('Authentication mismatch. Please sign in again.');
    }

    try {
      // Validate input
      if (text.trim().isEmpty) {
        throw Exception('Message text cannot be empty');
      }

      if (text.length > 500) {
        throw Exception('Message text too long (max 500 characters)');
      }

      if (fromUid == toUid) {
        throw Exception('Cannot send message to yourself');
      }

      // Create message
      final message = Message.create(
        fromUid: fromUid,
        toUid: toUid,
        text: text.trim(),
      );

      debugPrint(
        '[MessagingService] Created message with conversation ID: ${message.conversationId}',
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection('messages')
          .add(message.toFirestore());

      debugPrint(
        '[MessagingService] Message sent successfully with ID: ${docRef.id}',
      );

      return docRef.id;
    } catch (e) {
      debugPrint('[MessagingService] Error sending message: $e');
      rethrow;
    }
  }

  /// Gets messages for a conversation between two users
  /// Returns a stream of messages ordered by creation time (newest first)
  Stream<List<Message>> getConversationMessages({
    required String userId1,
    required String userId2,
    int limit = 50,
  }) {
    debugPrint(
      '[MessagingService] Getting conversation messages between $userId1 and $userId2 using participants field',
    );

    // Create a sorted list of participants to match the stored array
    final participants = [userId1, userId2]..sort();

    debugPrint('[MessagingService] Using participants for query: $participants');

    return _firestore
        .collection('messages')
        .where('participants', isEqualTo: participants)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      debugPrint(
        '[MessagingService] Received ${snapshot.docs.length} messages for participants $participants',
      );

      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .where(
            (message) => !message.hasExpired,
          ) // Filter out expired messages
          .toList();
    });
  }

  /// Gets all conversations for a user
  /// Returns a stream of the latest message from each conversation
  Stream<List<Message>> getUserConversations({
    required String userId,
    int limit = 20,
  }) {
    debugPrint('[MessagingService] Getting conversations for user: $userId using participants field');

    // Perform quick auth check without token validation to avoid hanging
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      debugPrint('[MessagingService] ❌ User authentication mismatch');
      return Stream.value(<Message>[]);
    }

    try {
      // Query for messages where the user is a participant
      final query = _firestore
          .collection('messages')
          .where('participants', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit * 5); // Get more to account for filtering and grouping

      debugPrint('[MessagingService] Created Firestore query for getUserConversations');

      return query
          .snapshots(includeMetadataChanges: false)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: (sink) {
              debugPrint('[MessagingService] Query timed out for user $userId - likely missing index');
              sink.addError('Query timed out - this usually indicates missing Firestore indexes for the messages collection');
            },
          )
          .handleError((error, stackTrace) {
            debugPrint('[MessagingService] Stream error for getUserConversations: $error');
            debugPrint('[MessagingService] Stack trace: $stackTrace');
            // Re-throw to be handled by UI
            throw error;
          })
          .map((snapshot) {
            debugPrint(
              '[MessagingService] Received ${snapshot.docs.length} messages for user $userId (metadata from cache: ${snapshot.metadata.isFromCache})',
            );

            if (snapshot.docs.isEmpty) {
              debugPrint('[MessagingService] No messages found for user $userId - returning empty list');
              return <Message>[];
            }

            try {
              // Convert to messages and filter expired ones
              final allMessages = snapshot.docs
                  .map((doc) {
                    try {
                      return Message.fromFirestore(doc);
                    } catch (e) {
                      debugPrint('[MessagingService] Error parsing message ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((message) => message != null)
                  .cast<Message>()
                  .where((message) => !message.hasExpired)
                  .toList();

              debugPrint('[MessagingService] Parsed ${allMessages.length} valid, non-expired messages');

              // Group by conversation and get the latest message from each
              final conversationMap = <String, Message>{};
              for (final message in allMessages) {
                final existing = conversationMap[message.conversationId];
                if (existing == null ||
                    message.createdAt.isAfter(existing.createdAt)) {
                  conversationMap[message.conversationId] = message;
                }
              }

              // Convert to list and sort by creation time
              final conversations = conversationMap.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              debugPrint(
                '[MessagingService] Found ${conversations.length} conversations for user $userId',
              );

              final result = conversations.take(limit).toList();
              debugPrint('[MessagingService] Returning ${result.length} conversations after limit');
              
              return result;
            } catch (e) {
              debugPrint('[MessagingService] Error processing conversation data: $e');
              // Return empty list rather than crashing
              return <Message>[];
            }
          })
          .handleError((error) {
            debugPrint('[MessagingService] Final error handler in getUserConversations: $error');
            // Emit empty list on error to prevent infinite loading
            return Stream.value(<Message>[]);
          });
    } catch (e) {
      debugPrint('[MessagingService] Error creating getUserConversations stream: $e');
      // Return a stream that immediately emits an empty list
      return Stream.value(<Message>[]);
    }
  }

  /// Marks a message as read
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    debugPrint(
      '[MessagingService] Marking message $messageId as read by user $userId',
    );

    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isRead': true,
      });

      debugPrint(
        '[MessagingService] Message $messageId marked as read successfully',
      );
    } catch (e) {
      debugPrint('[MessagingService] Error marking message as read: $e');
      rethrow;
    }
  }

  /// Marks all messages in a conversation as read by the user
  Future<void> markConversationAsRead({
    required String userId1,
    required String userId2,
    required String currentUserId,
  }) async {
    debugPrint(
      '[MessagingService] Marking conversation between $userId1 and $userId2 as read by $currentUserId',
    );

    try {
      // Create a sorted list of participants to match the stored array
      final participants = [userId1, userId2]..sort();

      // Get unread messages where current user is the recipient
      final unreadMessages = await _firestore
          .collection('messages')
          .where('participants', isEqualTo: participants)
          .where('toUid', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Mark all as read in a batch
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      debugPrint(
        '[MessagingService] Marked ${unreadMessages.docs.length} messages as read in conversation between $userId1 and $userId2',
      );
    } catch (e) {
      debugPrint('[MessagingService] Error marking conversation as read: $e');
      rethrow;
    }
  }

  /// Gets the count of unread messages for a user
  Stream<int> getUnreadMessageCount({required String userId}) {
    debugPrint(
      '[MessagingService] Getting unread message count for user: $userId using participants field',
    );

    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .where('toUid', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final unreadCount = snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .where((message) => !message.hasExpired)
              .length;

          debugPrint(
            '[MessagingService] User $userId has $unreadCount unread messages',
          );

          return unreadCount;
        });
  }

  /// Deletes expired messages (for cleanup - normally handled by Firestore TTL)
  Future<void> cleanupExpiredMessages() async {
    debugPrint('[MessagingService] Starting cleanup of expired messages');

    try {
      final now = Timestamp.now();
      final expiredMessages = await _firestore
          .collection('messages')
          .where('expiresAt', isLessThan: now)
          .get();

      if (expiredMessages.docs.isEmpty) {
        debugPrint('[MessagingService] No expired messages to clean up');
        return;
      }

      // Delete in batches
      final batch = _firestore.batch();
      for (final doc in expiredMessages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint(
        '[MessagingService] Cleaned up ${expiredMessages.docs.length} expired messages',
      );
    } catch (e) {
      debugPrint('[MessagingService] Error during cleanup: $e');
      rethrow;
    }
  }

  /// Gets a specific message by ID
  Future<Message?> getMessage({required String messageId}) async {
    debugPrint('[MessagingService] Getting message with ID: $messageId');

    try {
      final doc = await _firestore.collection('messages').doc(messageId).get();

      if (!doc.exists) {
        debugPrint('[MessagingService] Message $messageId not found');
        return null;
      }

      final message = Message.fromFirestore(doc);

      if (message.hasExpired) {
        debugPrint('[MessagingService] Message $messageId has expired');
        return null;
      }

      debugPrint(
        '[MessagingService] Retrieved message $messageId successfully',
      );
      return message;
    } catch (e) {
      debugPrint('[MessagingService] Error getting message: $e');
      rethrow;
    }
  }
}
