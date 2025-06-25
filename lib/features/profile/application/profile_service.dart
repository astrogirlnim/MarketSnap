import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/vendor_profile.dart';
import '../../../core/services/hive_service.dart';

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
  })  : _hiveService = hiveService,
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

    // Try to sync immediately if online
    try {
      await syncProfileToFirestore(uid);
    } catch (e) {
      debugPrint('[ProfileService] Failed to sync immediately, will retry later: $e');
      // Don't throw - offline-first means we save locally and sync when possible
    }
  }

  /// Picks an image from gallery or camera for avatar
  Future<String?> pickAvatarImage({bool fromCamera = false}) async {
    debugPrint('[ProfileService] Picking avatar image from ${fromCamera ? 'camera' : 'gallery'}');

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

      // Sync to Firestore
      await _firestore
          .collection('vendors')
          .doc(uid)
          .set(profileToSync.toFirestore());

      // Mark as synced locally
      await _hiveService.markProfileAsSynced(uid);
      
      // Save updated profile with avatar URL
      if (avatarURL != null) {
        await _hiveService.saveVendorProfile(
          profileToSync.copyWith(needsSync: false)
        );
      }

      debugPrint('[ProfileService] Profile synced to Firestore successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error syncing profile to Firestore: $e');
      throw Exception('Failed to sync profile: $e');
    }
  }

  /// Loads vendor profile from Firestore and caches locally
  Future<VendorProfile?> loadProfileFromFirestore(String uid) async {
    debugPrint('[ProfileService] Loading profile from Firestore for UID: $uid');

    try {
      final doc = await _firestore.collection('vendors').doc(uid).get();
      
      if (!doc.exists) {
        debugPrint('[ProfileService] No profile found in Firestore for UID: $uid');
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
    debugPrint('[ProfileService] Found ${profilesNeedingSync.length} profiles to sync');

    for (final profile in profilesNeedingSync) {
      try {
        await syncProfileToFirestore(profile.uid);
      } catch (e) {
        debugPrint('[ProfileService] Failed to sync profile ${profile.uid}: $e');
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
        debugPrint('[ProfileService] Avatar deletion failed (may not exist): $e');
      }
      
      // Delete from local storage
      await _hiveService.deleteVendorProfile(uid);
      
      debugPrint('[ProfileService] Profile deleted successfully');
    } catch (e) {
      debugPrint('[ProfileService] Error deleting profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
  }
} 