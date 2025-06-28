import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/broadcast.dart';

import 'location_service.dart';
import 'hive_service.dart';
import '../../features/profile/application/profile_service.dart';

/// Service for managing broadcast functionality
/// Handles creation, posting, and filtering of text broadcasts
class BroadcastService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  final HiveService _hiveService;
  final ProfileService _profileService;
  
  static const _uuid = Uuid();

  BroadcastService({
    required HiveService hiveService,
    required ProfileService profileService,
  }) : _hiveService = hiveService,
       _profileService = profileService;

  /// Get current user's UID
  String? get _currentUserUid => _auth.currentUser?.uid;

  /// Create and post a new broadcast
  /// Returns broadcast ID if successful, null if failed
  Future<String?> createBroadcast({
    required String message,
    bool includeLocation = false,
  }) async {
    try {
      final uid = _currentUserUid;
      if (uid == null) {
        developer.log('[BroadcastService] ❌ No authenticated user');
        throw Exception('User must be authenticated to create broadcasts');
      }

      // Validate message
      if (message.trim().isEmpty) {
        developer.log('[BroadcastService] ❌ Empty message provided');
        throw Exception('Broadcast message cannot be empty');
      }

      if (message.trim().length > 100) {
        developer.log('[BroadcastService] ❌ Message too long: ${message.length} chars');
        throw Exception('Broadcast message must be 100 characters or less');
      }

      developer.log('[BroadcastService] 📢 Creating broadcast with ${message.length} chars, includeLocation: $includeLocation');

      // Get user profile for vendor info
      final profile = _profileService.getCurrentUserProfile();
      if (profile == null) {
        developer.log('[BroadcastService] ❌ No user profile found');
        throw Exception('User profile required to create broadcasts');
      }

      // Get location if requested and enabled in settings
      CoarseLocation? location;
      if (includeLocation) {
        final settings = _hiveService.getUserSettings();
        final locationEnabled = settings?.enableCoarseLocation ?? false;
        
        if (locationEnabled) {
          developer.log('[BroadcastService] 📍 Getting location for broadcast...');
          location = await _locationService.getCurrentCoarseLocation();
          if (location == null) {
            developer.log('[BroadcastService] ⚠️ Could not get location, proceeding without it');
          } else {
            developer.log('[BroadcastService] ✅ Location obtained: $location');
          }
        } else {
          developer.log('[BroadcastService] ⚠️ Location not enabled in settings');
        }
      }

      // Create broadcast object
      final broadcastId = _uuid.v4();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24)); // 24 hour TTL

      final broadcast = Broadcast(
        id: broadcastId,
        vendorUid: uid,
        vendorName: profile.displayName,
        vendorAvatarUrl: profile.avatarURL ?? '',
        stallName: profile.stallName,
        message: message.trim(),
        createdAt: now,
        expiresAt: expiresAt,
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: location?.name,
      );

      developer.log('[BroadcastService] 💾 Saving broadcast to Firestore...');

      // Save to Firestore (this will trigger the fanOutBroadcast Cloud Function)
      await _firestore
          .collection('broadcasts')
          .doc(broadcastId)
          .set(broadcast.toFirestore());

      developer.log('[BroadcastService] ✅ Broadcast created successfully: $broadcastId');
      return broadcastId;

    } catch (e) {
      developer.log('[BroadcastService] ❌ Error creating broadcast: $e');
      rethrow;
    }
  }

  /// Get stream of all broadcasts, optionally filtered by distance
  Stream<List<Broadcast>> getBroadcastsStream({
    double? maxDistanceKm,
    int limit = 50,
  }) {
    try {
      developer.log('[BroadcastService] 📡 Setting up broadcasts stream with limit: $limit, maxDistance: $maxDistanceKm km');

      // Get base query for unexpired broadcasts
      Query query = _firestore
          .collection('broadcasts')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      return query.snapshots().asyncMap((snapshot) async {
        if (snapshot.docs.isEmpty) {
          developer.log('[BroadcastService] 📡 No broadcasts found');
          return <Broadcast>[];
        }

        // Convert documents to broadcast objects
        List<Broadcast> broadcasts = snapshot.docs
            .map((doc) => Broadcast.fromFirestore(doc))
            .toList();

        developer.log('[BroadcastService] 📡 Loaded ${broadcasts.length} broadcasts from Firestore');

        // Apply distance filtering if requested
        if (maxDistanceKm != null) {
          broadcasts = await _filterBroadcastsByDistance(broadcasts, maxDistanceKm);
          developer.log('[BroadcastService] 📍 After distance filtering: ${broadcasts.length} broadcasts');
        }

        // Update with fresh profile data
        broadcasts = await _updateBroadcastsWithFreshProfiles(broadcasts);

        developer.log('[BroadcastService] ✅ Returning ${broadcasts.length} broadcasts');
        return broadcasts;
      });

    } catch (e) {
      developer.log('[BroadcastService] ❌ Error setting up broadcasts stream: $e');
      return Stream.error(e);
    }
  }

  /// Filter broadcasts by distance from user's current location
  Future<List<Broadcast>> _filterBroadcastsByDistance(
    List<Broadcast> broadcasts, 
    double maxDistanceKm
  ) async {
    try {
      // Get user's current location
      final userLocation = await _locationService.getCurrentCoarseLocation();
      if (userLocation == null) {
        developer.log('[BroadcastService] 📍 No user location for distance filtering, returning all');
        return broadcasts;
      }

      // Filter broadcasts by distance
      final filteredBroadcasts = <Broadcast>[];
      
      for (final broadcast in broadcasts) {
        if (!broadcast.hasLocation) {
          // Include broadcasts without location (don't discriminate)
          filteredBroadcasts.add(broadcast);
          continue;
        }

        final distance = LocationService.calculateDistance(
          userLocation,
          CoarseLocation(
            latitude: broadcast.latitude!,
            longitude: broadcast.longitude!,
            name: broadcast.locationName,
          ),
        );

        if (distance != null && distance <= maxDistanceKm) {
          filteredBroadcasts.add(broadcast);
          developer.log('[BroadcastService] 📍 Included broadcast ${broadcast.id} (${distance.toStringAsFixed(1)} km away)');
        } else {
          developer.log('[BroadcastService] 📍 Excluded broadcast ${broadcast.id} (${distance?.toStringAsFixed(1) ?? 'unknown'} km away)');
        }
      }

      return filteredBroadcasts;
    } catch (e) {
      developer.log('[BroadcastService] ❌ Error filtering broadcasts by distance: $e');
      return broadcasts; // Return unfiltered on error
    }
  }

  /// Update broadcasts with fresh profile data from cache
  Future<List<Broadcast>> _updateBroadcastsWithFreshProfiles(List<Broadcast> broadcasts) async {
    try {
      // Update broadcasts with cached profile data
      final updatedBroadcasts = <Broadcast>[];
      
      for (final broadcast in broadcasts) {
        // Try to get fresh profile data from cache
        final profile = _hiveService.getVendorProfile(broadcast.vendorUid);
        
        if (profile != null) {
          // Update with fresh profile data
          final updatedBroadcast = broadcast.updateProfileData(
            vendorName: profile.displayName,
            vendorAvatarUrl: profile.avatarURL ?? '',
            stallName: profile.stallName,
          );
          updatedBroadcasts.add(updatedBroadcast);
        } else {
          // Keep original data if no cached profile
          updatedBroadcasts.add(broadcast);
        }
      }

      return updatedBroadcasts;
    } catch (e) {
      developer.log('[BroadcastService] ❌ Error updating broadcasts with profiles: $e');
      return broadcasts; // Return original on error
    }
  }

  /// Delete a broadcast (only by its creator)
  Future<void> deleteBroadcast(String broadcastId) async {
    try {
      final uid = _currentUserUid;
      if (uid == null) {
        throw Exception('User must be authenticated to delete broadcasts');
      }

      developer.log('[BroadcastService] 🗑️ Deleting broadcast: $broadcastId');

      // Get broadcast to verify ownership
      final doc = await _firestore.collection('broadcasts').doc(broadcastId).get();
      if (!doc.exists) {
        throw Exception('Broadcast not found');
      }

      final data = doc.data()!;
      if (data['vendorUid'] != uid) {
        throw Exception('You can only delete your own broadcasts');
      }

      // Delete the broadcast
      await _firestore.collection('broadcasts').doc(broadcastId).delete();

      developer.log('[BroadcastService] ✅ Broadcast deleted successfully: $broadcastId');

    } catch (e) {
      developer.log('[BroadcastService] ❌ Error deleting broadcast: $e');
      rethrow;
    }
  }

  /// Get broadcasts for a specific vendor
  Stream<List<Broadcast>> getVendorBroadcastsStream(String vendorId, {int limit = 20}) {
    try {
      developer.log('[BroadcastService] 📡 Setting up vendor broadcasts stream for: $vendorId');

      return _firestore
          .collection('broadcasts')
          .where('vendorUid', isEqualTo: vendorId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final broadcasts = snapshot.docs
                .map((doc) => Broadcast.fromFirestore(doc))
                .toList();
            
            developer.log('[BroadcastService] 📡 Vendor broadcasts loaded: ${broadcasts.length}');
            return broadcasts;
          });

    } catch (e) {
      developer.log('[BroadcastService] ❌ Error setting up vendor broadcasts stream: $e');
      return Stream.error(e);
    }
  }

  /// Check if user can create broadcasts (must be a vendor with complete profile)
  bool canCreateBroadcasts() {
    try {
      final uid = _currentUserUid;
      if (uid == null) return false;

      final profile = _profileService.getCurrentUserProfile();
      return profile != null && profile.isComplete;
    } catch (e) {
      developer.log('[BroadcastService] ❌ Error checking broadcast permissions: $e');
      return false;
    }
  }

  /// Get statistics about broadcasts for analytics
  Future<Map<String, dynamic>> getBroadcastStats() async {
    try {
      final uid = _currentUserUid;
      if (uid == null) return {};

      // Get user's broadcasts count
      final userBroadcasts = await _firestore
          .collection('broadcasts')
          .where('vendorUid', isEqualTo: uid)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .count()
          .get();

      // Get total broadcasts count
      final totalBroadcasts = await _firestore
          .collection('broadcasts')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .count()
          .get();

      return {
        'userBroadcasts': userBroadcasts.count ?? 0,
        'totalBroadcasts': totalBroadcasts.count ?? 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      developer.log('[BroadcastService] ❌ Error getting broadcast stats: $e');
      return {};
    }
  }
} 