import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/core/services/profile_update_notifier.dart';

// Local StreamGroup implementation for merging streams
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subscriptions = <StreamSubscription>[];

    for (final stream in streams) {
      subscriptions.add(stream.listen(
        controller.add,
        onError: controller.addError,
      ));
    }

    return controller.stream;
  }
}

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Note: _auth will be used for user-specific feed filtering in future updates
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileUpdateNotifier _profileUpdateNotifier;

  // Cache for profile data to avoid repeated Firestore queries
  final Map<String, Map<String, String>> _profileCache = {};

  FeedService({ProfileUpdateNotifier? profileUpdateNotifier})
      : _profileUpdateNotifier = profileUpdateNotifier ?? ProfileUpdateNotifier() {
    // Listen for profile updates and clear cache when profiles change
    _profileUpdateNotifier.allProfileUpdates.listen((update) {
      final uid = update['uid'] as String;
      if (update['type'] == 'delete') {
        _profileCache.remove(uid);
        developer.log('[FeedService] 🗑️ Cleared profile cache for deleted user: $uid');
      } else {
        _profileCache[uid] = {
          'displayName': update['displayName'] as String,
          'avatarURL': (update['avatarURL'] as String?) ?? '',
        };
        developer.log('[FeedService] 🔄 Updated profile cache for user: $uid');
      }
    });
  }

  /// Get current user's ID for distinguishing own posts
  String? get currentUserId => _auth.currentUser?.uid;

  /// Real-time stream of stories from the current user with live profile updates
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
      '[FeedService] Setting up real-time stories stream with profile updates for user: $userId',
      name: 'FeedService',
    );

    // Create the base stories stream
    final storiesStream = _firestore
        .collection('snaps')
        .where('storyVendorId', isEqualTo: userId)
        .where('isStory', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          developer.log(
            '[FeedService] Received ${snapshot.docs.length} snaps for stories for user $userId',
            name: 'FeedService',
          );

          final snaps = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();

          if (snaps.isEmpty) {
            return <StoryItem>[];
          }

          // Create story item with original data (will be updated with fresh profile data below)
          final storyItem = StoryItem(
            vendorId: userId,
            vendorName: snaps.first.vendorName,
            vendorAvatarUrl: snaps.first.vendorAvatarUrl,
            snaps: snaps,
            hasUnseenSnaps: true,
          );

          return [storyItem];
        });

    // Combine with profile update stream to get real-time updates
    return StreamGroup.merge([
      storiesStream,
      _profileUpdateNotifier.allProfileUpdates.map((_) => <StoryItem>[]), // Trigger refresh on profile updates
    ]).asyncMap((storyItemsList) async {
      // If it's just a profile update trigger (empty list), get current stories
      if (storyItemsList.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection('snaps')
              .where('storyVendorId', isEqualTo: userId)
              .where('isStory', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();
          
          final snaps = snapshot.docs.map((doc) => Snap.fromFirestore(doc)).toList();
          
          if (snaps.isEmpty) {
            return <StoryItem>[];
          }

          storyItemsList = [StoryItem(
            vendorId: userId,
            vendorName: snaps.first.vendorName,
            vendorAvatarUrl: snaps.first.vendorAvatarUrl,
            snaps: snaps,
            hasUnseenSnaps: true,
          )];
        } catch (e) {
          developer.log('[FeedService] Error fetching stories after profile update: $e');
          return <StoryItem>[];
        }
      }

      // Apply current profile data to all story items
      return _applyProfileUpdatesToStories(storyItemsList);
    });
  }

  /// Apply cached profile updates to a list of story items
  List<StoryItem> _applyProfileUpdatesToStories(List<StoryItem> stories) {
    return stories.map((story) {
      final cachedProfile = _profileCache[story.vendorId];
      if (cachedProfile != null) {
        // Update story item with fresh profile data
        final updatedStory = StoryItem(
          vendorId: story.vendorId,
          vendorName: cachedProfile['displayName']!,
          vendorAvatarUrl: cachedProfile['avatarURL']!,
          snaps: story.snaps,
          hasUnseenSnaps: story.hasUnseenSnaps,
        );
        developer.log(
          '[FeedService] 🔄 Updated story profile data for ${story.vendorId}: ${cachedProfile['displayName']}',
        );
        return updatedStory;
      }
      return story; // Return unchanged if no cached profile data
    }).toList();
  }

  /// Real-time stream of feed snaps with live profile updates
  /// Returns snaps ordered by creation time (newest first)
  /// Profile changes are automatically reflected in the stream
  Stream<List<Snap>> getFeedSnapsStream({int limit = 20}) {
    developer.log(
      '[FeedService] Setting up real-time feed snaps stream with limit: $limit',
      name: 'FeedService',
    );

    // Combine the Firestore snaps stream with profile update stream
    final snapsStream = _firestore
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

    // Create a combined stream that updates snaps when profiles change
    return StreamGroup.merge([
      snapsStream,
      _profileUpdateNotifier.allProfileUpdates.map((_) => <Snap>[]), // Trigger refresh on any profile update
    ]).asyncMap((snapsList) async {
      // If it's just a profile update trigger (empty list), get current snaps
      if (snapsList.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection('snaps')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();
          snapsList = snapshot.docs.map((doc) => Snap.fromFirestore(doc)).toList();
        } catch (e) {
          developer.log('[FeedService] Error fetching snaps after profile update: $e');
          return <Snap>[];
        }
      }

      // Apply current profile data to all snaps
      return _applyProfileUpdatesToSnaps(snapsList);
    });
  }

  /// Apply cached profile updates to a list of snaps
  List<Snap> _applyProfileUpdatesToSnaps(List<Snap> snaps) {
    return snaps.map((snap) {
      final cachedProfile = _profileCache[snap.vendorId];
      if (cachedProfile != null) {
        // Update snap with fresh profile data
        final updatedSnap = snap.updateProfileData(
          vendorName: cachedProfile['displayName']!,
          vendorAvatarUrl: cachedProfile['avatarURL']!,
        );
        developer.log(
          '[FeedService] 🔄 Updated snap profile data for ${snap.vendorId}: ${cachedProfile['displayName']}',
        );
        return updatedSnap;
      }
      return snap; // Return unchanged if no cached profile data
    }).toList();
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
