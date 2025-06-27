import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Note: _auth will be used for user-specific feed filtering in future updates
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's ID for distinguishing own posts
  String? get currentUserId => _auth.currentUser?.uid;

  /// Real-time stream of stories from the current user
  Stream<List<StoryItem>> getStoriesStream() {
    final userId = currentUserId;
    if (userId == null) {
      developer.log(
        '[FeedService] No user logged in, returning empty stories stream',
        name: 'FeedService',
      );
      return Stream.value([]);
    }

    developer.log(
      '[FeedService] Setting up real-time stories stream for user: $userId',
      name: 'FeedService',
    );

    return _firestore
        .collection('snaps')
        // ✅ FIX: Query for the current user's stories specifically
        .where('storyVendorId', isEqualTo: userId)
        .where('isStory', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20) // A user's own stories are limited
        .snapshots()
        .map((snapshot) {
          developer.log(
            '[FeedService] Received ${snapshot.docs.length} snaps for stories for user $userId',
            name: 'FeedService',
          );

          final snaps = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();

          // Since we are only getting one user's stories, we can simplify the grouping
          if (snaps.isEmpty) {
            return [];
          }

          final storyItem = StoryItem(
            vendorId: userId,
            vendorName: snaps.first.vendorName,
            vendorAvatarUrl: snaps.first.vendorAvatarUrl,
            snaps: snaps,
            hasUnseenSnaps: true, // Placeholder logic
          );

          developer.log(
            '[FeedService] Created 1 story item for user $userId with ${snaps.length} snaps',
            name: 'FeedService',
          );

          // Return a list containing the single story item for the current user
          return [storyItem];
        });
  }

  /// Real-time stream of feed snaps
  /// Returns snaps ordered by creation time (newest first)
  Stream<List<Snap>> getFeedSnapsStream({int limit = 20}) {
    developer.log(
      '[FeedService] Setting up real-time feed snaps stream with limit: $limit',
      name: 'FeedService',
    );

    return _firestore
        .collection('snaps')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          developer.log(
            '[FeedService] Received ${snapshot.docs.length} snaps for feed',
            name: 'FeedService',
          );
          final snaps = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();

          // Log current user's snaps for debugging
          final currentUser = currentUserId;
          if (currentUser != null) {
            final userSnaps = snaps
                .where((snap) => snap.vendorId == currentUser)
                .length;
            developer.log(
              '[FeedService] Found $userSnaps snaps from current user ($currentUser)',
              name: 'FeedService',
            );
          }

          return snaps;
        });
  }

  /// Check if a snap belongs to the current user
  bool isCurrentUserSnap(Snap snap) {
    final currentUser = currentUserId;
    final isUserSnap = currentUser != null && snap.vendorId == currentUser;
    if (isUserSnap) {
      developer.log(
        '[FeedService] Snap "${snap.caption}" belongs to current user',
        name: 'FeedService',
      );
    }
    return isUserSnap;
  }

  /// Legacy methods for backward compatibility (now use streams internally)
  Future<List<StoryItem>> getStories() async {
    developer.log(
      '[FeedService] Using legacy getStories - converting stream to future',
      name: 'FeedService',
    );
    return getStoriesStream().first;
  }

  Future<List<Snap>> getFeedSnaps({
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    developer.log(
      '[FeedService] Using legacy getFeedSnaps - converting stream to future',
      name: 'FeedService',
    );
    return getFeedSnapsStream(limit: limit).first;
  }
}
