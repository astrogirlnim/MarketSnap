import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/vendor_profile.dart';
import '../../../core/models/regular_user_profile.dart';
import '../../../core/services/hive_service.dart';
import '../../../main.dart' as main;

/// Service for managing vendor profiles with offline-first capabilities.
/// Handles profile CRUD operations, avatar uploads, and Firebase sync.
class ProfileService {
  final HiveService _hiveService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _imagePicker;

  ProfileService({
    required HiveService hiveService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? imagePicker,
  }) : _hiveService = hiveService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _imagePicker = imagePicker ?? ImagePicker();

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

    debugPrint('[ProfileService] Saving profile for user: $uid');
    debugPrint('[ProfileService] Profile data: $stallName in $marketCity');

    // Get existing profile or create new one
    final existingProfile = _hiveService.getVendorProfile(uid);

    final profile = VendorProfile(
      uid: uid,
      displayName: displayName.trim(),
      stallName: stallName.trim(),
      marketCity: marketCity.trim(),
      allowLocation: allowLocation,
      localAvatarPath: localAvatarPath,
      avatarURL: existingProfile?.avatarURL, // Preserve existing avatar URL
      needsSync: true, // Mark for sync since we're updating locally
      lastUpdated: DateTime.now(),
    );

    await _hiveService.saveVendorProfile(profile);
    debugPrint('[ProfileService] Profile saved locally successfully');

    // Try to sync immediately if online - but don't block the UI
    _attemptImmediateSync(uid);
    
    // Also try to save FCM token now that profile exists
    _attemptFCMTokenSave();
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

    debugPrint('[ProfileService] Uploading avatar for user: $uid');

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Avatar file does not exist: $localPath');
      }

      // Create a reference to the avatar location
      final ref = _storage.ref().child('vendors/$uid/avatar.jpg');

      // Upload the file
      debugPrint('[ProfileService] Starting avatar upload...');
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[ProfileService] Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[ProfileService] Error uploading avatar: $e');
      throw Exception('Failed to upload avatar: $e');
    }
  }

  /// Syncs a vendor profile from local storage to Firestore
  Future<void> syncProfileToFirestore(String uid) async {
    debugPrint('[ProfileService] Syncing profile to Firestore for UID: $uid');

    final profile = _hiveService.getVendorProfile(uid);
    if (profile == null) {
      debugPrint('[ProfileService] No profile found locally for UID: $uid');
      return;
    }

    if (!profile.needsSync) {
      debugPrint('[ProfileService] Profile already synced for UID: $uid');
      return;
    }

    try {
      debugPrint('[ProfileService] Starting Firestore sync process...');

      // Upload avatar if we have a local path but no URL
      String? avatarURL = profile.avatarURL;
      if (profile.localAvatarPath != null && profile.avatarURL == null) {
        debugPrint('[ProfileService] Uploading avatar before profile sync');
        avatarURL = await uploadAvatar(profile.localAvatarPath!);
      }

      // Update profile with avatar URL if we got one
      final profileToSync = avatarURL != null
          ? profile.copyWith(avatarURL: avatarURL, localAvatarPath: null)
          : profile;

      debugPrint(
        '[ProfileService] Writing profile to Firestore collection: vendors/$uid',
      );

      // Sync to Firestore with timeout and detailed error handling
      await _firestore
          .collection('vendors')
          .doc(uid)
          .set(profileToSync.toFirestore())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Firestore write operation timed out after 10 seconds',
            ),
          );

      debugPrint('[ProfileService] Firestore write completed successfully');

      // Mark as synced locally
      await _hiveService.markProfileAsSynced(uid);

      // Save updated profile with avatar URL
      if (avatarURL != null) {
        await _hiveService.saveVendorProfile(
          profileToSync.copyWith(needsSync: false),
        );
      }

      debugPrint('[ProfileService] Profile synced to Firestore successfully');
    } on FirebaseException catch (e) {
      debugPrint(
        '[ProfileService] Firebase error during sync: ${e.code} - ${e.message}',
      );
      throw Exception('Firebase sync failed: ${e.message}');
    } catch (e) {
      debugPrint('[ProfileService] Error syncing profile to Firestore: $e');

      // Additional diagnostics for Firestore connection issues
      if (e.toString().contains('FRAME_SIZE_ERROR') ||
          e.toString().contains('Failed to connect') ||
          e.toString().contains('INTERNAL')) {
        debugPrint(
          '[ProfileService] Detected Firestore emulator connection issue',
        );
        debugPrint(
          '[ProfileService] This is likely due to emulator connectivity problems',
        );
      }

      throw Exception('Failed to sync profile: $e');
    }
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
          SetOptions(merge: true), // Use merge to avoid overwriting existing data
        );
      } else if (regularProfile != null) {
        // User is a regular user - save to regularUsers collection
        debugPrint('[ProfileService] Saving FCM token to regularUsers collection');
        await _firestore.collection('regularUsers').doc(uid).set(
          {'fcmToken': token},
          SetOptions(merge: true), // Use merge to avoid overwriting existing data
        );
      } else {
        // User hasn't completed profile setup yet - skip FCM token saving for now
        debugPrint('[ProfileService] User profile not complete yet, skipping FCM token save');
        debugPrint('[ProfileService] FCM token will be saved when profile is created');
        return;
      }

      debugPrint('[ProfileService] FCM token saved to Firestore successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error saving FCM token: $e');
      // Don't rethrow, not a critical error for UI
    }
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
        await syncProfileToFirestore(profile.uid);
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

  /// Creates or updates a regular user profile locally
  Future<void> saveRegularUserProfile({
    required String displayName,
    String? localAvatarPath,
  }) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw Exception('User must be authenticated to save profile');
    }

    debugPrint('[ProfileService] Saving regular user profile for UID: $uid');

    try {
      // Get current user's contact info from auth
      final user = _auth.currentUser;
      final phoneNumber = user?.phoneNumber;
      final email = user?.email;

      final profile = RegularUserProfile(
        uid: uid,
        displayName: displayName.trim(),
        localAvatarPath: localAvatarPath,
        phoneNumber: phoneNumber,
        email: email,
        needsSync: true,
      );

      // Save locally
      await _hiveService.saveRegularUserProfile(profile);

      debugPrint('[ProfileService] Regular user profile saved locally');

      // Try to sync to Firestore if online
      try {
        await syncRegularUserProfileToFirestore(uid);
      } catch (e) {
        debugPrint('[ProfileService] Profile saved locally, will sync when online: $e');
      }
      
      // Also try to save FCM token now that profile exists
      _attemptFCMTokenSave();
    } catch (e) {
      debugPrint('[ProfileService] Error saving regular user profile: $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  /// Syncs a regular user profile from local storage to Firestore
  Future<void> syncRegularUserProfileToFirestore(String uid) async {
    debugPrint('[ProfileService] Syncing regular user profile to Firestore for UID: $uid');

    final profile = _hiveService.getRegularUserProfile(uid);
    if (profile == null) {
      debugPrint('[ProfileService] No regular user profile found locally for UID: $uid');
      return;
    }

    if (!profile.needsSync) {
      debugPrint('[ProfileService] Regular user profile already synced for UID: $uid');
      return;
    }

    try {
      debugPrint('[ProfileService] Starting regular user profile Firestore sync process...');

      // Upload avatar if we have a local path but no URL
      String? avatarURL = profile.avatarURL;
      if (profile.localAvatarPath != null && profile.avatarURL == null) {
        debugPrint('[ProfileService] Uploading avatar before regular user profile sync');
        avatarURL = await uploadAvatar(profile.localAvatarPath!);
      }

      // Update profile with avatar URL if we got one
      final profileToSync = avatarURL != null
          ? profile.copyWith(avatarURL: avatarURL, localAvatarPath: null)
          : profile;

      debugPrint(
        '[ProfileService] Writing regular user profile to Firestore collection: regularUsers/$uid',
      );

      // Sync to Firestore regular users collection
      await _firestore
          .collection('regularUsers')
          .doc(uid)
          .set(profileToSync.toFirestore())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Firestore write operation timed out after 10 seconds',
            ),
          );

      debugPrint('[ProfileService] Regular user profile Firestore write completed successfully');

      // Mark as synced locally
      await _hiveService.saveRegularUserProfile(
        profileToSync.copyWith(needsSync: false),
      );

      debugPrint('[ProfileService] Regular user profile synced to Firestore successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error syncing regular user profile to Firestore: $e');
      throw Exception('Failed to sync regular user profile: $e');
    }
  }

  /// Checks if the current user has a complete regular user profile
  bool hasCompleteRegularUserProfile() {
    final uid = currentUserUid;
    if (uid == null) return false;
    return _hiveService.hasCompleteRegularUserProfile(uid);
  }

  /// Loads regular user profile from Firestore and caches locally
  Future<RegularUserProfile?> loadRegularUserProfileFromFirestore(String uid) async {
    debugPrint('[ProfileService] Loading regular user profile from Firestore for UID: $uid');

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

      debugPrint('[ProfileService] Regular user profile loaded and cached successfully');
      return profile;
    } catch (e) {
      debugPrint('[ProfileService] Error loading regular user profile from Firestore: $e');
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

      debugPrint('[ProfileService] Regular user profile deleted successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error deleting regular user profile: $e');
      throw Exception('Failed to delete regular user profile: $e');
    }
  }
}
