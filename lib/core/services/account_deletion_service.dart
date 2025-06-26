import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'hive_service.dart';
import '../models/pending_media.dart';
import '../models/user_settings.dart';

/// Comprehensive service for deleting user accounts and all associated data
/// Handles cleanup of profile, snaps, messages, storage files, and pending queue
class AccountDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HiveService _hiveService;

  AccountDeletionService({required HiveService hiveService})
      : _hiveService = hiveService;

  /// Get current user's ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Completely delete user account and all associated data
  /// This is a destructive operation that cannot be undone
  Future<void> deleteAccountCompletely({
    required Function(String) onProgress,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    final userId = currentUser.uid;
    developer.log(
      '[AccountDeletionService] Starting complete account deletion for user: $userId',
      name: 'AccountDeletionService',
    );

    try {
      // Step 1: Delete user's snaps and associated media
      onProgress('Deleting your snaps and media...');
      await _deleteUserSnaps(userId);

      // Step 2: Delete user's messages and conversations
      onProgress('Cleaning up your messages...');
      await _deleteUserMessages(userId);

      // Step 3: Delete user's profile data
      onProgress('Removing your profile...');
      await _deleteUserProfile(userId);

      // Step 4: Clean up local data
      onProgress('Cleaning up local data...');
      await _cleanupLocalData(userId);

      // Step 5: Delete Firebase Auth account (must be last)
      onProgress('Deleting your account...');
      await _deleteFirebaseAuthAccount();

      developer.log(
        '[AccountDeletionService] Account deletion completed successfully',
        name: 'AccountDeletionService',
      );
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error during account deletion: $e',
        name: 'AccountDeletionService',
      );
      rethrow;
    }
  }

  /// Delete all snaps created by the user
  Future<void> _deleteUserSnaps(String userId) async {
    developer.log(
      '[AccountDeletionService] Deleting snaps for user: $userId',
      name: 'AccountDeletionService',
    );

    try {
      // Get all user snaps
      final userSnapsQuery = await _firestore
          .collection('snaps')
          .where('vendorId', isEqualTo: userId)
          .get();

      developer.log(
        '[AccountDeletionService] Found ${userSnapsQuery.docs.length} snaps to delete',
        name: 'AccountDeletionService',
      );

      // Delete each snap and its associated media
      final batch = _firestore.batch();
      final List<String> mediaUrls = [];

      for (final doc in userSnapsQuery.docs) {
        // Add to batch delete
        batch.delete(doc.reference);

        // Collect media URL for storage deletion
        final data = doc.data();
        final mediaUrl = data['mediaUrl'] as String?;
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          mediaUrls.add(mediaUrl);
        }
      }

      // Execute batch delete for Firestore documents
      if (userSnapsQuery.docs.isNotEmpty) {
        await batch.commit();
        developer.log(
          '[AccountDeletionService] Deleted ${userSnapsQuery.docs.length} snap documents',
          name: 'AccountDeletionService',
        );
      }

      // Delete media files from Storage
      for (final mediaUrl in mediaUrls) {
        try {
          final ref = _storage.refFromURL(mediaUrl);
          await ref.delete();
          developer.log(
            '[AccountDeletionService] Deleted media file: $mediaUrl',
            name: 'AccountDeletionService',
          );
        } catch (storageError) {
          developer.log(
            '[AccountDeletionService] Could not delete media file (may not exist): $storageError',
            name: 'AccountDeletionService',
          );
          // Continue with other deletions
        }
      }

      // Delete entire user storage folder if it exists
      try {
        final userStorageRef = _storage.ref().child('vendors/$userId');
        final listResult = await userStorageRef.listAll();
        
        for (final item in listResult.items) {
          await item.delete();
        }
        
        developer.log(
          '[AccountDeletionService] Deleted user storage folder: vendors/$userId',
          name: 'AccountDeletionService',
        );
      } catch (e) {
        developer.log(
          '[AccountDeletionService] Could not delete user storage folder: $e',
          name: 'AccountDeletionService',
        );
      }
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error deleting user snaps: $e',
        name: 'AccountDeletionService',
      );
      throw Exception('Failed to delete user snaps: $e');
    }
  }

  /// Delete all messages involving the user
  Future<void> _deleteUserMessages(String userId) async {
    developer.log(
      '[AccountDeletionService] Deleting messages for user: $userId',
      name: 'AccountDeletionService',
    );

    try {
      // Delete messages where user is sender
      final sentMessagesQuery = await _firestore
          .collection('messages')
          .where('fromUid', isEqualTo: userId)
          .get();

      // Delete messages where user is recipient  
      final receivedMessagesQuery = await _firestore
          .collection('messages')
          .where('toUid', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      int deletedCount = 0;

      // Add sent messages to batch
      for (final doc in sentMessagesQuery.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      // Add received messages to batch
      for (final doc in receivedMessagesQuery.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      // Execute batch delete
      if (deletedCount > 0) {
        await batch.commit();
        developer.log(
          '[AccountDeletionService] Deleted $deletedCount messages',
          name: 'AccountDeletionService',
        );
      } else {
        developer.log(
          '[AccountDeletionService] No messages found to delete',
          name: 'AccountDeletionService',
        );
      }
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error deleting user messages: $e',
        name: 'AccountDeletionService',
      );
      throw Exception('Failed to delete user messages: $e');
    }
  }

  /// Delete user's vendor profile
  Future<void> _deleteUserProfile(String userId) async {
    developer.log(
      '[AccountDeletionService] Deleting profile for user: $userId',
      name: 'AccountDeletionService',
    );

    try {
      // Delete profile document from Firestore
      await _firestore.collection('vendors').doc(userId).delete();
      
      developer.log(
        '[AccountDeletionService] Deleted vendor profile document',
        name: 'AccountDeletionService',
      );
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error deleting user profile: $e',
        name: 'AccountDeletionService',
      );
      throw Exception('Failed to delete user profile: $e');
    }
  }

  /// Clean up local data (Hive storage)
  Future<void> _cleanupLocalData(String userId) async {
    developer.log(
      '[AccountDeletionService] Cleaning up local data for user: $userId',
      name: 'AccountDeletionService',
    );

    try {
      // Delete user's vendor profile from local storage
      await _hiveService.deleteVendorProfile(userId);

      // Delete all pending media items for this user
      final allPendingMedia = _hiveService.getAllPendingMedia();
      final userPendingMedia = allPendingMedia
          .where((item) => item.vendorId == userId)
          .toList();

      for (final item in userPendingMedia) {
        await _hiveService.removePendingMedia(item.id);
      }

      developer.log(
        '[AccountDeletionService] Cleaned up ${userPendingMedia.length} pending media items',
        name: 'AccountDeletionService',
      );

      // Reset user settings to defaults
      await _hiveService.updateUserSettings(UserSettings());

      developer.log(
        '[AccountDeletionService] Local data cleanup completed',
        name: 'AccountDeletionService',
      );
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error cleaning up local data: $e',
        name: 'AccountDeletionService',
      );
      throw Exception('Failed to clean up local data: $e');
    }
  }

  /// Delete the Firebase Auth account (must be called last)
  Future<void> _deleteFirebaseAuthAccount() async {
    developer.log(
      '[AccountDeletionService] Deleting Firebase Auth account',
      name: 'AccountDeletionService',
    );

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in for account deletion');
      }

      await user.delete();
      
      developer.log(
        '[AccountDeletionService] Firebase Auth account deleted successfully',
        name: 'AccountDeletionService',
      );
    } on FirebaseAuthException catch (e) {
      developer.log(
        '[AccountDeletionService] Firebase Auth deletion failed: ${e.code} - ${e.message}',
        name: 'AccountDeletionService',
      );

      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Recent authentication required. Please sign in again and try deleting your account.',
        );
      }

      throw Exception('Failed to delete account: ${e.message}');
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Account deletion error: $e',
        name: 'AccountDeletionService',
      );
      throw Exception('Failed to delete account. Please try again.');
    }
  }

  /// Check if the user can delete their account (authenticated and profile exists)
  bool canDeleteAccount() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final profile = _hiveService.getVendorProfile(user.uid);
    return profile != null;
  }

  /// Get a summary of data that will be deleted
  Future<Map<String, int>> getAccountDataSummary() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {};
    }

    final userId = user.uid;
    
    try {
      // Count snaps
      final snapsQuery = await _firestore
          .collection('snaps')
          .where('vendorId', isEqualTo: userId)
          .get();

      // Count messages (sent + received)
      final sentMessagesQuery = await _firestore
          .collection('messages')
          .where('fromUid', isEqualTo: userId)
          .get();
      
      final receivedMessagesQuery = await _firestore
          .collection('messages')
          .where('toUid', isEqualTo: userId)
          .get();

      // Count pending media
      final pendingMedia = _hiveService.getAllPendingMedia()
          .where((item) => item.vendorId == userId)
          .length;

      return {
        'snaps': snapsQuery.docs.length,
        'messages': sentMessagesQuery.docs.length + receivedMessagesQuery.docs.length,
        'pendingMedia': pendingMedia,
      };
    } catch (e) {
      developer.log(
        '[AccountDeletionService] Error getting account data summary: $e',
        name: 'AccountDeletionService',
      );
      return {};
    }
  }
}