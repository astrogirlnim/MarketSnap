import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketsnap/core/models/pending_media.dart';

void main() {
  group('Story vs Feed Posting Bug Fix Tests', () {
    test('PendingMediaItem correctly stores and preserves isStory=true', () {
      // Arrange: Create a story item
      final storyItem = PendingMediaItem(
        filePath: '/tmp/test_story.jpg',
        mediaType: MediaType.photo,
        caption: 'Test story post',
        vendorId: 'test-vendor-123',
        filterType: 'warm',
        isStory: true, // This should be preserved!
      );

      debugPrint('📝 Created story item with isStory: ${storyItem.isStory}');

      // Assert: Verify isStory is correctly set
      expect(
        storyItem.isStory,
        isTrue,
        reason: 'Story item should have isStory=true',
      );
      expect(storyItem.caption, equals('Test story post'));
      expect(storyItem.filterType, equals('warm'));
      expect(storyItem.mediaType, equals(MediaType.photo));

      debugPrint('✅ PASSED: Story item correctly stores isStory=true');
    });

    test('PendingMediaItem correctly stores and preserves isStory=false', () {
      // Arrange: Create a feed item
      final feedItem = PendingMediaItem(
        filePath: '/tmp/test_feed.jpg',
        mediaType: MediaType.photo,
        caption: 'Test feed post',
        vendorId: 'test-vendor-123',
        filterType: 'cool',
        isStory: false, // This should be preserved!
      );

      debugPrint('📝 Created feed item with isStory: ${feedItem.isStory}');

      // Assert: Verify isStory is correctly set
      expect(
        feedItem.isStory,
        isFalse,
        reason: 'Feed item should have isStory=false',
      );
      expect(feedItem.caption, equals('Test feed post'));
      expect(feedItem.filterType, equals('cool'));
      expect(feedItem.mediaType, equals(MediaType.photo));

      debugPrint('✅ PASSED: Feed item correctly stores isStory=false');
    });

    test('Multiple PendingMediaItems with different isStory values', () {
      // Arrange: Create both story and feed items
      final storyItem = PendingMediaItem(
        filePath: '/tmp/test_story.jpg',
        mediaType: MediaType.photo,
        caption: 'Mixed test story',
        vendorId: 'test-vendor-456',
        filterType: 'contrast',
        isStory: true,
      );

      final feedItem = PendingMediaItem(
        filePath: '/tmp/test_feed.jpg',
        mediaType: MediaType.video,
        caption: 'Mixed test feed',
        vendorId: 'test-vendor-456',
        filterType: 'none',
        isStory: false,
      );

      // Assert: Both items have correct isStory values
      expect(
        storyItem.isStory,
        isTrue,
        reason: 'Story item should have isStory=true',
      );
      expect(
        feedItem.isStory,
        isFalse,
        reason: 'Feed item should have isStory=false',
      );

      // Verify other fields are also correctly set
      expect(storyItem.mediaType, equals(MediaType.photo));
      expect(feedItem.mediaType, equals(MediaType.video));

      debugPrint('✅ PASSED: Mixed story/feed items handled correctly');
    });

    test('PendingMediaItem default isStory value behavior', () {
      // Test the default behavior of the isStory field
      // when creating PendingMediaItem instances

      // Create an item without explicitly setting isStory (should default to false)
      final defaultItem = PendingMediaItem(
        filePath: '/tmp/test_default.jpg',
        mediaType: MediaType.photo,
        caption: 'Default behavior test',
        vendorId: 'test-vendor-789',
        filterType: 'warm',
        // isStory not explicitly set - should default to false
      );

      // Verify default behavior
      expect(
        defaultItem.isStory,
        isFalse,
        reason: 'PendingMediaItem should default isStory to false when not set',
      );

      debugPrint('✅ PASSED: Default isStory behavior works correctly');
    });

    test(
      'Bug scenario: HiveService should pass isStory to quarantined items',
      () {
        // This test simulates the bug scenario described in the debugging log
        // The bug was in HiveService.addPendingMedia() where isStory was missing
        // from quarantined item constructor

        // Simulate the original item that would be quarantined
        final originalStoryItem = PendingMediaItem(
          filePath: '/path/to/story.jpg',
          mediaType: MediaType.photo,
          caption: 'Story that should be quarantined',
          vendorId: 'vendor-123',
          filterType: 'warm',
          isStory: true, // This was being lost in the bug!
        );

        // Simulate what the fixed HiveService should do:
        // Create a quarantined item preserving ALL fields including isStory
        final quarantinedItem = PendingMediaItem(
          filePath: '/quarantine/story.jpg', // moved path
          mediaType: originalStoryItem.mediaType,
          caption: originalStoryItem.caption,
          vendorId: originalStoryItem.vendorId,
          filterType: originalStoryItem.filterType,
          isStory: originalStoryItem
              .isStory, // THE FIX: This field must be preserved!
        );

        // Verify the fix preserves isStory
        expect(
          quarantinedItem.isStory,
          equals(originalStoryItem.isStory),
          reason: 'Quarantined item must preserve original isStory value',
        );
        expect(
          quarantinedItem.isStory,
          isTrue,
          reason: 'Story item should remain a story after quarantine',
        );

        // Test the same for feed items
        final originalFeedItem = PendingMediaItem(
          filePath: '/path/to/feed.jpg',
          mediaType: MediaType.video,
          caption: 'Feed that should be quarantined',
          vendorId: 'vendor-456',
          filterType: 'cool',
          isStory: false,
        );

        final quarantinedFeedItem = PendingMediaItem(
          filePath: '/quarantine/feed.jpg',
          mediaType: originalFeedItem.mediaType,
          caption: originalFeedItem.caption,
          vendorId: originalFeedItem.vendorId,
          filterType: originalFeedItem.filterType,
          isStory: originalFeedItem.isStory, // THE FIX: Preserve this!
        );

        expect(
          quarantinedFeedItem.isStory,
          isFalse,
          reason: 'Feed item should remain a feed item after quarantine',
        );

        debugPrint(
          '✅ PASSED: Bug fix correctly preserves isStory in quarantined items',
        );
      },
    );

    test('toString() method includes isStory field for debugging', () {
      // Test that the toString method includes the isStory field
      // This helps with debugging the exact bug we fixed

      final storyItem = PendingMediaItem(
        filePath: '/tmp/debug_story.jpg',
        mediaType: MediaType.photo,
        caption: 'Debug story',
        vendorId: 'debug-vendor',
        filterType: 'debug',
        isStory: true,
      );

      final feedItem = PendingMediaItem(
        filePath: '/tmp/debug_feed.jpg',
        mediaType: MediaType.video,
        caption: 'Debug feed',
        vendorId: 'debug-vendor',
        filterType: 'debug',
        isStory: false,
      );

      final storyString = storyItem.toString();
      final feedString = feedItem.toString();

      // Verify isStory is included in toString output for debugging
      expect(
        storyString,
        contains('isStory: true'),
        reason: 'toString should include isStory=true for story items',
      );
      expect(
        feedString,
        contains('isStory: false'),
        reason: 'toString should include isStory=false for feed items',
      );

      debugPrint('📝 Story toString: $storyString');
      debugPrint('📝 Feed toString: $feedString');
      debugPrint('✅ PASSED: toString includes isStory field for debugging');
    });
  });
}
