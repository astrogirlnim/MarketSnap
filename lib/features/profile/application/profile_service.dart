import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/vendor_profile.dart';
import '../../../core/models/regular_user_profile.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/profile_update_notifier.dart';
import '../../../main.dart' as main;

/// Service for managing vendor profiles with offline-first capabilities.
/// Handles profile CRUD operations, avatar uploads, and Firebase sync.
class ProfileService {
  final HiveService _hiveService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _imagePicker;
  final ProfileUpdateNotifier _profileUpdateNotifier;

  ProfileService({
    required HiveService hiveService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? imagePicker,
    ProfileUpdateNotifier? profileUpdateNotifier,
  }) : _hiveService = hiveService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _imagePicker = imagePicker ?? ImagePicker(),
       _profileUpdateNotifier =
           profileUpdateNotifier ?? ProfileUpdateNotifier();

  /// Gets the current user's UID
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Gets the current user's vendor profile from local storage
  VendorProfile? getCurrentUserProfile() {
    final uid = currentUserUid;
    if (uid == null) {
      debugPrint('[ProfileService] No authenticated user found');
      return null;
    }
    return _hiveService.getVendorProfile(uid);
  }

  /// Creates or updates a vendor profile locally
  Future<void> saveProfile({
    required String displayName,
    required String stallName,
    required String marketCity,
    bool allowLocation = false,
    String? localAvatarPath,
  }) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to save profile');
    }

    debugPrint('[ProfileService] 🔄 Starting profile save for user: $uid');
    debugPrint('[ProfileService] Profile data: $stallName in $marketCity');
    debugPrint('[ProfileService] 🖼️ Avatar handling:');
    debugPrint('[ProfileService] - localAvatarPath parameter: $localAvatarPath');

    // Get existing profile to understand current avatar state
    final existingProfile = _hiveService.getVendorProfile(uid);
    debugPrint('[ProfileService] 📋 Existing profile analysis:');
    debugPrint('[ProfileService] - Existing profile found: ${existingProfile != null}');
    debugPrint('[ProfileService] - Existing avatarURL: ${existingProfile?.avatarURL}');
    debugPrint('[ProfileService] - Existing localAvatarPath: ${existingProfile?.localAvatarPath}');
    
    // ✅ CRITICAL FIX: Smart avatar state management
    String? avatarURL;
    String? finalLocalAvatarPath;
    
    if (localAvatarPath != null) {
      // User selected a new avatar - use it and clear existing URL
      debugPrint('[ProfileService] 🆕 New avatar selected - will upload after save');
      finalLocalAvatarPath = localAvatarPath;
      avatarURL = null; // Clear existing URL since we have new local image
    } else if (existingProfile?.avatarURL != null) {
      // No new avatar, preserve existing remote URL
      debugPrint('[ProfileService] 🔄 No new avatar - preserving existing remote URL');
      avatarURL = existingProfile!.avatarURL;
      finalLocalAvatarPath = null; // Clear local path since we have remote URL
    } else {
      // No avatar at all
      debugPrint('[ProfileService] ℹ️ No avatar data available');
      avatarURL = null;
      finalLocalAvatarPath = null;
    }

    final profile = VendorProfile(
      uid: uid,
      displayName: displayName.trim(),
      stallName: stallName.trim(),
      marketCity: marketCity.trim(),
      allowLocation: allowLocation,
      localAvatarPath: finalLocalAvatarPath,
      avatarURL: avatarURL,
      needsSync: true, // Always mark for sync when saving
      lastUpdated: DateTime.now(),
    );

    debugPrint('[ProfileService] 📦 Final profile state before save:');
    debugPrint('[ProfileService] - localAvatarPath: ${profile.localAvatarPath}');
    debugPrint('[ProfileService] - avatarURL: ${profile.avatarURL}');
    debugPrint('[ProfileService] - needsSync: ${profile.needsSync}');

    // Save locally first (offline-first approach)
    await _hiveService.saveVendorProfile(profile);
    debugPrint('[ProfileService] ✅ Profile saved to local storage successfully');

    // 📢 Broadcast immediate profile update
    _profileUpdateNotifier.notifyVendorProfileUpdate(profile);
    debugPrint('[ProfileService] 📢 Profile update broadcasted for: ${profile.displayName}');

    // ✅ CRITICAL FIX: Attempt sync with comprehensive error handling and retry
    try {
      await _syncProfileWithRetry(uid);
    } catch (e) {
      debugPrint('[ProfileService] ⚠️ Initial sync failed but profile saved locally: $e');
      // Don't throw - offline-first means local save succeeds even if sync fails
    }

    // Also try to save FCM token now that profile exists
    _attemptFCMTokenSave();
  }

  /// ✅ NEW METHOD: Sync profile with retry logic and comprehensive avatar handling
  Future<void> _syncProfileWithRetry(String uid, {int maxRetries = 3}) async {
    debugPrint('[ProfileService] 🔄 Starting sync with retry for UID: $uid');
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[ProfileService] 🔄 Sync attempt $attempt/$maxRetries');
        
        final success = await _performProfileSync(uid);
        if (success) {
          debugPrint('[ProfileService] ✅ Profile sync completed successfully on attempt $attempt');
          return;
        } else {
          debugPrint('[ProfileService] ❌ Profile sync failed on attempt $attempt');
        }
      } catch (e) {
        debugPrint('[ProfileService] ❌ Sync attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          debugPrint('[ProfileService] 🚨 All sync attempts failed - giving up');
          rethrow;
        } else {
          // Wait before retry with exponential backoff
          final waitTime = Duration(seconds: attempt * 2);
          debugPrint('[ProfileService] ⏳ Waiting ${waitTime.inSeconds}s before retry...');
          await Future.delayed(waitTime);
        }
      }
    }
  }

  /// ✅ NEW METHOD: Perform actual profile sync with comprehensive avatar upload handling
  Future<bool> _performProfileSync(String uid) async {
    debugPrint('[ProfileService] 🔄 Performing profile sync for UID: $uid');

    final profile = _hiveService.getVendorProfile(uid);
    if (profile == null) {
      debugPrint('[ProfileService] ❌ No profile found locally for UID: $uid');
      return false;
    }

    if (!profile.needsSync) {
      debugPrint('[ProfileService] ✅ Profile already synced for UID: $uid');
      return true;
    }

    debugPrint('[ProfileService] 🖼️ Avatar sync analysis:');
    debugPrint('[ProfileService] - localAvatarPath: ${profile.localAvatarPath}');
    debugPrint('[ProfileService] - avatarURL: ${profile.avatarURL}');

    // Handle avatar upload if needed
    String? finalAvatarURL = profile.avatarURL;
    
    if (profile.localAvatarPath != null) {
      debugPrint('[ProfileService] 📤 Uploading local avatar to Firebase Storage...');
      try {
        finalAvatarURL = await uploadAvatar(profile.localAvatarPath!);
        debugPrint('[ProfileService] ✅ Avatar uploaded successfully: $finalAvatarURL');
      } catch (e) {
        debugPrint('[ProfileService] ❌ Avatar upload failed: $e');
        throw Exception('Avatar upload failed: $e');
      }
    }

    // Create final profile for Firestore with updated avatar URL
    final profileToSync = profile.copyWith(
      avatarURL: finalAvatarURL,
      localAvatarPath: null, // Clear local path after successful upload
      needsSync: false, // Mark as synced
    );

    debugPrint('[ProfileService] 📤 Syncing profile to Firestore...');
    debugPrint('[ProfileService] - Final avatarURL: ${profileToSync.avatarURL}');

    // Write to Firestore
    await _firestore
        .collection('vendors')
        .doc(uid)
        .set(profileToSync.toFirestore())
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Firestore write timed out after 15 seconds'),
        );

    debugPrint('[ProfileService] ✅ Firestore write completed successfully');

    // Update local storage with synced profile
    await _hiveService.saveVendorProfile(profileToSync);
    debugPrint('[ProfileService] ✅ Local profile updated with sync results');

    // 📢 Broadcast final profile update with correct avatar URL
    _profileUpdateNotifier.notifyVendorProfileUpdate(profileToSync);
    debugPrint('[ProfileService] 📢 Final profile update broadcasted after sync');

    return true;
  }

  /// Attempts to sync profile immediately without blocking the UI
  void _attemptImmediateSync(String uid) {
    debugPrint('[ProfileService] Attempting immediate sync for UID: $uid');

    syncProfileToFirestore(uid)
        .timeout(
          const Duration(seconds: 5), // 5 second timeout
          onTimeout: () {
            debugPrint(
              '[ProfileService] Sync timed out after 5 seconds - will retry later',
            );
            return;
          },
        )
        .catchError((error) {
          debugPrint('[ProfileService] Immediate sync failed: $error');
          // Don't throw - offline-first means we save locally and sync when possible
        });
  }

  /// Attempts to save FCM token after profile creation
  void _attemptFCMTokenSave() {
    debugPrint('[ProfileService] Attempting to save pending FCM token');

    // Try to get and save FCM token - this is async but we don't block on it
    _getFCMTokenAndSave().catchError((error) {
      debugPrint('[ProfileService] FCM token save failed: $error');
      // Don't throw - not critical for profile creation flow
    });
  }

  /// Gets FCM token from push notification service and saves it
  Future<void> _getFCMTokenAndSave() async {
    try {
      // Import the push notification service from main
      final pushNotificationService = main.pushNotificationService;
      final token = await pushNotificationService.getFCMToken();

      if (token != null) {
        debugPrint('[ProfileService] Got FCM token, saving to profile');
        await saveFCMToken(token);
      } else {
        debugPrint('[ProfileService] No FCM token available');
      }
    } catch (e) {
      debugPrint('[ProfileService] Error getting/saving FCM token: $e');
    }
  }

  /// Picks an image from gallery or camera for avatar
  Future<String?> pickAvatarImage({bool fromCamera = false}) async {
    debugPrint(
      '[ProfileService] Picking avatar image from ${fromCamera ? 'camera' : 'gallery'}',
    );

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512, // Reasonable size for avatars
        maxHeight: 512,
        imageQuality: 85, // Good quality but not too large
      );

      if (image != null) {
        debugPrint('[ProfileService] Avatar image selected: ${image.path}');
        return image.path;
      } else {
        debugPrint('[ProfileService] No image selected');
        return null;
      }
    } catch (e) {
      debugPrint('[ProfileService] Error picking avatar image: $e');
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Uploads avatar to Firebase Storage and returns the download URL
  Future<String?> uploadAvatar(String localPath) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to upload avatar');
    }

    debugPrint('[ProfileService] 📤 Starting avatar upload for user: $uid');
    debugPrint('[ProfileService] - Local file path: $localPath');

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Avatar file does not exist: $localPath');
      }

      // Check file size for reasonable limits
      final fileSize = await file.length();
      debugPrint('[ProfileService] - File size: ${fileSize} bytes');
      
      if (fileSize > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Avatar file too large (${fileSize} bytes). Maximum size is 5MB.');
      }

      // Create a reference to the avatar location
      final ref = _storage.ref().child('vendors/$uid/avatar.jpg');

      // Upload the file with metadata
      debugPrint('[ProfileService] 📤 Uploading to Firebase Storage...');
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'uploadedBy': uid,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[ProfileService] ✅ Avatar uploaded successfully');
      debugPrint('[ProfileService] - Download URL: $downloadUrl');
      debugPrint('[ProfileService] - Storage path: vendors/$uid/avatar.jpg');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[ProfileService] ❌ Avatar upload failed: $e');
      throw Exception('Failed to upload avatar: $e');
    }
  }

  /// ✅ UPDATED METHOD: Wait for sync completion with proper result handling
  Future<bool> waitForSyncCompletion(String uid, {Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('[ProfileService] ⏳ Waiting for sync completion for UID: $uid');
    
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      final profile = _hiveService.getVendorProfile(uid);
      
      if (profile == null) {
        debugPrint('[ProfileService] ❌ Profile not found during sync wait');
        return false;
      }
      
      if (!profile.needsSync) {
        debugPrint('[ProfileService] ✅ Sync completed in ${stopwatch.elapsed.inMilliseconds}ms');
        return true;
      }
      
      // Check every 100ms
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    debugPrint('[ProfileService] ⏰ Sync wait timed out after ${timeout.inSeconds}s');
    return false;
  }

  /// ✅ UPDATED METHOD: Legacy sync method - now delegates to new implementation
  Future<void> syncProfileToFirestore(String uid) async {
    debugPrint('[ProfileService] 🔄 Legacy syncProfileToFirestore called - delegating to new implementation');
    await _performProfileSync(uid);
  }

  /// Loads vendor profile from Firestore and caches locally
  Future<VendorProfile?> loadProfileFromFirestore(String uid) async {
    debugPrint('[ProfileService] Loading profile from Firestore for UID: $uid');

    try {
      final doc = await _firestore.collection('vendors').doc(uid).get();

      if (!doc.exists) {
        debugPrint(
          '[ProfileService] No profile found in Firestore for UID: $uid',
        );
        return null;
      }

      final data = doc.data()!;
      final profile = VendorProfile.fromFirestore(data, uid);

      // Cache locally
      await _hiveService.saveVendorProfile(profile);

      debugPrint('[ProfileService] Profile loaded and cached successfully');
      return profile;
    } catch (e) {
      debugPrint('[ProfileService] Error loading profile from Firestore: $e');
      throw Exception('Failed to load profile: $e');
    }
  }

  /// Syncs all profiles that need syncing
  Future<void> syncAllPendingProfiles() async {
    debugPrint('[ProfileService] Syncing all pending profiles');

    final profilesNeedingSync = _hiveService.getProfilesNeedingSync();
    debugPrint(
      '[ProfileService] Found ${profilesNeedingSync.length} profiles to sync',
    );

    for (final profile in profilesNeedingSync) {
      try {
        await _performProfileSync(profile.uid);
      } catch (e) {
        debugPrint(
          '[ProfileService] Failed to sync profile ${profile.uid}: $e',
        );
        // Continue with other profiles
      }
    }

    debugPrint('[ProfileService] Finished syncing pending profiles');
  }

  /// Checks if the current user has a complete profile
  bool hasCompleteProfile() {
    final uid = currentUserUid;
    if (uid == null) return false;
    return _hiveService.hasCompleteVendorProfile(uid);
  }

  /// Deletes the current user's profile
  Future<void> deleteCurrentUserProfile() async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to delete profile');
    }

    debugPrint('[ProfileService] Deleting profile for user: $uid');

    try {
      // Delete from Firestore
      await _firestore.collection('vendors').doc(uid).delete();

      // Delete avatar from Storage
      try {
        await _storage.ref().child('vendors/$uid/avatar.jpg').delete();
      } catch (e) {
        debugPrint(
          '[ProfileService] Avatar deletion failed (may not exist): $e',
        );
      }

      // Delete from local storage
      await _hiveService.deleteVendorProfile(uid);

      // 📢 Broadcast profile deletion to all listeners
      _profileUpdateNotifier.notifyProfileDelete(uid);
      debugPrint(
        '[ProfileService] 📢 Profile deletion broadcasted for UID: $uid',
      );

      debugPrint('[ProfileService] Profile deleted successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error deleting profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
  }

  /// Gets the current user's regular user profile from local storage
  RegularUserProfile? getCurrentRegularUserProfile() {
    final uid = currentUserUid;
    if (uid == null) {
      debugPrint('[ProfileService] No authenticated user found');
      return null;
    }
    return _hiveService.getRegularUserProfile(uid);
  }

  /// ✅ UPDATED METHOD: Creates or updates a regular user profile with improved avatar handling
  Future<void> saveRegularUserProfile({
    required String displayName,
    String? localAvatarPath,
  }) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to save profile');
    }

    debugPrint('[ProfileService] 🔄 Starting regular user profile save for UID: $uid');
    debugPrint('[ProfileService] 🖼️ Avatar handling:');
    debugPrint('[ProfileService] - localAvatarPath parameter: $localAvatarPath');

    try {
      // Get current user's contact info from auth
      final user = _auth.currentUser;
      final phoneNumber = user?.phoneNumber;
      final email = user?.email;

      // Get existing profile to understand current avatar state
      final existingProfile = _hiveService.getRegularUserProfile(uid);
      debugPrint('[ProfileService] 📋 Existing regular user profile analysis:');
      debugPrint('[ProfileService] - Existing profile found: ${existingProfile != null}');
      debugPrint('[ProfileService] - Existing avatarURL: ${existingProfile?.avatarURL}');
      debugPrint('[ProfileService] - Existing localAvatarPath: ${existingProfile?.localAvatarPath}');
      
      // ✅ CRITICAL FIX: Smart avatar state management for regular users
      String? avatarURL;
      String? finalLocalAvatarPath;
      
      if (localAvatarPath != null) {
        // User selected a new avatar - use it and clear existing URL
        debugPrint('[ProfileService] 🆕 New avatar selected - will upload after save');
        finalLocalAvatarPath = localAvatarPath;
        avatarURL = null; // Clear existing URL since we have new local image
      } else if (existingProfile?.avatarURL != null) {
        // No new avatar, preserve existing remote URL
        debugPrint('[ProfileService] 🔄 No new avatar - preserving existing remote URL');
        avatarURL = existingProfile!.avatarURL;
        finalLocalAvatarPath = null; // Clear local path since we have remote URL
      } else {
        // No avatar at all
        debugPrint('[ProfileService] ℹ️ No avatar data available');
        avatarURL = null;
        finalLocalAvatarPath = null;
      }

      final profile = RegularUserProfile(
        uid: uid,
        displayName: displayName.trim(),
        localAvatarPath: finalLocalAvatarPath,
        phoneNumber: phoneNumber,
        email: email,
        avatarURL: avatarURL,
        needsSync: true, // Always mark for sync when saving
      );

      debugPrint('[ProfileService] 📦 Final regular user profile state before save:');
      debugPrint('[ProfileService] - localAvatarPath: ${profile.localAvatarPath}');
      debugPrint('[ProfileService] - avatarURL: ${profile.avatarURL}');
      debugPrint('[ProfileService] - needsSync: ${profile.needsSync}');

      // Save locally first (offline-first approach)
      await _hiveService.saveRegularUserProfile(profile);
      debugPrint('[ProfileService] ✅ Regular user profile saved to local storage successfully');

      // 📢 Broadcast immediate profile update
      _profileUpdateNotifier.notifyRegularUserProfileUpdate(profile);
      debugPrint('[ProfileService] 📢 Regular user profile update broadcasted for: ${profile.displayName}');

      // ✅ CRITICAL FIX: Attempt sync with comprehensive error handling and retry
      try {
        await _syncRegularUserProfileWithRetry(uid);
      } catch (e) {
        debugPrint('[ProfileService] ⚠️ Initial sync failed but regular user profile saved locally: $e');
        // Don't throw - offline-first means local save succeeds even if sync fails
      }

      // Also try to save FCM token now that profile exists
      _attemptFCMTokenSave();
    } catch (e) {
      debugPrint('[ProfileService] Error saving regular user profile: $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  /// ✅ NEW METHOD: Sync regular user profile with retry logic and comprehensive avatar handling
  Future<void> _syncRegularUserProfileWithRetry(String uid, {int maxRetries = 3}) async {
    debugPrint('[ProfileService] 🔄 Starting regular user profile sync with retry for UID: $uid');
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[ProfileService] 🔄 Regular user profile sync attempt $attempt/$maxRetries');
        
        final success = await _performRegularUserProfileSync(uid);
        if (success) {
          debugPrint('[ProfileService] ✅ Regular user profile sync completed successfully on attempt $attempt');
          return;
        } else {
          debugPrint('[ProfileService] ❌ Regular user profile sync failed on attempt $attempt');
        }
      } catch (e) {
        debugPrint('[ProfileService] ❌ Regular user profile sync attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          debugPrint('[ProfileService] 🚨 All regular user profile sync attempts failed - giving up');
          rethrow;
        } else {
          // Wait before retry with exponential backoff
          final waitTime = Duration(seconds: attempt * 2);
          debugPrint('[ProfileService] ⏳ Waiting ${waitTime.inSeconds}s before retry...');
          await Future.delayed(waitTime);
        }
      }
    }
  }

  /// ✅ NEW METHOD: Perform actual regular user profile sync with comprehensive avatar upload handling
  Future<bool> _performRegularUserProfileSync(String uid) async {
    debugPrint('[ProfileService] 🔄 Performing regular user profile sync for UID: $uid');

    final profile = _hiveService.getRegularUserProfile(uid);
    if (profile == null) {
      debugPrint('[ProfileService] ❌ No regular user profile found locally for UID: $uid');
      return false;
    }

    if (!profile.needsSync) {
      debugPrint('[ProfileService] ✅ Regular user profile already synced for UID: $uid');
      return true;
    }

    debugPrint('[ProfileService] 🖼️ Regular user avatar sync analysis:');
    debugPrint('[ProfileService] - localAvatarPath: ${profile.localAvatarPath}');
    debugPrint('[ProfileService] - avatarURL: ${profile.avatarURL}');

    // Handle avatar upload if needed
    String? finalAvatarURL = profile.avatarURL;
    
    if (profile.localAvatarPath != null) {
      debugPrint('[ProfileService] 📤 Uploading regular user local avatar to Firebase Storage...');
      try {
        // Use different storage path for regular users
        finalAvatarURL = await _uploadRegularUserAvatar(profile.localAvatarPath!, uid);
        debugPrint('[ProfileService] ✅ Regular user avatar uploaded successfully: $finalAvatarURL');
      } catch (e) {
        debugPrint('[ProfileService] ❌ Regular user avatar upload failed: $e');
        throw Exception('Regular user avatar upload failed: $e');
      }
    }

    // Create final profile for Firestore with updated avatar URL
    final profileToSync = profile.copyWith(
      avatarURL: finalAvatarURL,
      localAvatarPath: null, // Clear local path after successful upload
      needsSync: false, // Mark as synced
    );

    debugPrint('[ProfileService] 📤 Syncing regular user profile to Firestore...');
    debugPrint('[ProfileService] - Final avatarURL: ${profileToSync.avatarURL}');

    // Write to Firestore regular users collection
    await _firestore
        .collection('regularUsers')
        .doc(uid)
        .set(profileToSync.toFirestore())
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Firestore write timed out after 15 seconds'),
        );

    debugPrint('[ProfileService] ✅ Regular user profile Firestore write completed successfully');

    // Update local storage with synced profile
    await _hiveService.saveRegularUserProfile(profileToSync);
    debugPrint('[ProfileService] ✅ Local regular user profile updated with sync results');

    // 📢 Broadcast final profile update with correct avatar URL
    _profileUpdateNotifier.notifyRegularUserProfileUpdate(profileToSync);
    debugPrint('[ProfileService] 📢 Final regular user profile update broadcasted after sync');

    return true;
  }

  /// ✅ NEW METHOD: Upload regular user avatar with proper storage path
  Future<String?> _uploadRegularUserAvatar(String localPath, String uid) async {
    debugPrint('[ProfileService] 📤 Starting regular user avatar upload for UID: $uid');
    debugPrint('[ProfileService] - Local file path: $localPath');

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Regular user avatar file does not exist: $localPath');
      }

      // Check file size for reasonable limits
      final fileSize = await file.length();
      debugPrint('[ProfileService] - File size: ${fileSize} bytes');
      
      if (fileSize > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Regular user avatar file too large (${fileSize} bytes). Maximum size is 5MB.');
      }

      // Create a reference to the regular user avatar location
      final ref = _storage.ref().child('regularUsers/$uid/avatar.jpg');

      // Upload the file with metadata
      debugPrint('[ProfileService] 📤 Uploading regular user avatar to Firebase Storage...');
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'uploadedBy': uid,
            'userType': 'regular',
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[ProfileService] ✅ Regular user avatar uploaded successfully');
      debugPrint('[ProfileService] - Download URL: $downloadUrl');
      debugPrint('[ProfileService] - Storage path: regularUsers/$uid/avatar.jpg');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[ProfileService] ❌ Regular user avatar upload failed: $e');
      throw Exception('Failed to upload regular user avatar: $e');
    }
  }

  /// ✅ UPDATED METHOD: Legacy regular user sync method - now delegates to new implementation
  Future<void> syncRegularUserProfileToFirestore(String uid) async {
    debugPrint('[ProfileService] 🔄 Legacy syncRegularUserProfileToFirestore called - delegating to new implementation');
    await _performRegularUserProfileSync(uid);
  }

  /// Saves the FCM token to the user's profile in Firestore and locally
  Future<void> saveFCMToken(String token) async {
    final uid = currentUserUid;
    if (uid == null) return;

    debugPrint('[ProfileService] Saving FCM token for user $uid');
    try {
      // Check if user has vendor or regular user profile to determine collection
      final vendorProfile = getCurrentUserProfile();
      final regularProfile = getCurrentRegularUserProfile();

      if (vendorProfile != null) {
        // User is a vendor - save to vendors collection
        debugPrint('[ProfileService] Saving FCM token to vendors collection');
        await _firestore.collection('vendors').doc(uid).set(
          {'fcmToken': token},
          SetOptions(
            merge: true,
          ), // Use merge to avoid overwriting existing data
        );
      } else if (regularProfile != null) {
        // User is a regular user - save to regularUsers collection
        debugPrint(
          '[ProfileService] Saving FCM token to regularUsers collection',
        );
        await _firestore.collection('regularUsers').doc(uid).set(
          {'fcmToken': token},
          SetOptions(
            merge: true,
          ), // Use merge to avoid overwriting existing data
        );
      } else {
        // User hasn't completed profile setup yet - skip FCM token saving for now
        debugPrint(
          '[ProfileService] User profile not complete yet, skipping FCM token save',
        );
        debugPrint(
          '[ProfileService] FCM token will be saved when profile is created',
        );
        return;
      }

      debugPrint('[ProfileService] FCM token saved to Firestore successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error saving FCM token: $e');
      // Don't rethrow, not a critical error for UI
    }
  }

  /// Loads regular user profile from Firestore and caches locally
  Future<RegularUserProfile?> loadRegularUserProfileFromFirestore(
    String uid,
  ) async {
    debugPrint(
      '[ProfileService] Loading regular user profile from Firestore for UID: $uid',
    );

    try {
      final doc = await _firestore.collection('regularUsers').doc(uid).get();

      if (!doc.exists) {
        debugPrint(
          '[ProfileService] No regular user profile found in Firestore for UID: $uid',
        );
        return null;
      }

      final data = doc.data()!;
      final profile = RegularUserProfile.fromFirestore(data, uid);

      // Cache locally
      await _hiveService.saveRegularUserProfile(profile);

      debugPrint(
        '[ProfileService] Regular user profile loaded and cached successfully',
      );
      return profile;
    } catch (e) {
      debugPrint(
        '[ProfileService] Error loading regular user profile from Firestore: $e',
      );
      throw Exception('Failed to load regular user profile: $e');
    }
  }

  /// Deletes the current user's regular user profile
  Future<void> deleteCurrentRegularUserProfile() async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to delete profile');
    }

    debugPrint('[ProfileService] Deleting regular user profile for user: $uid');

    try {
      // Delete from Firestore
      await _firestore.collection('regularUsers').doc(uid).delete();

      // Delete avatar from Storage
      try {
        await _storage.ref().child('regularUsers/$uid/avatar.jpg').delete();
      } catch (e) {
        debugPrint(
          '[ProfileService] Avatar deletion failed (may not exist): $e',
        );
      }

      // Delete from local storage
      await _hiveService.deleteRegularUserProfile(uid);

      // 📢 Broadcast profile deletion to all listeners
      _profileUpdateNotifier.notifyProfileDelete(uid);
      debugPrint(
        '[ProfileService] 📢 Profile deletion broadcasted for UID: $uid',
      );

      debugPrint('[ProfileService] Regular user profile deleted successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error deleting regular user profile: $e');
      throw Exception('Failed to delete regular user profile: $e');
    }
  }

  /// Loads any user profile (vendor or regular user) from Firestore
  /// Returns a VendorProfile for compatibility with messaging UI
  Future<VendorProfile?> loadAnyUserProfileFromFirestore(String uid) async {
    debugPrint(
      '[ProfileService] Loading any user profile from Firestore for UID: $uid',
    );

    try {
      // First try to load as vendor profile
      final vendorProfile = await loadProfileFromFirestore(uid);
      if (vendorProfile != null) {
        debugPrint('[ProfileService] Found vendor profile for UID: $uid');
        return vendorProfile;
      }

      // If not found, try to load as regular user profile
      final regularProfile = await loadRegularUserProfileFromFirestore(uid);
      if (regularProfile != null) {
        debugPrint(
          '[ProfileService] Found regular user profile for UID: $uid, converting to VendorProfile format',
        );

        // Convert RegularUserProfile to VendorProfile for messaging UI compatibility
        return VendorProfile(
          uid: regularProfile.uid,
          displayName: regularProfile.displayName,
          stallName: 'Customer', // Regular users don't have stalls
          marketCity: 'User', // Regular users don't have market cities
          allowLocation: false,
          avatarURL: regularProfile.avatarURL,
          localAvatarPath: regularProfile.localAvatarPath,
          needsSync: false, // Already loaded from Firestore
          lastUpdated: DateTime.now(),
        );
      }

      debugPrint(
        '[ProfileService] No profile found in either collection for UID: $uid',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[ProfileService] Error loading any user profile from Firestore: $e',
      );
      throw Exception('Failed to load user profile: $e');
    }
  }
}
