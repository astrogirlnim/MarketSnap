import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service for managing follow/unfollow functionality between regular users and vendors
/// Handles the followers collection in Firestore and FCM token management for push notifications
class FollowService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  FollowService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  /// Gets the current user's UID
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Follows a vendor by creating a document in the vendor's followers sub-collection
  /// Also saves the user's FCM token for push notifications
  Future<void> followVendor(String vendorId) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to follow vendors');
    }

    developer.log(
      '[FollowService] Following vendor: $vendorId',
      name: 'FollowService',
    );

    try {
      // Get FCM token for push notifications
      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
        developer.log(
          '[FollowService] FCM token obtained for notifications',
          name: 'FollowService',
        );
      } catch (e) {
        developer.log(
          '[FollowService] Warning: Could not get FCM token: $e',
          name: 'FollowService',
        );
        // Continue without FCM token - follow will still work
      }

      // Create follower document in vendor's followers sub-collection
      final followData = {
        'followerUid': uid,
        'followedAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken, // For push notifications
      };

      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('followers')
          .doc(uid)
          .set(followData);

      developer.log(
        '[FollowService] ✅ Successfully followed vendor: $vendorId',
        name: 'FollowService',
      );
    } catch (e) {
      developer.log(
        '[FollowService] Error following vendor $vendorId: $e',
        name: 'FollowService',
      );
      throw Exception('Failed to follow vendor: $e');
    }
  }

  /// Unfollows a vendor by deleting the document from the vendor's followers sub-collection
  Future<void> unfollowVendor(String vendorId) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to unfollow vendors');
    }

    developer.log(
      '[FollowService] Unfollowing vendor: $vendorId',
      name: 'FollowService',
    );

    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('followers')
          .doc(uid)
          .delete();

      developer.log(
        '[FollowService] ✅ Successfully unfollowed vendor: $vendorId',
        name: 'FollowService',
      );
    } catch (e) {
      developer.log(
        '[FollowService] Error unfollowing vendor $vendorId: $e',
        name: 'FollowService',
      );
      throw Exception('Failed to unfollow vendor: $e');
    }
  }

  /// Checks if the current user is following a specific vendor
  Future<bool> isFollowingVendor(String vendorId) async {
    final uid = currentUserUid;
    if (uid == null) {
      return false;
    }

    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('followers')
          .doc(uid)
          .get();

      final isFollowing = doc.exists;
      developer.log(
        '[FollowService] User following vendor $vendorId: $isFollowing',
        name: 'FollowService',
      );
      return isFollowing;
    } catch (e) {
      developer.log(
        '[FollowService] Error checking follow status for vendor $vendorId: $e',
        name: 'FollowService',
      );
      return false; // Assume not following on error
    }
  }

  /// Gets the list of vendor IDs that the current user is following
  Future<List<String>> getFollowedVendorIds() async {
    final uid = currentUserUid;
    if (uid == null) {
      return [];
    }

    developer.log(
      '[FollowService] Getting followed vendors for user: $uid',
      name: 'FollowService',
    );

    try {
      // Query all vendor collections to find where current user is a follower
      final vendorsSnapshot = await _firestore.collection('vendors').get();
      final followedVendorIds = <String>[];

      for (final vendorDoc in vendorsSnapshot.docs) {
        final followerDoc = await vendorDoc.reference
            .collection('followers')
            .doc(uid)
            .get();

        if (followerDoc.exists) {
          followedVendorIds.add(vendorDoc.id);
        }
      }

      developer.log(
        '[FollowService] User is following ${followedVendorIds.length} vendors',
        name: 'FollowService',
      );
      return followedVendorIds;
    } catch (e) {
      developer.log(
        '[FollowService] Error getting followed vendors: $e',
        name: 'FollowService',
      );
      return [];
    }
  }

  /// Gets the follower count for a specific vendor
  Future<int> getVendorFollowerCount(String vendorId) async {
    try {
      final followersSnapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('followers')
          .get();

      final count = followersSnapshot.docs.length;
      developer.log(
        '[FollowService] Vendor $vendorId has $count followers',
        name: 'FollowService',
      );
      return count;
    } catch (e) {
      developer.log(
        '[FollowService] Error getting follower count for vendor $vendorId: $e',
        name: 'FollowService',
      );
      return 0;
    }
  }

  /// Updates the FCM token for all vendors the current user is following
  /// This should be called when the FCM token is refreshed
  Future<void> updateFCMTokenForFollowedVendors() async {
    final uid = currentUserUid;
    if (uid == null) {
      return;
    }

    developer.log(
      '[FollowService] Updating FCM token for followed vendors',
      name: 'FollowService',
    );

    try {
      // Get new FCM token
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        developer.log(
          '[FollowService] No FCM token available',
          name: 'FollowService',
        );
        return;
      }

      // Get all followed vendor IDs
      final followedVendorIds = await getFollowedVendorIds();

      // Update FCM token for each followed vendor
      final batch = _firestore.batch();

      for (final vendorId in followedVendorIds) {
        final followerRef = _firestore
            .collection('vendors')
            .doc(vendorId)
            .collection('followers')
            .doc(uid);

        batch.update(followerRef, {'fcmToken': fcmToken});
      }

      await batch.commit();

      developer.log(
        '[FollowService] ✅ Updated FCM token for ${followedVendorIds.length} vendors',
        name: 'FollowService',
      );
    } catch (e) {
      developer.log(
        '[FollowService] Error updating FCM tokens: $e',
        name: 'FollowService',
      );
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Stream of follow status for a specific vendor
  /// Useful for real-time UI updates
  Stream<bool> followStatusStream(String vendorId) {
    final uid = currentUserUid;
    if (uid == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('followers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Stream of follower count for a specific vendor
  /// Useful for real-time follower count updates
  Stream<int> followerCountStream(String vendorId) {
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
