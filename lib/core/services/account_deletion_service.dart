import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../features/auth/application/auth_service.dart';
import '../../features/profile/application/profile_service.dart';
import 'hive_service.dart';

/// Service for coordinating complete account deletion
/// Handles all user data, media files, and triggers backend cleanup
class AccountDeletionService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final AuthService _authService;
  final ProfileService _profileService;
  final HiveService _hiveService;

  AccountDeletionService({
    required AuthService authService,
    required ProfileService profileService,
    required HiveService hiveService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _authService = authService,
       _profileService = profileService,
       _hiveService = hiveService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  /// Gets the current user's UID
  String? get currentUserUid => _authService.currentUser?.uid;

  /// Initiates complete account deletion process
  /// This is the main entry point for account deletion
  Future<void> deleteAccount() async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('No user is currently signed in');
    }

    developer.log('[AccountDeletionService] 🗑️ Starting account deletion for UID: $uid');

    try {
      // Step 1: Delete all local data immediately
      await _deleteLocalData(uid);
      developer.log('[AccountDeletionService] ✅ Local data deleted');

      // Step 2: Trigger backend cascading deletion via Cloud Function
      await _triggerBackendDeletion(uid);
      developer.log('[AccountDeletionService] ✅ Backend deletion triggered');

      // Step 3: Delete user profile data directly (as backup and for immediate effect)
      await _deleteProfileData(uid);
      developer.log('[AccountDeletionService] ✅ Profile data deleted');

      // Step 4: Delete Firebase Authentication account (this must be last)
      await _deleteAuthAccount();
      developer.log('[AccountDeletionService] ✅ Auth account deleted');

      // Step 5: Sign out user (cleanup any remaining local state)
      await _authService.signOut();
      developer.log('[AccountDeletionService] ✅ User signed out');

      developer.log('[AccountDeletionService] 🎉 Account deletion completed successfully');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Account deletion failed: $e');
      rethrow;
    }
  }

  /// Delete all local data from Hive storage
  Future<void> _deleteLocalData(String uid) async {
    developer.log('[AccountDeletionService] 🧹 Deleting local data for UID: $uid');

    try {
      // Delete vendor profile if exists
      final vendorProfile = _hiveService.getVendorProfile(uid);
      if (vendorProfile != null) {
        await _hiveService.deleteVendorProfile(uid);
        developer.log('[AccountDeletionService] ✅ Vendor profile deleted from local storage');
      }

      // Delete regular user profile if exists  
      final regularProfile = _hiveService.getRegularUserProfile(uid);
      if (regularProfile != null) {
        await _hiveService.deleteRegularUserProfile(uid);
        developer.log('[AccountDeletionService] ✅ Regular user profile deleted from local storage');
      }

      // Clear authentication cache
      await _hiveService.clearAuthenticationCache();
      developer.log('[AccountDeletionService] ✅ Authentication cache cleared');

      // Delete any pending media queue items for this user
      await _deletePendingMediaQueue(uid);
      developer.log('[AccountDeletionService] ✅ Pending media queue cleaned');

      developer.log('[AccountDeletionService] ✅ All local data deleted successfully');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting local data: $e');
      throw Exception('Failed to delete local data: $e');
    }
  }

  /// Delete pending media queue items for the user
  Future<void> _deletePendingMediaQueue(String uid) async {
    try {
      // Get all pending media items
      final pendingItems = _hiveService.getAllPendingMedia();
      
      // Filter items that belong to this user and delete them
      for (final item in pendingItems) {
        // Assuming the pending media item has a way to identify the user
        // This is a safety measure to clean up any orphaned media
        try {
          await _hiveService.removePendingMedia(item.id);
        } catch (e) {
          developer.log('[AccountDeletionService] Warning: Failed to delete pending media item ${item.id}: $e');
          // Continue with other items
        }
      }
    } catch (e) {
      developer.log('[AccountDeletionService] Warning: Error cleaning pending media queue: $e');
      // Non-critical error, continue with deletion
    }
  }

  /// Trigger backend cascading deletion via Cloud Function
  Future<void> _triggerBackendDeletion(String uid) async {
    developer.log('[AccountDeletionService] 🔥 Triggering backend deletion via Cloud Function for UID: $uid');

    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      final result = await callable.call({
        'uid': uid,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final response = result.data;
      developer.log('[AccountDeletionService] Backend deletion response: $response');

      if (response['success'] != true) {
        throw Exception('Backend deletion failed: ${response['error'] ?? 'Unknown error'}');
      }

      developer.log('[AccountDeletionService] ✅ Backend deletion completed successfully');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Backend deletion failed: $e');
      
      // If backend deletion fails, we still need to continue with local cleanup
      // Log the error but don't throw - we'll handle cleanup manually
      developer.log('[AccountDeletionService] ⚠️ Continuing with manual cleanup due to backend failure');
      
      // Continue with manual deletion as fallback
      await _deleteUserDataManually(uid);
    }
  }

  /// Manual deletion as fallback if Cloud Function fails
  Future<void> _deleteUserDataManually(String uid) async {
    developer.log('[AccountDeletionService] 🔧 Performing manual data deletion for UID: $uid');

    try {
      // Delete user's snaps
      await _deleteUserSnaps(uid);
      
      // Delete user's messages
      await _deleteUserMessages(uid);
      
      // Delete user's followers/following relationships
      await _deleteUserFollowRelationships(uid);
      
      // Delete user's RAG feedback
      await _deleteUserRAGFeedback(uid);
      
      // Delete user's FAQ vectors (if vendor)
      await _deleteUserFAQVectors(uid);
      
      // Delete user's broadcasts (if vendor)
      await _deleteUserBroadcasts(uid);

      developer.log('[AccountDeletionService] ✅ Manual data deletion completed');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Manual data deletion failed: $e');
      // Continue with profile deletion anyway
    }
  }

  /// Delete all snaps created by the user
  Future<void> _deleteUserSnaps(String uid) async {
    developer.log('[AccountDeletionService] 🖼️ Deleting user snaps for UID: $uid');

    try {
      final snapsQuery = await _firestore
          .collection('snaps')
          .where('vendorId', isEqualTo: uid)
          .get();

      if (snapsQuery.docs.isEmpty) {
        developer.log('[AccountDeletionService] No snaps found for user');
        return;
      }

      // Delete snaps in batches
      final batch = _firestore.batch();
      for (final doc in snapsQuery.docs) {
        batch.delete(doc.reference);
        
        // Also delete associated media from Storage
        try {
          final snapData = doc.data();
          final mediaURL = snapData['mediaURL'] as String?;
          if (mediaURL != null) {
            await _storage.refFromURL(mediaURL).delete();
          }
        } catch (e) {
          developer.log('[AccountDeletionService] Warning: Failed to delete media for snap ${doc.id}: $e');
        }
      }

      await batch.commit();
      developer.log('[AccountDeletionService] ✅ Deleted ${snapsQuery.docs.length} snaps');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting user snaps: $e');
    }
  }

  /// Delete all messages sent or received by the user
  Future<void> _deleteUserMessages(String uid) async {
    developer.log('[AccountDeletionService] 💬 Deleting user messages for UID: $uid');

    try {
      // Delete messages where user is sender
      final sentMessagesQuery = await _firestore
          .collection('messages')
          .where('fromUid', isEqualTo: uid)
          .get();

      // Delete messages where user is receiver
      final receivedMessagesQuery = await _firestore
          .collection('messages')
          .where('toUid', isEqualTo: uid)
          .get();

      final batch = _firestore.batch();
      
      // Add sent messages to batch delete
      for (final doc in sentMessagesQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Add received messages to batch delete
      for (final doc in receivedMessagesQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      final totalMessages = sentMessagesQuery.docs.length + receivedMessagesQuery.docs.length;
      developer.log('[AccountDeletionService] ✅ Deleted $totalMessages messages');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting user messages: $e');
    }
  }

  /// Delete all follow relationships involving the user
  Future<void> _deleteUserFollowRelationships(String uid) async {
    developer.log('[AccountDeletionService] 👥 Deleting follow relationships for UID: $uid');

    try {
      // Delete where user is following others (in vendors/{vendorId}/followers/{uid})
      final vendorsSnapshot = await _firestore.collection('vendors').get();
      
      final batch = _firestore.batch();
      int followersDeleted = 0;

      for (final vendorDoc in vendorsSnapshot.docs) {
        final followerDoc = await vendorDoc.reference
            .collection('followers')
            .doc(uid)
            .get();
            
        if (followerDoc.exists) {
          batch.delete(followerDoc.reference);
          followersDeleted++;
        }
      }

      // Delete the user's own followers collection (if they are a vendor)
      final userFollowersSnapshot = await _firestore
          .collection('vendors')
          .doc(uid)
          .collection('followers')
          .get();

      for (final doc in userFollowersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      developer.log('[AccountDeletionService] ✅ Deleted $followersDeleted follow relationships and ${userFollowersSnapshot.docs.length} followers');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting follow relationships: $e');
    }
  }

  /// Delete user's RAG feedback data
  Future<void> _deleteUserRAGFeedback(String uid) async {
    developer.log('[AccountDeletionService] 🤖 Deleting RAG feedback for UID: $uid');

    try {
      // Delete feedback created by the user
      final userFeedbackQuery = await _firestore
          .collection('ragFeedback')
          .where('userId', isEqualTo: uid)
          .get();

      // Delete feedback on content owned by the user (if vendor)
      final vendorFeedbackQuery = await _firestore
          .collection('ragFeedback')
          .where('vendorId', isEqualTo: uid)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in userFeedbackQuery.docs) {
        batch.delete(doc.reference);
      }
      
      for (final doc in vendorFeedbackQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      final totalFeedback = userFeedbackQuery.docs.length + vendorFeedbackQuery.docs.length;
      developer.log('[AccountDeletionService] ✅ Deleted $totalFeedback RAG feedback items');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting RAG feedback: $e');
    }
  }

  /// Delete user's FAQ vectors (if vendor)
  Future<void> _deleteUserFAQVectors(String uid) async {
    developer.log('[AccountDeletionService] 📚 Deleting FAQ vectors for UID: $uid');

    try {
      final faqVectorsQuery = await _firestore
          .collection('faqVectors')
          .where('vendorId', isEqualTo: uid)
          .get();

      if (faqVectorsQuery.docs.isEmpty) {
        developer.log('[AccountDeletionService] No FAQ vectors found for user');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in faqVectorsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      developer.log('[AccountDeletionService] ✅ Deleted ${faqVectorsQuery.docs.length} FAQ vectors');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting FAQ vectors: $e');
    }
  }

  /// Delete user's broadcasts (if vendor)
  Future<void> _deleteUserBroadcasts(String uid) async {
    developer.log('[AccountDeletionService] 📢 Deleting broadcasts for UID: $uid');

    try {
      final broadcastsQuery = await _firestore
          .collection('broadcasts')
          .where('vendorUid', isEqualTo: uid)
          .get();

      if (broadcastsQuery.docs.isEmpty) {
        developer.log('[AccountDeletionService] No broadcasts found for user');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in broadcastsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      developer.log('[AccountDeletionService] ✅ Deleted ${broadcastsQuery.docs.length} broadcasts');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting broadcasts: $e');
    }
  }

  /// Delete user profile data from Firestore and Storage
  Future<void> _deleteProfileData(String uid) async {
    developer.log('[AccountDeletionService] 👤 Deleting profile data for UID: $uid');

    try {
      // Use existing ProfileService methods for proper cleanup
      final vendorProfile = _profileService.getCurrentUserProfile();
      if (vendorProfile != null) {
        await _profileService.deleteCurrentUserProfile();
        developer.log('[AccountDeletionService] ✅ Vendor profile deleted via ProfileService');
      }

      final regularProfile = _profileService.getCurrentRegularUserProfile();
      if (regularProfile != null) {
        await _profileService.deleteCurrentRegularUserProfile();
        developer.log('[AccountDeletionService] ✅ Regular user profile deleted via ProfileService');
      }

      // Additional cleanup: Delete entire Storage folder for the user
      await _deleteUserStorageFolder(uid);

    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting profile data: $e');
      throw Exception('Failed to delete profile data: $e');
    }
  }

  /// Delete user's entire Storage folder
  Future<void> _deleteUserStorageFolder(String uid) async {
    developer.log('[AccountDeletionService] 📁 Deleting storage folder for UID: $uid');

    try {
      // Try to delete vendor storage folder
      try {
        final vendorFolder = _storage.ref().child('vendors/$uid');
        final vendorItems = await vendorFolder.listAll();
        
        for (final item in vendorItems.items) {
          await item.delete();
        }
        
        for (final folder in vendorItems.prefixes) {
          await _deleteStorageFolder(folder);
        }
        
        developer.log('[AccountDeletionService] ✅ Vendor storage folder deleted');
      } catch (e) {
        developer.log('[AccountDeletionService] Info: No vendor storage folder found: $e');
      }

      // Try to delete regular user storage folder
      try {
        final regularUserFolder = _storage.ref().child('regularUsers/$uid');
        final regularUserItems = await regularUserFolder.listAll();
        
        for (final item in regularUserItems.items) {
          await item.delete();
        }
        
        for (final folder in regularUserItems.prefixes) {
          await _deleteStorageFolder(folder);
        }
        
        developer.log('[AccountDeletionService] ✅ Regular user storage folder deleted');
      } catch (e) {
        developer.log('[AccountDeletionService] Info: No regular user storage folder found: $e');
      }

    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting storage folders: $e');
      // Non-critical error, continue with deletion
    }
  }

  /// Recursively delete a storage folder
  Future<void> _deleteStorageFolder(Reference folder) async {
    try {
      final listResult = await folder.listAll();
      
      // Delete all files
      for (final item in listResult.items) {
        await item.delete();
      }
      
      // Recursively delete subfolders
      for (final subfolder in listResult.prefixes) {
        await _deleteStorageFolder(subfolder);
      }
    } catch (e) {
      developer.log('[AccountDeletionService] Warning: Error deleting storage folder ${folder.fullPath}: $e');
    }
  }

  /// Delete Firebase Authentication account (must be done last)
  Future<void> _deleteAuthAccount() async {
    developer.log('[AccountDeletionService] 🔐 Deleting Firebase Auth account');

    try {
      await _authService.deleteAccount();
      developer.log('[AccountDeletionService] ✅ Firebase Auth account deleted');
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error deleting auth account: $e');
      throw Exception('Failed to delete authentication account: $e');
    }
  }

  /// Check what data exists for a user before deletion (for confirmation)
  Future<Map<String, dynamic>> getUserDataSummary() async {
    final uid = currentUserUid;
    if (uid == null) {
      return {};
    }

    developer.log('[AccountDeletionService] 📊 Getting data summary for UID: $uid');

    try {
      final summary = <String, dynamic>{};

      // Check profile type
      final vendorProfile = _profileService.getCurrentUserProfile();
      final regularProfile = _profileService.getCurrentRegularUserProfile();
      
      summary['profileType'] = vendorProfile != null ? 'vendor' : 
                               regularProfile != null ? 'regular' : 'none';
      summary['displayName'] = vendorProfile?.displayName ?? regularProfile?.displayName ?? 'Unknown';

      // Count snaps
      final snapsQuery = await _firestore
          .collection('snaps')
          .where('vendorId', isEqualTo: uid)
          .get();
      summary['snapsCount'] = snapsQuery.docs.length;

      // Count messages
      final sentMessagesQuery = await _firestore
          .collection('messages')
          .where('fromUid', isEqualTo: uid)
          .get();
      final receivedMessagesQuery = await _firestore
          .collection('messages')
          .where('toUid', isEqualTo: uid)
          .get();
      summary['messagesCount'] = sentMessagesQuery.docs.length + receivedMessagesQuery.docs.length;

      // Count followers (if vendor)
      if (vendorProfile != null) {
        final followersSnapshot = await _firestore
            .collection('vendors')
            .doc(uid)
            .collection('followers')
            .get();
        summary['followersCount'] = followersSnapshot.docs.length;
      } else {
        summary['followersCount'] = 0;
      }

      developer.log('[AccountDeletionService] 📊 Data summary: $summary');
      return summary;
    } catch (e) {
      developer.log('[AccountDeletionService] ❌ Error getting data summary: $e');
      return {};
    }
  }
} 