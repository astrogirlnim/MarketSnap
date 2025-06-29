import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vendor_profile.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/profile/application/profile_service.dart';
import '../../main.dart' as main;

/// Service for handling account linking and profile discovery
/// Finds existing vendor profiles by phone/email to prevent duplicates
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

  /// Checks if an existing vendor profile exists for the current user's contact info
  /// Returns the existing profile if found, null if no profile exists
  Future<VendorProfile?> findExistingProfileForCurrentUser() async {
    debugPrint(
      '[AccountLinkingService] Checking for existing profile for current user',
    );

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('[AccountLinkingService] No current user');
      return null;
    }

    // Get current user's contact info
    final phoneNumber = _authService.getUserPhoneNumber();
    final email = _authService.getUserEmail();

    debugPrint(
      '[AccountLinkingService] Current user - UID: ${currentUser.uid}, Phone: $phoneNumber, Email: $email',
    );

    try {
      // First check if vendor profile already exists with current UID
      final currentUidProfile = await _firestore
          .collection('vendors')
          .doc(currentUser.uid)
          .get();

      if (currentUidProfile.exists) {
        debugPrint(
          '[AccountLinkingService] Profile already exists for current UID: ${currentUser.uid}',
        );
        return VendorProfile.fromFirestore(
          currentUidProfile.data()!,
          currentUser.uid,
        );
      }

      // Check if a regular user profile exists - this indicates the user has an existing profile
      final hasRegularProfile = _profileService.hasCompleteRegularUserProfile();
      if (hasRegularProfile) {
        debugPrint(
          '[AccountLinkingService] Found existing regular user profile for current UID: ${currentUser.uid}',
        );
        // Return a placeholder VendorProfile to indicate profile exists
        // The actual profile handling will be done by AuthWrapper
        return VendorProfile(
          uid: currentUser.uid,
          displayName: 'Regular User',
          stallName: 'Customer',
          marketCity: 'User',
          phoneNumber: phoneNumber,
          email: email,
          needsSync: false,
        );
      }

      // ✅ CRITICAL ENHANCEMENT: Enhanced cross-platform profile search
      // This provides robust fallback when Firebase Auth UIDs are inconsistent across platforms
      debugPrint(
        '[AccountLinkingService] Searching for existing profiles by contact info',
      );

      if (phoneNumber != null || email != null) {
        final existingProfile = await _findExistingProfileByContact(
          phoneNumber,
          email,
        );

        if (existingProfile != null) {
          debugPrint(
            '[AccountLinkingService] ✅ Found existing vendor profile: ${existingProfile.stallName} (${existingProfile.uid})',
          );
          debugPrint(
            '[AccountLinkingService] 🔗 This resolves cross-platform authentication issues',
          );

          // Copy the existing profile to the current user's UID
          await _copyProfileToCurrentUser(existingProfile);

          return existingProfile;
        }
      }

      debugPrint('[AccountLinkingService] No existing profile found');
      return null;
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error checking for existing profiles: $e',
      );

      // ✅ ENHANCEMENT: Add retry logic for transient Firestore errors
      if (e.toString().contains('unavailable') ||
          e.toString().contains('deadline-exceeded')) {
        debugPrint(
          '[AccountLinkingService] 🔄 Retrying due to transient error...',
        );
        await Future.delayed(const Duration(seconds: 2));

        try {
          // Retry the contact-based search only (most critical for cross-platform linking)
          if (phoneNumber != null || email != null) {
            final existingProfile = await _findExistingProfileByContact(
              phoneNumber,
              email,
            );

            if (existingProfile != null) {
              debugPrint(
                '[AccountLinkingService] ✅ Retry successful: Found profile ${existingProfile.stallName}',
              );
              await _copyProfileToCurrentUser(existingProfile);
              return existingProfile;
            }
          }
        } catch (retryError) {
          debugPrint(
            '[AccountLinkingService] ❌ Retry also failed: $retryError',
          );
        }
      }

      return null;
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

  /// Copies an existing profile to the current user's UID and updates contact info
  Future<void> _copyProfileToCurrentUser(VendorProfile existingProfile) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('[AccountLinkingService] No current user to copy profile to');
      return;
    }

    debugPrint(
      '[AccountLinkingService] Copying profile to current user UID: ${currentUser.uid}',
    );

    try {
      // Update profile with current user's contact info and UID
      final phoneNumber = _authService.getUserPhoneNumber();
      final email = _authService.getUserEmail();

      final updatedProfile = existingProfile.copyWith(
        uid: currentUser.uid,
        phoneNumber: phoneNumber ?? existingProfile.phoneNumber,
        email: email ?? existingProfile.email,
        lastUpdated: DateTime.now(),
        needsSync: true,
      );

      // Save the profile to the current user's UID in Firestore
      await _firestore
          .collection('vendors')
          .doc(currentUser.uid)
          .set(updatedProfile.toFirestore());

      debugPrint(
        '[AccountLinkingService] Profile copied to current user UID: ${currentUser.uid}',
      );

      // Also save locally via ProfileService
      await _profileService.saveProfile(
        displayName: updatedProfile.displayName,
        stallName: updatedProfile.stallName,
        marketCity: updatedProfile.marketCity,
        allowLocation: updatedProfile.allowLocation,
        localAvatarPath: updatedProfile.localAvatarPath,
      );

      debugPrint(
        '[AccountLinkingService] Profile saved locally via ProfileService',
      );
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error copying profile to current user: $e',
      );
      throw Exception('Failed to link existing profile: $e');
    }
  }

  /// Handles the account linking flow when a user signs in
  /// Returns true if an existing profile was found and linked
  Future<bool> handleSignInAccountLinking() async {
    debugPrint('[AccountLinkingService] Handling sign-in account linking');

    try {
      final existingProfile = await findExistingProfileForCurrentUser();

      if (existingProfile != null) {
        debugPrint(
          '[AccountLinkingService] Successfully linked existing profile: ${existingProfile.stallName}',
        );

        // ✅ CRITICAL FIX: Trigger comprehensive data sync after successful profile linking
        debugPrint(
          '[AccountLinkingService] 🚀 Triggering comprehensive data sync for cross-platform consistency',
        );

        try {
          // Check if user needs full data sync (first time on this device, or stale data)
          if (main.userDataSyncService.needsFullSync()) {
            debugPrint(
              '[AccountLinkingService] 📊 Full data sync needed - downloading all user data',
            );
            final syncResult = await main.userDataSyncService
                .performFullDataSync();

            if (syncResult.isSuccess) {
              debugPrint(
                '[AccountLinkingService] ✅ Data sync completed successfully',
              );
              debugPrint(
                '[AccountLinkingService] 📊 Sync summary: ${syncResult.summary}',
              );
            } else {
              debugPrint(
                '[AccountLinkingService] ❌ Data sync failed: ${syncResult.errorMessage}',
              );
              // Continue anyway - user can still use the app with just profile data
            }
          } else {
            debugPrint(
              '[AccountLinkingService] ✅ Recent sync found - skipping full data sync',
            );
          }
        } catch (syncError) {
          debugPrint(
            '[AccountLinkingService] ❌ Error during data sync: $syncError',
          );
          // Don't throw - profile linking succeeded, sync is secondary
        }

        return true;
      } else {
        debugPrint(
          '[AccountLinkingService] No existing profile found - user needs to create profile',
        );

        // Still check if we need to sync data for new profile creation
        try {
          if (main.userDataSyncService.needsFullSync()) {
            debugPrint(
              '[AccountLinkingService] 🆕 New user - performing initial data sync check',
            );
            await main.userDataSyncService.performFullDataSync();
          }
        } catch (syncError) {
          debugPrint(
            '[AccountLinkingService] Warning: Initial sync failed for new user: $syncError',
          );
          // Non-critical for new users
        }

        return false;
      }
    } catch (e) {
      debugPrint(
        '[AccountLinkingService] Error in sign-in account linking: $e',
      );
      // Don't throw - this shouldn't block the sign-in flow
      return false;
    }
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
