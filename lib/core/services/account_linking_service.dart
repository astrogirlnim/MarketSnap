import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vendor_profile.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/profile/application/profile_service.dart';

/// Service for handling account linking and profile consolidation
/// Prevents multiple vendor profiles per person by linking accounts
/// based on shared phone numbers or email addresses
class AccountLinkingService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final ProfileService _profileService;

  AccountLinkingService({
    required AuthService authService,
    required ProfileService profileService,
    FirebaseFirestore? firestore,
  }) : _authService = authService,
       _profileService = profileService,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Checks if the current user should be prompted to link accounts
  /// Returns true if there's an existing profile with the same phone/email
  Future<bool> shouldPromptAccountLinking() async {
    debugPrint('[AccountLinkingService] Checking if account linking is needed');

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('[AccountLinkingService] No current user');
      return false;
    }

    // Get current user's contact info
    final phoneNumber = _authService.getUserPhoneNumber();
    final email = _authService.getUserEmail();

    debugPrint(
      '[AccountLinkingService] Current user - Phone: $phoneNumber, Email: $email',
    );

    if (phoneNumber == null && email == null) {
      debugPrint(
        '[AccountLinkingService] No contact info available for linking',
      );
      return false;
    }

    try {
      // Check for existing profiles with same phone number or email
      final existingProfile = await _findExistingProfileByContact(
        phoneNumber,
        email,
      );

      if (existingProfile != null && existingProfile.uid != currentUser.uid) {
        debugPrint(
          '[AccountLinkingService] Found existing profile for different user: ${existingProfile.uid}',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error checking for existing profiles: $e',
      );
      return false;
    }
  }

  /// Finds existing vendor profile by phone number or email
  Future<VendorProfile?> _findExistingProfileByContact(
    String? phoneNumber,
    String? email,
  ) async {
    debugPrint(
      '[AccountLinkingService] Searching for existing profiles by contact info',
    );

    try {
      // First check by phone number if available
      if (phoneNumber != null) {
        debugPrint('[AccountLinkingService] Searching by phone: $phoneNumber');
        final phoneQuery = await _firestore
            .collection('vendors')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          final doc = phoneQuery.docs.first;
          debugPrint(
            '[AccountLinkingService] Found profile by phone: ${doc.id}',
          );
          return VendorProfile.fromFirestore(doc.data(), doc.id);
        }
      }

      // Then check by email if available
      if (email != null) {
        debugPrint('[AccountLinkingService] Searching by email: $email');
        final emailQuery = await _firestore
            .collection('vendors')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          final doc = emailQuery.docs.first;
          debugPrint(
            '[AccountLinkingService] Found profile by email: ${doc.id}',
          );
          return VendorProfile.fromFirestore(doc.data(), doc.id);
        }
      }

      debugPrint('[AccountLinkingService] No existing profile found');
      return null;
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error searching for existing profiles: $e',
      );
      return null;
    }
  }

  /// Consolidates profiles by merging data from multiple accounts
  Future<void> consolidateProfiles(
    String primaryUid,
    String secondaryUid,
  ) async {
    debugPrint(
      '[AccountLinkingService] Consolidating profiles: $primaryUid <- $secondaryUid',
    );

    try {
      // Get both profiles
      final primaryDoc = await _firestore
          .collection('vendors')
          .doc(primaryUid)
          .get();
      final secondaryDoc = await _firestore
          .collection('vendors')
          .doc(secondaryUid)
          .get();

      if (!primaryDoc.exists) {
        debugPrint('[AccountLinkingService] Primary profile not found');
        return;
      }

      if (!secondaryDoc.exists) {
        debugPrint('[AccountLinkingService] Secondary profile not found');
        return;
      }

      final primaryProfile = VendorProfile.fromFirestore(
        primaryDoc.data()!,
        primaryUid,
      );
      final secondaryProfile = VendorProfile.fromFirestore(
        secondaryDoc.data()!,
        secondaryUid,
      );

      // Merge profile data (prefer primary, but fill in missing fields from secondary)
      final consolidatedProfile = _mergeProfiles(
        primaryProfile,
        secondaryProfile,
      );

      // Update primary profile with consolidated data
      await _firestore
          .collection('vendors')
          .doc(primaryUid)
          .set(consolidatedProfile.toFirestore());

      // Delete secondary profile
      await _firestore.collection('vendors').doc(secondaryUid).delete();

      debugPrint('[AccountLinkingService] Profile consolidation completed');
    } catch (e) {
      debugPrint('[AccountLinkingService] Error consolidating profiles: $e');
      throw Exception('Failed to consolidate profiles: $e');
    }
  }

  /// Merges two vendor profiles, preferring primary but filling gaps with secondary
  VendorProfile _mergeProfiles(VendorProfile primary, VendorProfile secondary) {
    debugPrint('[AccountLinkingService] Merging profiles');

    return primary.copyWith(
      // Use secondary data if primary is missing critical info
      displayName: primary.displayName.isNotEmpty
          ? primary.displayName
          : secondary.displayName,
      stallName: primary.stallName.isNotEmpty
          ? primary.stallName
          : secondary.stallName,
      marketCity: primary.marketCity.isNotEmpty
          ? primary.marketCity
          : secondary.marketCity,

      // Use primary avatar if available, otherwise secondary
      avatarURL: primary.avatarURL ?? secondary.avatarURL,
      localAvatarPath: primary.localAvatarPath ?? secondary.localAvatarPath,

      // Merge contact info
      phoneNumber: primary.phoneNumber ?? secondary.phoneNumber,
      email: primary.email ?? secondary.email,

      // Prefer primary settings
      allowLocation: primary.allowLocation,

      // Update timestamps
      lastUpdated: DateTime.now(),
      needsSync: true,
    );
  }

  /// Updates vendor profile with current user's contact information
  Future<void> updateProfileWithUserInfo() async {
    debugPrint(
      '[AccountLinkingService] Updating profile with current user info',
    );

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('[AccountLinkingService] No current user');
      return;
    }

    final phoneNumber = _authService.getUserPhoneNumber();
    final email = _authService.getUserEmail();

    debugPrint(
      '[AccountLinkingService] User contact info - Phone: $phoneNumber, Email: $email',
    );

    if (phoneNumber == null && email == null) {
      debugPrint('[AccountLinkingService] No contact info to update');
      return;
    }

    try {
      // Get current profile
      final currentProfile = _profileService.getCurrentUserProfile();
      if (currentProfile == null) {
        debugPrint('[AccountLinkingService] No current profile to update');
        return;
      }

      // Update profile with contact info
      final updatedProfile = currentProfile.copyWith(
        phoneNumber: phoneNumber ?? currentProfile.phoneNumber,
        email: email ?? currentProfile.email,
        lastUpdated: DateTime.now(),
        needsSync: true,
      );

      // Save updated profile locally (we need to use the public method)
      await _profileService.saveProfile(
        displayName: updatedProfile.displayName,
        stallName: updatedProfile.stallName,
        marketCity: updatedProfile.marketCity,
        allowLocation: updatedProfile.allowLocation,
        localAvatarPath: updatedProfile.localAvatarPath,
      );

      // Sync to Firestore
      await _profileService.syncProfileToFirestore(currentUser.uid);

      debugPrint(
        '[AccountLinkingService] Profile updated with user contact info',
      );
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error updating profile with user info: $e',
      );
      // Don't throw - this is a background operation
    }
  }

  /// Handles the account linking flow when a user signs in
  Future<void> handleSignInAccountLinking() async {
    debugPrint('[AccountLinkingService] Handling sign-in account linking');

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint('[AccountLinkingService] No current user');
        return;
      }

      // Get current user's contact info
      final phoneNumber = _authService.getUserPhoneNumber();
      final email = _authService.getUserEmail();

      debugPrint(
        '[AccountLinkingService] Current user - Phone: $phoneNumber, Email: $email',
      );

      if (phoneNumber == null && email == null) {
        debugPrint('[AccountLinkingService] No contact info available for linking');
        return;
      }

      // Check for existing profiles with same phone number or email
      final existingProfile = await _findExistingProfileByContact(
        phoneNumber,
        email,
      );

      if (existingProfile != null && existingProfile.uid != currentUser.uid) {
        debugPrint(
          '[AccountLinkingService] Found existing profile for different user: ${existingProfile.uid}',
        );
        debugPrint('[AccountLinkingService] Automatically consolidating profiles...');

        // Automatically consolidate profiles
        await _migrateProfileToNewUid(existingProfile.uid, currentUser.uid);
        
        debugPrint('[AccountLinkingService] Profile consolidation completed successfully');
      } else {
        debugPrint('[AccountLinkingService] No existing profile found or same user');
        
        // Update current profile with user info if no consolidation needed
        await updateProfileWithUserInfo();
      }
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error in sign-in account linking: $e',
      );
      // Don't throw - this shouldn't block the sign-in flow
    }
  }

  /// Migrates an existing profile to a new UID, including messages
  Future<void> _migrateProfileToNewUid(String oldUid, String newUid) async {
    debugPrint('[AccountLinkingService] Migrating profile from $oldUid to $newUid');

    try {
      // Get the existing profile
      final oldProfileDoc = await _firestore.collection('vendors').doc(oldUid).get();
      if (!oldProfileDoc.exists) {
        debugPrint('[AccountLinkingService] Old profile not found: $oldUid');
        return;
      }

      final oldProfile = VendorProfile.fromFirestore(oldProfileDoc.data()!, oldUid);
      debugPrint('[AccountLinkingService] Found existing profile: ${oldProfile.stallName}');

      // Update profile with current user's contact info
      final phoneNumber = _authService.getUserPhoneNumber();
      final email = _authService.getUserEmail();

      final migratedProfile = oldProfile.copyWith(
        uid: newUid,
        phoneNumber: phoneNumber ?? oldProfile.phoneNumber,
        email: email ?? oldProfile.email,
        lastUpdated: DateTime.now(),
        needsSync: true,
      );

      // Save the migrated profile to the new UID
      await _firestore
          .collection('vendors')
          .doc(newUid)
          .set(migratedProfile.toFirestore());
      
      debugPrint('[AccountLinkingService] Profile migrated to new UID: $newUid');

      // Migrate messages that reference the old UID
      await _migrateMessages(oldUid, newUid);

      // Delete the old profile
      await _firestore.collection('vendors').doc(oldUid).delete();
      debugPrint('[AccountLinkingService] Old profile deleted: $oldUid');

      // Update local profile service with the migrated profile
      await _profileService.saveProfile(
        displayName: migratedProfile.displayName,
        stallName: migratedProfile.stallName,
        marketCity: migratedProfile.marketCity,
        allowLocation: migratedProfile.allowLocation,
        localAvatarPath: migratedProfile.localAvatarPath,
      );

      debugPrint('[AccountLinkingService] Profile migration completed successfully');
    } catch (e) {
      debugPrint('[AccountLinkingService] Error migrating profile: $e');
      throw Exception('Failed to migrate profile: $e');
    }
  }

  /// Migrates messages from old UID to new UID
  Future<void> _migrateMessages(String oldUid, String newUid) async {
    debugPrint('[AccountLinkingService] Migrating messages from $oldUid to $newUid');

    try {
      // Find all messages where the old UID is a participant
      final messagesQuery = await _firestore
          .collection('messages')
          .where('participants', arrayContains: oldUid)
          .get();

      debugPrint('[AccountLinkingService] Found ${messagesQuery.docs.length} messages to migrate');

      // Batch update messages
      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in messagesQuery.docs) {
        final messageData = doc.data();
        final participants = List<String>.from(messageData['participants'] ?? []);
        
        // Replace old UID with new UID in participants
        final updatedParticipants = participants.map((uid) => uid == oldUid ? newUid : uid).toList();
        
        // Update fromUid if it matches old UID
        final updatedFromUid = messageData['fromUid'] == oldUid ? newUid : messageData['fromUid'];
        
        // Update toUid if it matches old UID
        final updatedToUid = messageData['toUid'] == oldUid ? newUid : messageData['toUid'];

        // Update conversationId to reflect the new UID
        final sortedParticipants = List<String>.from(updatedParticipants)..sort();
        final updatedConversationId = '${sortedParticipants[0]}_${sortedParticipants[1]}';

        // Update the message document
        batch.update(doc.reference, {
          'participants': updatedParticipants,
          'fromUid': updatedFromUid,
          'toUid': updatedToUid,
          'conversationId': updatedConversationId,
        });

        updateCount++;
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint('[AccountLinkingService] Updated $updateCount messages with new UID');
      } else {
        debugPrint('[AccountLinkingService] No messages to migrate');
      }
    } catch (e) {
      debugPrint('[AccountLinkingService] Error migrating messages: $e');
      // Don't throw - message migration failure shouldn't block profile migration
    }
  }

  /// Gets information about linkable accounts for the current user
  Future<Map<String, dynamic>> getLinkableAccountInfo() async {
    debugPrint('[AccountLinkingService] Getting linkable account info');

    final currentUser = _authService.currentUser;
    if (currentUser == null) return {};

    final phoneNumber = _authService.getUserPhoneNumber();
    final email = _authService.getUserEmail();

    try {
      final existingProfile = await _findExistingProfileByContact(
        phoneNumber,
        email,
      );

      return {
        'hasLinkableAccount':
            existingProfile != null && existingProfile.uid != currentUser.uid,
        'existingProfile': existingProfile?.toMap(),
        'currentProviders': _authService.getUserProviders(),
        'hasMultipleProviders': _authService.hasMultipleProviders(),
      };
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error getting linkable account info: $e',
      );
      return {};
    }
  }
}
