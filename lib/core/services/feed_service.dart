import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/snap.dart';
import '../models/vendor.dart';
import '../models/following.dart';

/// Service for managing feed data including snaps, vendors, and following relationships.
class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ======================================
  // SNAP OPERATIONS
  // ======================================

  /// Gets all recent snaps (within 24h) for story reel, ordered by creation time
  Stream<List<Snap>> getRecentSnapsStream({int limit = 50}) {
    debugPrint('[FeedService] Fetching recent snaps stream with limit: $limit');
    
    // Get snaps from last 24 hours
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    try {
      return _firestore
          .collection('snaps')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            debugPrint('[FeedService] Received ${snapshot.docs.length} recent snaps');
            return snapshot.docs
                .map((doc) => Snap.fromFirestore(doc))
                .where((snap) => !snap.hasExpired)
                .toList();
          });
    } catch (e) {
      debugPrint('[FeedService] Error fetching recent snaps: $e');
      return Stream.value([]);
    }
  }

  /// Gets latest snaps from followed vendors for the main feed
  Future<List<Snap>> getFollowedSnaps({
    required String currentUserUid,
    int limit = 30,
  }) async {
    debugPrint('[FeedService] Fetching followed snaps for user: $currentUserUid');
    
    try {
      // First get the vendors the user follows
      final followingSnapshot = await _firestore
          .collection('followers')
          .where('followerUid', isEqualTo: currentUserUid)
          .get();

      if (followingSnapshot.docs.isEmpty) {
        debugPrint('[FeedService] User is not following any vendors');
        return [];
      }

      final followedVendorIds = followingSnapshot.docs
          .map((doc) => doc.data()['vendorUid'] as String)
          .toList();

      debugPrint('[FeedService] User follows ${followedVendorIds.length} vendors');

      // Get latest snaps from followed vendors (max 3 per vendor)
      final List<Snap> allSnaps = [];
      
      for (final vendorId in followedVendorIds) {
        final vendorSnaps = await _firestore
            .collection('snaps')
            .where('vendorUid', isEqualTo: vendorId)
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('createdAt', descending: true)
            .limit(3) // Max 3 snaps per vendor as per requirements
            .get();

        final snaps = vendorSnaps.docs
            .map((doc) => Snap.fromFirestore(doc))
            .where((snap) => !snap.hasExpired)
            .toList();

        allSnaps.addAll(snaps);
      }

      // Sort all snaps by creation time and limit total results
      allSnaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final result = allSnaps.take(limit).toList();
      
      debugPrint('[FeedService] Returning ${result.length} followed snaps');
      return result;
    } catch (e) {
      debugPrint('[FeedService] Error fetching followed snaps: $e');
      return [];
    }
  }

  /// Gets snaps by vendor ID for story viewing
  Stream<List<Snap>> getVendorSnapsStream({
    required String vendorId,
    int limit = 20,
  }) {
    debugPrint('[FeedService] Fetching snaps stream for vendor: $vendorId');
    
    try {
      return _firestore
          .collection('snaps')
          .where('vendorUid', isEqualTo: vendorId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            debugPrint('[FeedService] Received ${snapshot.docs.length} snaps for vendor $vendorId');
            return snapshot.docs
                .map((doc) => Snap.fromFirestore(doc))
                .where((snap) => !snap.hasExpired)
                .toList();
          });
    } catch (e) {
      debugPrint('[FeedService] Error fetching vendor snaps: $e');
      return Stream.value([]);
    }
  }

  // ======================================
  // VENDOR OPERATIONS
  // ======================================

  /// Gets vendor by ID
  Future<Vendor?> getVendor(String vendorId) async {
    debugPrint('[FeedService] Fetching vendor: $vendorId');
    
    try {
      final doc = await _firestore.collection('vendors').doc(vendorId).get();
      
      if (!doc.exists) {
        debugPrint('[FeedService] Vendor not found: $vendorId');
        return null;
      }

      final vendor = Vendor.fromFirestore(doc);
      debugPrint('[FeedService] Retrieved vendor: ${vendor.stallName}');
      return vendor;
    } catch (e) {
      debugPrint('[FeedService] Error fetching vendor: $e');
      return null;
    }
  }

  /// Gets multiple vendors by IDs
  Future<Map<String, Vendor>> getVendors(List<String> vendorIds) async {
    debugPrint('[FeedService] Fetching ${vendorIds.length} vendors');
    
    if (vendorIds.isEmpty) return {};

    try {
      final Map<String, Vendor> vendors = {};
      
      // Batch get vendors (Firestore limit is 10 per batch)
      const batchSize = 10;
      for (int i = 0; i < vendorIds.length; i += batchSize) {
        final batch = vendorIds.skip(i).take(batchSize).toList();
        
        final snapshot = await _firestore
            .collection('vendors')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          vendors[doc.id] = Vendor.fromFirestore(doc);
        }
      }

      debugPrint('[FeedService] Retrieved ${vendors.length} vendors');
      return vendors;
    } catch (e) {
      debugPrint('[FeedService] Error fetching vendors: $e');
      return {};
    }
  }

  /// Gets all active vendors (for discovery)
  Future<List<Vendor>> getAllVendors({int limit = 50}) async {
    debugPrint('[FeedService] Fetching all active vendors');
    
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .where('isActive', isEqualTo: true)
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      final vendors = snapshot.docs
          .map((doc) => Vendor.fromFirestore(doc))
          .toList();

      debugPrint('[FeedService] Retrieved ${vendors.length} active vendors');
      return vendors;
    } catch (e) {
      debugPrint('[FeedService] Error fetching all vendors: $e');
      return [];
    }
  }

  // ======================================
  // FOLLOWING OPERATIONS
  // ======================================

  /// Gets users that the current user is following
  Stream<List<Following>> getFollowingStream(String currentUserUid) {
    debugPrint('[FeedService] Fetching following stream for user: $currentUserUid');
    
    try {
      return _firestore
          .collection('followers')
          .where('followerUid', isEqualTo: currentUserUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('[FeedService] User is following ${snapshot.docs.length} vendors');
            return snapshot.docs
                .map((doc) => Following.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('[FeedService] Error fetching following: $e');
      return Stream.value([]);
    }
  }

  /// Checks if user is following a specific vendor
  Future<bool> isFollowing({
    required String followerUid,
    required String vendorUid,
  }) async {
    debugPrint('[FeedService] Checking if $followerUid follows $vendorUid');
    
    try {
      final snapshot = await _firestore
          .collection('followers')
          .where('followerUid', isEqualTo: followerUid)
          .where('vendorUid', isEqualTo: vendorUid)
          .limit(1)
          .get();

      final isFollowing = snapshot.docs.isNotEmpty;
      debugPrint('[FeedService] Following status: $isFollowing');
      return isFollowing;
    } catch (e) {
      debugPrint('[FeedService] Error checking following status: $e');
      return false;
    }
  }

  /// Follow a vendor
  Future<bool> followVendor({
    required String followerUid,
    required String vendorUid,
    String? fcmToken,
  }) async {
    debugPrint('[FeedService] Following vendor: $vendorUid');
    
    try {
      // Check if already following
      final isAlreadyFollowing = await isFollowing(
        followerUid: followerUid,
        vendorUid: vendorUid,
      );

      if (isAlreadyFollowing) {
        debugPrint('[FeedService] Already following vendor');
        return true;
      }

      // Create following relationship
      final following = Following.create(
        followerUid: followerUid,
        vendorUid: vendorUid,
        fcmToken: fcmToken,
      );

      await _firestore.collection('followers').add(following.toFirestore());
      
      debugPrint('[FeedService] Successfully followed vendor');
      return true;
    } catch (e) {
      debugPrint('[FeedService] Error following vendor: $e');
      return false;
    }
  }

  /// Unfollow a vendor
  Future<bool> unfollowVendor({
    required String followerUid,
    required String vendorUid,
  }) async {
    debugPrint('[FeedService] Unfollowing vendor: $vendorUid');
    
    try {
      final snapshot = await _firestore
          .collection('followers')
          .where('followerUid', isEqualTo: followerUid)
          .where('vendorUid', isEqualTo: vendorUid)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[FeedService] Not following vendor');
        return true;
      }

      // Delete all following relationships (should be only one)
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('[FeedService] Successfully unfollowed vendor');
      return true;
    } catch (e) {
      debugPrint('[FeedService] Error unfollowing vendor: $e');
      return false;
    }
  }

  // ======================================
  // UTILITY METHODS
  // ======================================

  /// Groups snaps by vendor for story reel display
  Map<String, List<Snap>> groupSnapsByVendor(List<Snap> snaps) {
    debugPrint('[FeedService] Grouping ${snaps.length} snaps by vendor');
    
    final Map<String, List<Snap>> grouped = {};
    
    for (final snap in snaps) {
      if (!grouped.containsKey(snap.vendorUid)) {
        grouped[snap.vendorUid] = [];
      }
      grouped[snap.vendorUid]!.add(snap);
    }

    // Sort snaps within each vendor group by creation time
    for (final vendorSnaps in grouped.values) {
      vendorSnaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    debugPrint('[FeedService] Grouped into ${grouped.length} vendor stories');
    return grouped;
  }

  /// Gets combined story reel data (snaps + vendors)
  Future<Map<String, dynamic>> getStoryReelData({
    required String currentUserUid,
    int limit = 50,
  }) async {
    debugPrint('[FeedService] Fetching complete story reel data');
    
    try {
      // Get recent snaps
      final recentSnapsStream = getRecentSnapsStream(limit: limit);
      final recentSnaps = await recentSnapsStream.first;
      
      // Group by vendor
      final groupedSnaps = groupSnapsByVendor(recentSnaps);
      
      // Get vendor info for all vendors with snaps
      final vendorIds = groupedSnaps.keys.toList();
      final vendors = await getVendors(vendorIds);
      
      // Get following status
      final followingStream = getFollowingStream(currentUserUid);
      final following = await followingStream.first;
      final followingMap = {for (final f in following) f.vendorUid: f};
      
      debugPrint('[FeedService] Story reel data ready: ${groupedSnaps.length} vendor stories');
      
      return {
        'snapsByVendor': groupedSnaps,
        'vendors': vendors,
        'following': followingMap,
      };
    } catch (e) {
      debugPrint('[FeedService] Error fetching story reel data: $e');
      return {
        'snapsByVendor': <String, List<Snap>>{},
        'vendors': <String, Vendor>{},
        'following': <String, Following>{},
      };
    }
  }
}