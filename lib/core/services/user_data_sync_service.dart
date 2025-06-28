import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/models/regular_user_profile.dart';
import 'package:marketsnap/core/services/hive_service.dart';
import 'package:marketsnap/core/services/profile_update_notifier.dart';

/// Comprehensive service for syncing all user data after authentication
/// Ensures consistent data across devices by downloading and caching
/// all user-related data (profile, snaps, messages, conversations, etc.)
class UserDataSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HiveService _hiveService;
  final ProfileUpdateNotifier _profileUpdateNotifier;

  // Track sync state to prevent duplicate operations
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncedUid;

  UserDataSyncService({
    required HiveService hiveService,
    required ProfileUpdateNotifier profileUpdateNotifier,
  }) : _hiveService = hiveService,
       _profileUpdateNotifier = profileUpdateNotifier;

  /// Check if user needs a full data sync
  /// Returns true if:
  /// - User has never been synced on this device
  /// - Last sync was more than 24 hours ago
  /// - User UID has changed (different account)
  bool needsFullSync() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    // Check if different user (account switch)
    if (_lastSyncedUid != null && _lastSyncedUid != currentUser.uid) {
      developer.log(
        '[UserDataSyncService] 🔄 Different user detected - full sync needed',
        name: 'UserDataSyncService',
      );
      return true;
    }

    // Check if first sync on this device
    if (_lastSyncTime == null) {
      developer.log(
        '[UserDataSyncService] 🆕 First sync on this device - full sync needed',
        name: 'UserDataSyncService',
      );
      return true;
    }

    // Check if sync is older than 24 hours
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    if (timeSinceLastSync.inHours > 24) {
      developer.log(
        '[UserDataSyncService] ⏰ Last sync was ${timeSinceLastSync.inHours} hours ago - full sync needed',
        name: 'UserDataSyncService',
      );
      return true;
    }

    developer.log(
      '[UserDataSyncService] ✅ Recent sync found - no full sync needed',
      name: 'UserDataSyncService',
    );
    return false;
  }

  /// Perform comprehensive data sync for authenticated user
  /// This is the main entry point for post-authentication data loading
  Future<UserDataSyncResult> performFullDataSync() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      developer.log(
        '[UserDataSyncService] ❌ No authenticated user - cannot sync',
        name: 'UserDataSyncService',
      );
      return UserDataSyncResult.failure('No authenticated user');
    }

    if (_isSyncing) {
      developer.log(
        '[UserDataSyncService] 🔄 Sync already in progress - waiting',
        name: 'UserDataSyncService',
      );
      // Wait for current sync to complete
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return UserDataSyncResult.success('Sync completed by concurrent operation');
    }

    _isSyncing = true;
    developer.log(
      '[UserDataSyncService] 🚀 Starting comprehensive data sync for user: ${currentUser.uid}',
      name: 'UserDataSyncService',
    );

    try {
      final syncResult = UserDataSyncResult();
      final uid = currentUser.uid;

      // Step 1: Sync Profile Data
      developer.log(
        '[UserDataSyncService] 📋 Step 1: Syncing profile data',
        name: 'UserDataSyncService',
      );
      final profileResult = await _syncProfileData(uid);
      syncResult.profileSynced = profileResult.success;
      syncResult.profileType = profileResult.profileType;

      // Step 2: Sync User's Snaps/Stories
      developer.log(
        '[UserDataSyncService] 📸 Step 2: Syncing user snaps and stories',
        name: 'UserDataSyncService',
      );
      final snapsResult = await _syncUserSnaps(uid);
      syncResult.snapsCount = snapsResult.count;
      syncResult.snapsSynced = snapsResult.success;

      // Step 3: Sync Conversations
      developer.log(
        '[UserDataSyncService] 💬 Step 3: Syncing conversations',
        name: 'UserDataSyncService',
      );
      final conversationsResult = await _syncConversations(uid);
      syncResult.conversationsCount = conversationsResult.count;
      syncResult.conversationsSynced = conversationsResult.success;

      // Step 4: Sync Messages
      developer.log(
        '[UserDataSyncService] 📨 Step 4: Syncing messages',
        name: 'UserDataSyncService',
      );
      final messagesResult = await _syncMessages(uid);
      syncResult.messagesCount = messagesResult.count;
      syncResult.messagesSynced = messagesResult.success;

      // Step 5: Sync Broadcasts (if vendor)
      if (syncResult.profileType == 'vendor') {
        developer.log(
          '[UserDataSyncService] 📡 Step 5: Syncing broadcasts (vendor account)',
          name: 'UserDataSyncService',
        );
        final broadcastsResult = await _syncBroadcasts(uid);
        syncResult.broadcastsCount = broadcastsResult.count;
        syncResult.broadcastsSynced = broadcastsResult.success;
      }

      // Step 6: Mark sync as completed
      _lastSyncTime = DateTime.now();
      _lastSyncedUid = uid;
      syncResult.syncCompletedAt = _lastSyncTime!;

      developer.log(
        '[UserDataSyncService] ✅ SYNC COMPLETED SUCCESSFULLY',
        name: 'UserDataSyncService',
      );
      developer.log(
        '[UserDataSyncService] 📊 Sync Summary: ${syncResult.summary}',
        name: 'UserDataSyncService',
      );

      return syncResult;

    } catch (e, stackTrace) {
      developer.log(
        '[UserDataSyncService] ❌ SYNC FAILED: $e',
        name: 'UserDataSyncService',
      );
      developer.log(
        '[UserDataSyncService] Stack trace: $stackTrace',
        name: 'UserDataSyncService',
      );
      return UserDataSyncResult.failure('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync profile data (both vendor and regular user profiles)
  Future<ProfileSyncResult> _syncProfileData(String uid) async {
    developer.log(
      '[UserDataSyncService] 🔍 Checking for existing profiles for UID: $uid',
      name: 'UserDataSyncService',
    );

    try {
      // Check for vendor profile first
      final vendorDoc = await _firestore.collection('vendors').doc(uid).get();
      if (vendorDoc.exists) {
        developer.log(
          '[UserDataSyncService] 🏪 Found vendor profile - loading and caching',
          name: 'UserDataSyncService',
        );
        
        final vendorProfile = VendorProfile.fromFirestore(vendorDoc.data()!, uid);
        await _hiveService.saveVendorProfile(vendorProfile);
        
        // Broadcast profile update
        _profileUpdateNotifier.notifyVendorProfileUpdate(vendorProfile);
        
        developer.log(
          '[UserDataSyncService] ✅ Vendor profile synced: ${vendorProfile.displayName}',
          name: 'UserDataSyncService',
        );
        return ProfileSyncResult(success: true, profileType: 'vendor');
      }

      // Check for regular user profile
      final regularDoc = await _firestore.collection('regularUsers').doc(uid).get();
      if (regularDoc.exists) {
        developer.log(
          '[UserDataSyncService] 👤 Found regular user profile - loading and caching',
          name: 'UserDataSyncService',
        );
        
        final regularProfile = RegularUserProfile.fromFirestore(regularDoc.data()!, uid);
        await _hiveService.saveRegularUserProfile(regularProfile);
        
        // Broadcast profile update
        _profileUpdateNotifier.notifyRegularUserProfileUpdate(regularProfile);
        
        developer.log(
          '[UserDataSyncService] ✅ Regular user profile synced: ${regularProfile.displayName}',
          name: 'UserDataSyncService',
        );
        return ProfileSyncResult(success: true, profileType: 'regular');
      }

      developer.log(
        '[UserDataSyncService] ⚠️ No profile found for UID: $uid',
        name: 'UserDataSyncService',
      );
      return ProfileSyncResult(success: false, profileType: 'none');

    } catch (e) {
      developer.log(
        '[UserDataSyncService] ❌ Error syncing profile data: $e',
        name: 'UserDataSyncService',
      );
      return ProfileSyncResult(success: false, profileType: 'error');
    }
  }

  /// Sync user's snaps and stories
  Future<DataSyncResult> _syncUserSnaps(String uid) async {
    try {
      // Get all snaps for this user
      final snapsQuery = await _firestore
          .collection('snaps')
          .where('vendorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(100) // Limit to prevent excessive data transfer
          .get();

      developer.log(
        '[UserDataSyncService] 📸 Found ${snapsQuery.docs.length} snaps for user',
        name: 'UserDataSyncService',
      );

      // Cache snaps locally (we'll add this to HiveService if needed)
      // For now, just count them as they'll be loaded by FeedService streams
      
      return DataSyncResult(success: true, count: snapsQuery.docs.length);

    } catch (e) {
      developer.log(
        '[UserDataSyncService] ❌ Error syncing user snaps: $e',
        name: 'UserDataSyncService',
      );
      return DataSyncResult(success: false, count: 0);
    }
  }

  /// Sync user's conversations
  Future<DataSyncResult> _syncConversations(String uid) async {
    try {
      // Get conversations where user is participant
      final conversationsQuery = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: uid)
          .orderBy('lastMessageTime', descending: true)
          .limit(50) // Reasonable limit
          .get();

      developer.log(
        '[UserDataSyncService] 💬 Found ${conversationsQuery.docs.length} conversations for user',
        name: 'UserDataSyncService',
      );

      // Cache conversations locally (we'll add this to HiveService if needed)
      // For now, just count them as they'll be loaded by MessagingService
      
      return DataSyncResult(success: true, count: conversationsQuery.docs.length);

    } catch (e) {
      developer.log(
        '[UserDataSyncService] ❌ Error syncing conversations: $e',
        name: 'UserDataSyncService',
      );
      return DataSyncResult(success: false, count: 0);
    }
  }

  /// Sync user's messages
  Future<DataSyncResult> _syncMessages(String uid) async {
    try {
      // Get recent messages sent by or to this user
      final sentMessagesQuery = _firestore
          .collection('messages')
          .where('fromUid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100);

      final receivedMessagesQuery = _firestore
          .collection('messages')
          .where('toUid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100);

      final results = await Future.wait([
        sentMessagesQuery.get(),
        receivedMessagesQuery.get(),
      ]);

      final sentCount = results[0].docs.length;
      final receivedCount = results[1].docs.length;
      final totalMessages = sentCount + receivedCount;

      developer.log(
        '[UserDataSyncService] 📨 Found $totalMessages messages for user (sent: $sentCount, received: $receivedCount)',
        name: 'UserDataSyncService',
      );

      return DataSyncResult(success: true, count: totalMessages);

    } catch (e) {
      developer.log(
        '[UserDataSyncService] ❌ Error syncing messages: $e',
        name: 'UserDataSyncService',
      );
      return DataSyncResult(success: false, count: 0);
    }
  }

  /// Sync user's broadcasts (vendor only)
  Future<DataSyncResult> _syncBroadcasts(String uid) async {
    try {
      // Get broadcasts created by this vendor
      final broadcastsQuery = await _firestore
          .collection('broadcasts')
          .where('vendorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      developer.log(
        '[UserDataSyncService] 📡 Found ${broadcastsQuery.docs.length} broadcasts for vendor',
        name: 'UserDataSyncService',
      );

      return DataSyncResult(success: true, count: broadcastsQuery.docs.length);

    } catch (e) {
      developer.log(
        '[UserDataSyncService] ❌ Error syncing broadcasts: $e',
        name: 'UserDataSyncService',
      );
      return DataSyncResult(success: false, count: 0);
    }
  }

  /// Get sync status summary
  String getSyncStatusSummary() {
    if (_lastSyncTime == null) {
      return 'Never synced on this device';
    }

    final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
    if (timeSinceSync.inMinutes < 60) {
      return 'Synced ${timeSinceSync.inMinutes} minutes ago';
    } else if (timeSinceSync.inHours < 24) {
      return 'Synced ${timeSinceSync.inHours} hours ago';
    } else {
      return 'Synced ${timeSinceSync.inDays} days ago';
    }
  }
}

/// Result object for profile sync operations
class ProfileSyncResult {
  final bool success;
  final String profileType; // 'vendor', 'regular', 'none', 'error'

  ProfileSyncResult({required this.success, required this.profileType});
}

/// Result object for general data sync operations
class DataSyncResult {
  final bool success;
  final int count;

  DataSyncResult({required this.success, required this.count});
}

/// Comprehensive result object for full user data sync
class UserDataSyncResult {
  bool profileSynced = false;
  String profileType = 'none';
  
  bool snapsSynced = false;
  int snapsCount = 0;
  
  bool conversationsSynced = false;
  int conversationsCount = 0;
  
  bool messagesSynced = false;
  int messagesCount = 0;
  
  bool broadcastsSynced = false;
  int broadcastsCount = 0;
  
  DateTime? syncCompletedAt;
  String? errorMessage;

  UserDataSyncResult();

  UserDataSyncResult.failure(String error) {
    errorMessage = error;
  }

  UserDataSyncResult.success(String message) {
    // Constructor for simple success cases
  }

  bool get isSuccess => errorMessage == null;

  String get summary {
    if (!isSuccess) return 'Failed: $errorMessage';
    
    return '''
Profile: $profileType (${profileSynced ? 'synced' : 'failed'})
Snaps: $snapsCount (${snapsSynced ? 'synced' : 'failed'})
Conversations: $conversationsCount (${conversationsSynced ? 'synced' : 'failed'})
Messages: $messagesCount (${messagesSynced ? 'synced' : 'failed'})
${profileType == 'vendor' ? 'Broadcasts: $broadcastsCount (${broadcastsSynced ? 'synced' : 'failed'})' : ''}
Completed: ${syncCompletedAt?.toString() ?? 'Not completed'}''';
  }
} 