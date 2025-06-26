import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/core/services/hive_service.dart';
import 'package:marketsnap/core/models/pending_media.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Note: _auth will be used for user-specific feed filtering in future updates
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HiveService? _hiveService;

  FeedService({HiveService? hiveService}) : _hiveService = hiveService;

  /// Get current user's ID for distinguishing own posts
  String? get currentUserId => _auth.currentUser?.uid;

  /// Real-time stream of stories from all vendors
  /// In a real app, this would be filtered by followed vendors
  Stream<List<StoryItem>> getStoriesStream() {
    developer.log(
      '[FeedService] Setting up real-time stories stream',
      name: 'FeedService',
    );

    return _firestore
        .collection('snaps')
        .orderBy('createdAt', descending: true)
        .limit(50) // Get more snaps to group by vendor
        .snapshots()
        .map((snapshot) {
          developer.log(
            '[FeedService] Received ${snapshot.docs.length} snaps for stories',
            name: 'FeedService',
          );

          final snaps = snapshot.docs
              .map((doc) => Snap.fromFirestore(doc))
              .toList();

          // Group snaps by vendor
          final Map<String, List<Snap>> snapsByVendor = {};
          for (var snap in snaps) {
            if (!snapsByVendor.containsKey(snap.vendorId)) {
              snapsByVendor[snap.vendorId] = [];
            }
            snapsByVendor[snap.vendorId]!.add(snap);
          }

          // Create StoryItems
          final List<StoryItem> stories = [];
          snapsByVendor.forEach((vendorId, vendorSnaps) {
            if (vendorSnaps.isNotEmpty) {
              stories.add(
                StoryItem(
                  vendorId: vendorId,
                  vendorName: vendorSnaps.first.vendorName,
                  vendorAvatarUrl: vendorSnaps.first.vendorAvatarUrl,
                  snaps: vendorSnaps,
                  hasUnseenSnaps:
                      true, // In a real app, this would track viewed status
                ),
              );
            }
          });

          developer.log(
            '[FeedService] Created ${stories.length} story items',
            name: 'FeedService',
          );
          return stories;
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

  /// Delete a snap (only allowed for snap owner)
  /// Removes snap from Firestore and deletes associated media from Storage
  Future<void> deleteSnap(Snap snap) async {
    final currentUser = currentUserId;
    if (currentUser == null) {
      throw Exception('User must be authenticated to delete snaps');
    }

    if (snap.vendorId != currentUser) {
      throw Exception('You can only delete your own snaps');
    }

    developer.log(
      '[FeedService] Deleting snap: ${snap.id} by user: $currentUser',
      name: 'FeedService',
    );

    try {
      // Delete the Firestore document
      await _firestore.collection('snaps').doc(snap.id).delete();
      developer.log(
        '[FeedService] Successfully deleted snap document: ${snap.id}',
        name: 'FeedService',
      );

      // Delete the media file from Storage if it exists
      if (snap.mediaUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(snap.mediaUrl);
          await ref.delete();
          developer.log(
            '[FeedService] Successfully deleted media file: ${snap.mediaUrl}',
            name: 'FeedService',
          );
        } catch (storageError) {
          developer.log(
            '[FeedService] Could not delete media file (may not exist): $storageError',
            name: 'FeedService',
          );
          // Don't throw - the Firestore deletion succeeded
        }
      }

      developer.log(
        '[FeedService] Snap deletion completed successfully: ${snap.id}',
        name: 'FeedService',
      );
    } catch (e) {
      developer.log(
        '[FeedService] Error deleting snap: $e',
        name: 'FeedService',
      );
      throw Exception('Failed to delete snap: $e');
    }
  }

  /// Remove pending media item from local queue by caption/file path matching
  /// This is used when user wants to delete a snap that hasn't been uploaded yet
  Future<void> removePendingMediaByContent({
    String? caption,
    String? filePath,
  }) async {
    if (_hiveService == null) {
      developer.log(
        '[FeedService] Cannot remove pending media - HiveService not available',
        name: 'FeedService',
      );
      return;
    }

    final currentUser = currentUserId;
    if (currentUser == null) {
      throw Exception('User must be authenticated to remove pending media');
    }

    developer.log(
      '[FeedService] Searching for pending media to remove for user: $currentUser',
      name: 'FeedService',
    );

    try {
      final allPendingMedia = _hiveService!.getAllPendingMedia();
      final userPendingMedia = allPendingMedia
          .where((item) => item.vendorId == currentUser)
          .toList();

      developer.log(
        '[FeedService] Found ${userPendingMedia.length} pending media items for user',
        name: 'FeedService',
      );

      // Find matching pending media by caption and/or file path
      PendingMediaItem? matchingItem;
      for (final item in userPendingMedia) {
        final captionMatches = caption != null && 
            item.caption != null && 
            item.caption == caption;
        final pathMatches = filePath != null && 
            item.filePath == filePath;

        if (captionMatches || pathMatches) {
          matchingItem = item;
          break;
        }
      }

      if (matchingItem != null) {
        await _hiveService!.removePendingMedia(matchingItem.id);
        developer.log(
          '[FeedService] Successfully removed pending media: ${matchingItem.id}',
          name: 'FeedService',
        );
      } else {
        developer.log(
          '[FeedService] No matching pending media found',
          name: 'FeedService',
        );
      }
    } catch (e) {
      developer.log(
        '[FeedService] Error removing pending media: $e',
        name: 'FeedService',
      );
      // Don't throw - this is a best-effort cleanup
    }
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
