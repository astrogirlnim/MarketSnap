import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/core/services/profile_update_notifier.dart';

// Local StreamGroup implementation for merging streams
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subscriptions = <StreamSubscription>[];

    for (final stream in streams) {
      subscriptions.add(
        stream.listen(controller.add, onError: controller.addError),
      );
    }

    return controller.stream;
  }
}

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Note: _auth will be used for user-specific feed filtering in future updates
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileUpdateNotifier _profileUpdateNotifier;

  // Cache for profile data to avoid repeated Firestore queries
  final Map<String, Map<String, String>> _profileCache = {};

  FeedService({ProfileUpdateNotifier? profileUpdateNotifier})
    : _profileUpdateNotifier =
          profileUpdateNotifier ?? ProfileUpdateNotifier() {
    // Listen for profile updates and clear cache when profiles change
    _profileUpdateNotifier.allProfileUpdates.listen((update) {
      final uid = update['uid'] as String;
      if (update['type'] == 'delete') {
        _profileCache.remove(uid);
        developer.log(
          '[FeedService] 🗑️ Cleared profile cache for deleted user: $uid',
        );
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

  /// Real-time stream of stories from followed vendors with live profile updates
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

    // First get the list of vendors this user follows
    return _getFollowedVendorsStream(userId).asyncExpand((followedVendorIds) {
      developer.log(
        '[FeedService] User is following ${followedVendorIds.length} vendors: $followedVendorIds',
        name: 'FeedService',
      );

      if (followedVendorIds.isEmpty) {
        developer.log(
          '[FeedService] No followed vendors, returning empty stories',
          name: 'FeedService',
        );
        return Stream.value(<StoryItem>[]);
      }

      // Query stories from all followed vendors and return the live stream
      return _firestore
          .collection('snaps')
          .where('vendorId', whereIn: followedVendorIds)
          .where('isStory', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100) // Increased limit to get stories from multiple vendors
          .snapshots()
          .asyncMap((snapshot) async {
            developer.log(
              '[FeedService] Received ${snapshot.docs.length} story snaps from followed vendors',
              name: 'FeedService',
            );

            final snaps = snapshot.docs
                .map((doc) => Snap.fromFirestore(doc))
                .toList();

            // Group snaps by vendorId to create story items
            final storyItemsMap = <String, List<Snap>>{};
            for (final snap in snaps) {
              if (!storyItemsMap.containsKey(snap.vendorId)) {
                storyItemsMap[snap.vendorId] = [];
              }
              storyItemsMap[snap.vendorId]!.add(snap);
            }

            // Convert to StoryItem list and sort by most recent snap
            final storyItems = storyItemsMap.entries.map((entry) {
              final vendorSnaps = entry.value;
              // Sort snaps for this vendor by creation time (oldest first for chronological viewing)
              vendorSnaps.sort((a, b) => a.createdAt.compareTo(b.createdAt));

              final latestSnap = vendorSnaps
                  .last; // Latest snap for vendor ordering (last in chronological list)
              return StoryItem(
                vendorId: latestSnap.vendorId,
                vendorName: latestSnap.vendorName,
                vendorAvatarUrl: latestSnap.vendorAvatarUrl,
                snaps: vendorSnaps,
                hasUnseenSnaps: true, // TODO: Implement seen/unseen logic
              );
            }).toList();

            // Sort story items by most recent story (latest snap from each vendor)
            storyItems.sort(
              (a, b) =>
                  b.snaps.last.createdAt.compareTo(a.snaps.last.createdAt),
            );

            developer.log(
              '[FeedService] Created ${storyItems.length} story items from ${snaps.length} snaps',
              name: 'FeedService',
            );

            // Debug: Log each story item with snap counts
            for (final storyItem in storyItems) {
              developer.log(
                '[FeedService] 📚 Story: ${storyItem.vendorName} has ${storyItem.snaps.length} snaps',
                name: 'FeedService',
              );
            }

            // Apply current profile data to all story items
            return await _applyProfileUpdatesToStories(storyItems);
          });
    });
  }

  /// Get stream of followed vendor IDs for the current user
  Stream<List<String>> _getFollowedVendorsStream(String userId) {
    // Note: For now, we'll poll the follow service periodically
    // In a production app, you might want to cache this or use Firestore streams

    // Create a controller that starts with an immediate value
    late StreamController<List<String>> controller;

    // Start with immediate execution
    Future<void> getFollowedVendors() async {
      try {
        final followedIds = await _getFollowedVendorIds(userId);

        // Also include current user's own stories
        if (!followedIds.contains(userId)) {
          followedIds.add(userId);
        }

        if (!controller.isClosed) {
          controller.add(followedIds);
        }
      } catch (e) {
        developer.log(
          '[FeedService] Error getting followed vendors: $e',
          name: 'FeedService',
        );
        // Fallback to just current user
        if (!controller.isClosed) {
          controller.add([userId]);
        }
      }
    }

    controller = StreamController<List<String>>.broadcast(
      onListen: () {
        // Execute immediately on listen
        getFollowedVendors();

        // Set up periodic updates
        Timer.periodic(const Duration(minutes: 5), (_) {
          if (!controller.isClosed) {
            getFollowedVendors();
          }
        });
      },
    );

    return controller.stream;
  }

  /// Get the list of vendor IDs that the current user is following
  /// Uses direct Firestore query to avoid circular dependencies
  Future<List<String>> _getFollowedVendorIds(String userId) async {
    developer.log(
      '[FeedService] Getting followed vendors for user: $userId',
      name: 'FeedService',
    );

    try {
      // Query all vendor collections to find where current user is a follower
      final vendorsSnapshot = await _firestore.collection('vendors').get();
      final followedVendorIds = <String>[];

      for (final vendorDoc in vendorsSnapshot.docs) {
        final followerDoc = await vendorDoc.reference
            .collection('followers')
            .doc(userId)
            .get();

        if (followerDoc.exists) {
          followedVendorIds.add(vendorDoc.id);
        }
      }

      developer.log(
        '[FeedService] User is following ${followedVendorIds.length} vendors',
        name: 'FeedService',
      );
      return followedVendorIds;
    } catch (e) {
      developer.log(
        '[FeedService] Error getting followed vendors: $e',
        name: 'FeedService',
      );
      return [];
    }
  }

  /// Apply cached profile updates to a list of story items
  Future<List<StoryItem>> _applyProfileUpdatesToStories(
    List<StoryItem> stories,
  ) async {
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
        .where(
          'isStory',
          isEqualTo: false,
        ) // Only get regular feed posts, not stories
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          developer.log(
            '[FeedService] Received ${snapshot.docs.length} regular feed snaps (stories excluded)',
            name: 'FeedService',
          );
          final snaps = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();

          // Debug: Verify no stories leaked into feed
          final storyCount = snaps.where((snap) => snap.isStory).length;
          if (storyCount > 0) {
            developer.log(
              '[FeedService] ⚠️ WARNING: $storyCount stories found in regular feed!',
              name: 'FeedService',
            );
          }

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
      _profileUpdateNotifier.allProfileUpdates.map(
        (_) => <Snap>[],
      ), // Trigger refresh on any profile update
    ]).asyncMap((snapsList) async {
      // If it's just a profile update trigger (empty list), get current snaps
      if (snapsList.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection('snaps')
              .where(
                'isStory',
                isEqualTo: false,
              ) // Only get regular feed posts, not stories
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();
          snapsList = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();
        } catch (e) {
          developer.log(
            '[FeedService] Error fetching snaps after profile update: $e',
          );
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

  /// Delete a snap by ID - removes from both Firestore and Storage
  /// Only allows deletion if the current user owns the snap
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteSnap(String snapId) async {
    final currentUser = currentUserId;
    if (currentUser == null) {
      developer.log(
        '[FeedService] ❌ Cannot delete snap: user not authenticated',
        name: 'FeedService',
      );
      return false;
    }

    developer.log(
      '[FeedService] 🗑️ Starting deletion process for snap: $snapId',
      name: 'FeedService',
    );

    try {
      // Step 1: Get the snap document to verify ownership and get media URL
      final snapDoc = await _firestore.collection('snaps').doc(snapId).get();

      if (!snapDoc.exists) {
        developer.log(
          '[FeedService] ❌ Snap not found: $snapId',
          name: 'FeedService',
        );
        return false;
      }

      final snapData = snapDoc.data()!;
      final vendorId = snapData['vendorId'] as String?;
      final mediaUrl = snapData['mediaUrl'] as String?;

      // Step 2: Verify ownership
      if (vendorId != currentUser) {
        developer.log(
          '[FeedService] ❌ Cannot delete snap: user ($currentUser) does not own snap (owner: $vendorId)',
          name: 'FeedService',
        );
        return false;
      }

      developer.log(
        '[FeedService] ✅ Ownership verified - proceeding with deletion',
        name: 'FeedService',
      );

      // Step 3: Delete media file from Firebase Storage (if exists)
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        try {
          // Extract storage path from media URL
          final storageRef = _storage.refFromURL(mediaUrl);
          await storageRef.delete();
          developer.log(
            '[FeedService] ✅ Successfully deleted media file from Storage: ${storageRef.fullPath}',
            name: 'FeedService',
          );
        } catch (storageError) {
          // Log storage deletion error but continue with Firestore deletion
          developer.log(
            '[FeedService] ⚠️ Failed to delete media file from Storage: $storageError',
            name: 'FeedService',
          );
          developer.log(
            '[FeedService] 📋 Media URL was: $mediaUrl',
            name: 'FeedService',
          );
        }
      } else {
        developer.log(
          '[FeedService] ℹ️ No media URL found - skipping Storage deletion',
          name: 'FeedService',
        );
      }

      // Step 4: Delete Firestore document
      await _firestore.collection('snaps').doc(snapId).delete();
      developer.log(
        '[FeedService] ✅ Successfully deleted snap document from Firestore: $snapId',
        name: 'FeedService',
      );

      // Step 5: Log successful completion
      developer.log(
        '[FeedService] 🎉 Snap deletion completed successfully: $snapId',
        name: 'FeedService',
      );

      return true;
    } catch (error, stackTrace) {
      developer.log(
        '[FeedService] ❌ Failed to delete snap $snapId: $error',
        name: 'FeedService',
      );
      developer.log(
        '[FeedService] 📋 Stack trace: $stackTrace',
        name: 'FeedService',
      );
      return false;
    }
  }
}
