import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/core/services/messaging_service.dart';

/// Integration test for ephemeral messaging system
/// This test verifies the complete messaging flow from creation to expiration
void main() {
  group('Ephemeral Messaging Integration Test', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MessagingService messagingService;

    setUpAll(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(
        isAnonymous: false,
        uid: 'integration_vendor',
        email: 'integration@test.com',
        displayName: 'Integration Test Vendor',
      ));
      messagingService = MessagingService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );
    });

    setUp(() async {
      // Clear messages before each test
      final snapshot = await fakeFirestore.collection('messages').get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    });

    test('complete ephemeral messaging lifecycle', () async {
      print('🧪 Testing complete ephemeral messaging lifecycle...');

      // Step 1: Send a message
      const fromUid = 'integration_vendor';
      const toUid = 'test_customer';
      const messageText = 'Fresh organic tomatoes available now! 🍅';

      print('📤 Step 1: Sending message...');
      final messageId = await messagingService.sendMessage(
        fromUid: fromUid,
        toUid: toUid,
        text: messageText,
      );

      expect(messageId, isNotEmpty);
      print('✅ Message sent with ID: $messageId');

      // Step 2: Verify message was created with proper TTL
      print('🔍 Step 2: Verifying message creation...');
      final doc = await fakeFirestore.collection('messages').doc(messageId).get();
      expect(doc.exists, isTrue);

      final message = Message.fromFirestore(doc);
      expect(message.text, equals(messageText));
      expect(message.fromUid, equals(fromUid));
      expect(message.toUid, equals(toUid));
      expect(message.hasExpired, isFalse);

      // Verify TTL is set to 24 hours
      final expectedExpiry = message.createdAt.add(const Duration(hours: 24));
      expect(message.expiresAt, equals(expectedExpiry));
             print('✅ Message created with proper 24-hour TTL');
       
       // Debug: Check conversation ID and participants
       print('🔍 DEBUG: Conversation ID: ${message.conversationId}');
       print('🔍 DEBUG: Participants: ${message.participants}');

       // Step 3: Test conversation retrieval
       print('💬 Step 3: Testing conversation retrieval...');
       final conversationStream = messagingService.getConversationMessages(
         userId1: fromUid,
         userId2: toUid,
       );

       await expectLater(
         conversationStream,
         emits(predicate<List<Message>>((messages) {
           print('🔍 DEBUG: Received ${messages.length} messages in conversation');
           if (messages.isNotEmpty) {
             print('🔍 DEBUG: First message: ${messages.first.text}');
           }
           expect(messages.length, equals(1));
           expect(messages.first.text, equals(messageText));
           return true;
         })),
       );
       print('✅ Conversation retrieval working correctly');

      // Step 4: Test user conversations
      print('👤 Step 4: Testing user conversations...');
      final userConversationsStream = messagingService.getUserConversations(
        userId: fromUid,
      );

      await expectLater(
        userConversationsStream,
        emits(predicate<List<Message>>((conversations) {
          expect(conversations.length, equals(1));
          expect(conversations.first.text, equals(messageText));
          return true;
        })),
      );
      print('✅ User conversations working correctly');

      // Step 5: Test unread count
      print('📧 Step 5: Testing unread count...');
      final unreadCountStream = messagingService.getUnreadMessageCount(
        userId: toUid,
      );

      await expectLater(
        unreadCountStream,
        emits(equals(1)),
      );
      print('✅ Unread count working correctly');

      // Step 6: Mark as read
      print('✅ Step 6: Testing mark as read...');
      await messagingService.markMessageAsRead(
        messageId: messageId,
        userId: toUid,
      );

      // Verify unread count is now 0
      await expectLater(
        unreadCountStream,
        emits(equals(0)),
      );
      print('✅ Mark as read working correctly');

      // Step 7: Test message retrieval
      print('🔍 Step 7: Testing message retrieval...');
      final retrievedMessage = await messagingService.getMessage(
        messageId: messageId,
      );
      expect(retrievedMessage, isNotNull);
      expect(retrievedMessage!.text, equals(messageText));
      print('✅ Message retrieval working correctly');

      print('🎉 Complete ephemeral messaging lifecycle test PASSED!');
    });

    test('message expiration and cleanup simulation', () async {
      print('⏰ Testing message expiration and cleanup...');

      // Create expired messages
      const fromUid = 'integration_vendor';
      const toUid = 'test_customer';
      final pastTime = DateTime.now().subtract(const Duration(hours: 25));

      // Add expired messages directly to Firestore
      final expiredMessages = [
        {
          'fromUid': fromUid,
          'toUid': toUid,
          'text': 'This message should be expired',
          'conversationId': 'test_customer_integration_vendor',
          'participants': [toUid, fromUid]..sort(),
          'createdAt': Timestamp.fromDate(pastTime),
          'expiresAt': Timestamp.fromDate(pastTime.add(const Duration(hours: 24))),
          'isRead': false,
        },
        {
          'fromUid': toUid,
          'toUid': fromUid,
          'text': 'This is also expired',
          'conversationId': 'test_customer_integration_vendor',
          'participants': [toUid, fromUid]..sort(),
          'createdAt': Timestamp.fromDate(pastTime.add(const Duration(minutes: 30))),
          'expiresAt': Timestamp.fromDate(pastTime.add(const Duration(hours: 24, minutes: 30))),
          'isRead': false,
        },
      ];

      for (final messageData in expiredMessages) {
        await fakeFirestore.collection('messages').add(messageData);
      }

      // Verify messages were added
      final beforeCleanup = await fakeFirestore.collection('messages').get();
      expect(beforeCleanup.docs.length, equals(2));
      print('📝 Added 2 expired messages to test cleanup');

      // Test that expired messages are filtered from conversation streams
      final conversationStream = messagingService.getConversationMessages(
        userId1: fromUid,
        userId2: toUid,
      );

      await expectLater(
        conversationStream,
        emits(predicate<List<Message>>((messages) {
          expect(messages.length, equals(0)); // Should be empty due to expiration
          return true;
        })),
      );
      print('✅ Expired messages correctly filtered from conversation streams');

      // Test that expired messages are filtered from user conversations
      final userConversationsStream = messagingService.getUserConversations(
        userId: fromUid,
      );

      await expectLater(
        userConversationsStream,
        emits(predicate<List<Message>>((conversations) {
          expect(conversations.length, equals(0)); // Should be empty due to expiration
          return true;
        })),
      );
      print('✅ Expired messages correctly filtered from user conversations');

      // Test manual cleanup
      await messagingService.cleanupExpiredMessages();

      // Verify physical deletion
      final afterCleanup = await fakeFirestore.collection('messages').get();
      expect(afterCleanup.docs.length, equals(0));
      print('✅ Manual cleanup successfully removed all expired messages');

      print('🎉 Message expiration and cleanup test PASSED!');
    });

    test('mixed active and expired messages handling', () async {
      print('🔄 Testing mixed active and expired messages...');

      const fromUid = 'integration_vendor';
      const toUid = 'test_customer';
      const activeMessageText = 'This message is still active';
      const expiredMessageText = 'This message has expired';

      // Add active message
      final activeMessageId = await messagingService.sendMessage(
        fromUid: fromUid,
        toUid: toUid,
        text: activeMessageText,
      );

      // Add expired message
      final pastTime = DateTime.now().subtract(const Duration(hours: 25));
      await fakeFirestore.collection('messages').add({
        'fromUid': fromUid,
        'toUid': toUid,
        'text': expiredMessageText,
        'conversationId': 'test_customer_integration_vendor',
        'participants': [toUid, fromUid]..sort(),
        'createdAt': Timestamp.fromDate(pastTime),
        'expiresAt': Timestamp.fromDate(pastTime.add(const Duration(hours: 24))),
        'isRead': false,
      });

      print('📝 Added 1 active and 1 expired message');

      // Verify initial state
      final beforeCleanup = await fakeFirestore.collection('messages').get();
      expect(beforeCleanup.docs.length, equals(2));

      // Test conversation stream only shows active messages
      final conversationStream = messagingService.getConversationMessages(
        userId1: fromUid,
        userId2: toUid,
      );

      await expectLater(
        conversationStream,
        emits(predicate<List<Message>>((messages) {
          expect(messages.length, equals(1));
          expect(messages.first.text, equals(activeMessageText));
          return true;
        })),
      );
      print('✅ Only active messages shown in conversation stream');

      // Test cleanup preserves active messages
      await messagingService.cleanupExpiredMessages();

      final afterCleanup = await fakeFirestore.collection('messages').get();
      expect(afterCleanup.docs.length, equals(1));

      final remainingMessage = Message.fromFirestore(afterCleanup.docs.first);
      expect(remainingMessage.text, equals(activeMessageText));
      expect(remainingMessage.messageId, equals(activeMessageId));
      print('✅ Cleanup preserved active message and removed expired message');

      print('🎉 Mixed messages handling test PASSED!');
    });

    test('system performance and edge cases', () async {
      print('⚡ Testing system performance and edge cases...');

      const fromUid = 'integration_vendor';
      const toUid = 'test_customer';

      // Test 1: Empty message text handling
      try {
        await messagingService.sendMessage(
          fromUid: fromUid,
          toUid: toUid,
          text: '',
        );
        fail('Should have thrown an exception for empty message');
      } catch (e) {
        expect(e.toString(), contains('Message text cannot be empty'));
        print('✅ Empty message text properly rejected');
      }

      // Test 2: Very long message handling
      final longMessage = 'a' * 600; // Over 500 character limit
      try {
        await messagingService.sendMessage(
          fromUid: fromUid,
          toUid: toUid,
          text: longMessage,
        );
        fail('Should have thrown an exception for long message');
      } catch (e) {
        expect(e.toString(), contains('Message text too long'));
        print('✅ Long message text properly rejected');
      }

      // Test 3: Self-messaging prevention
      try {
        await messagingService.sendMessage(
          fromUid: fromUid,
          toUid: fromUid,
          text: 'Sending to myself',
        );
        fail('Should have thrown an exception for self-messaging');
      } catch (e) {
        expect(e.toString(), contains('Cannot send message to yourself'));
        print('✅ Self-messaging properly prevented');
      }

      // Test 4: Getting non-existent message
      final nonExistentMessage = await messagingService.getMessage(
        messageId: 'non_existent_id',
      );
      expect(nonExistentMessage, isNull);
      print('✅ Non-existent message handling works correctly');

      // Test 5: Multiple rapid message sending
      final messageIds = <String>[];
      for (int i = 0; i < 5; i++) {
        final messageId = await messagingService.sendMessage(
          fromUid: fromUid,
          toUid: toUid,
          text: 'Rapid message $i',
        );
        messageIds.add(messageId);
      }

      expect(messageIds.length, equals(5));
      expect(messageIds.toSet().length, equals(5)); // All unique IDs
      print('✅ Multiple rapid messages handled correctly');

      // Test 6: Cleanup with no expired messages
      await messagingService.cleanupExpiredMessages();
      final finalCount = await fakeFirestore.collection('messages').get();
      expect(finalCount.docs.length, equals(5)); // All messages still present
      print('✅ Cleanup with no expired messages handled gracefully');

      print('🎉 Performance and edge cases test PASSED!');
    });
  });
} 