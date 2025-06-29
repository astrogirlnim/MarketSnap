// Service to fix authentication profile mismatch issues
// This service handles cases where users have cached auth but mismatched profile UIDs

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vendor_profile.dart';
import '../models/regular_user_profile.dart';
import 'hive_service.dart';
import 'profile_update_notifier.dart';

class AuthIssueFixService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final HiveService _hiveService;
  final ProfileUpdateNotifier _profileUpdateNotifier;

  AuthIssueFixService({
    required HiveService hiveService,
    required ProfileUpdateNotifier profileUpdateNotifier,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _hiveService = hiveService,
       _profileUpdateNotifier = profileUpdateNotifier,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Comprehensive fix for authentication profile mismatch issues
  /// Returns true if a profile was found and fixed, false if user needs to create a profile
  Future<bool> fixAuthenticationProfileMismatch() async {
    debugPrint('[AuthIssueFixService] 🔧 Starting authentication profile fix');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('[AuthIssueFixService] ❌ No authenticated user');
      return false;
    }

    debugPrint('[AuthIssueFixService] 👤 Current user: ${currentUser.uid}');
    debugPrint('[AuthIssueFixService] 📧 Email: ${currentUser.email}');
    debugPrint('[AuthIssueFixService] 📱 Phone: ${currentUser.phoneNumber}');

    try {
      // Step 1: Check if current UID already has a profile
      final hasCurrentVendorProfile = await _checkVendorProfileExists(
        currentUser.uid,
      );
      final hasCurrentRegularProfile = await _checkRegularProfileExists(
        currentUser.uid,
      );

      if (hasCurrentVendorProfile || hasCurrentRegularProfile) {
        debugPrint(
          '[AuthIssueFixService] ✅ User already has profile with current UID',
        );
        return true;
      }

      // Step 2: Search for existing profiles by contact info
      VendorProfile? existingVendorProfile;
      RegularUserProfile? existingRegularProfile;

      // Search by phone number
      if (currentUser.phoneNumber != null) {
        debugPrint(
          '[AuthIssueFixService] 🔍 Searching by phone: ${currentUser.phoneNumber}',
        );

        existingVendorProfile = await _findVendorByPhone(
          currentUser.phoneNumber!,
        );
        if (existingVendorProfile != null) {
          debugPrint('[AuthIssueFixService] ✅ Found vendor profile by phone');
        } else {
          existingRegularProfile = await _findRegularUserByPhone(
            currentUser.phoneNumber!,
          );
          if (existingRegularProfile != null) {
            debugPrint(
              '[AuthIssueFixService] ✅ Found regular user profile by phone',
            );
          }
        }
      }

      // Search by email if no phone match
      if (existingVendorProfile == null &&
          existingRegularProfile == null &&
          currentUser.email != null) {
        debugPrint(
          '[AuthIssueFixService] 🔍 Searching by email: ${currentUser.email}',
        );

        existingVendorProfile = await _findVendorByEmail(currentUser.email!);
        if (existingVendorProfile != null) {
          debugPrint('[AuthIssueFixService] ✅ Found vendor profile by email');
        } else {
          existingRegularProfile = await _findRegularUserByEmail(
            currentUser.email!,
          );
          if (existingRegularProfile != null) {
            debugPrint(
              '[AuthIssueFixService] ✅ Found regular user profile by email',
            );
          }
        }
      }

      // Step 3: Copy existing profile to current UID
      if (existingVendorProfile != null) {
        await _copyVendorProfileToCurrentUser(existingVendorProfile);
        return true;
      } else if (existingRegularProfile != null) {
        await _copyRegularProfileToCurrentUser(existingRegularProfile);
        return true;
      }

      debugPrint('[AuthIssueFixService] ❌ No existing profile found for user');
      return false;
    } catch (e, stackTrace) {
      debugPrint('[AuthIssueFixService] ❌ Error fixing authentication: $e');
      debugPrint('[AuthIssueFixService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Check if vendor profile exists for UID
  Future<bool> _checkVendorProfileExists(String uid) async {
    final doc = await _firestore.collection('vendors').doc(uid).get();
    return doc.exists;
  }

  /// Check if regular user profile exists for UID
  Future<bool> _checkRegularProfileExists(String uid) async {
    final doc = await _firestore.collection('regularUsers').doc(uid).get();
    return doc.exists;
  }

  /// Find vendor profile by phone number
  Future<VendorProfile?> _findVendorByPhone(String phoneNumber) async {
    final query = await _firestore
        .collection('vendors')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return VendorProfile.fromFirestore(doc.data(), doc.id);
    }
    return null;
  }

  /// Find regular user profile by phone number
  Future<RegularUserProfile?> _findRegularUserByPhone(
    String phoneNumber,
  ) async {
    final query = await _firestore
        .collection('regularUsers')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return RegularUserProfile.fromFirestore(doc.data(), doc.id);
    }
    return null;
  }

  /// Find vendor profile by email
  Future<VendorProfile?> _findVendorByEmail(String email) async {
    final query = await _firestore
        .collection('vendors')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return VendorProfile.fromFirestore(doc.data(), doc.id);
    }
    return null;
  }

  /// Find regular user profile by email
  Future<RegularUserProfile?> _findRegularUserByEmail(String email) async {
    final query = await _firestore
        .collection('regularUsers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return RegularUserProfile.fromFirestore(doc.data(), doc.id);
    }
    return null;
  }

  /// Copy vendor profile to current user UID
  Future<void> _copyVendorProfileToCurrentUser(
    VendorProfile existingProfile,
  ) async {
    final currentUser = _auth.currentUser!;
    debugPrint(
      '[AuthIssueFixService] 🔄 Copying vendor profile to current UID: ${currentUser.uid}',
    );

    // Update profile with current user's info
    final updatedProfile = existingProfile.copyWith(
      uid: currentUser.uid,
      phoneNumber: currentUser.phoneNumber ?? existingProfile.phoneNumber,
      email: currentUser.email ?? existingProfile.email,
      lastUpdated: DateTime.now(),
      needsSync: false, // Already saving to Firestore
    );

    // Save to Firestore with current UID
    await _firestore
        .collection('vendors')
        .doc(currentUser.uid)
        .set(updatedProfile.toFirestore());

    // Save to local storage
    await _hiveService.saveVendorProfile(updatedProfile);

    // Notify listeners
    _profileUpdateNotifier.notifyVendorProfileUpdate(updatedProfile);

    debugPrint('[AuthIssueFixService] ✅ Vendor profile copied successfully');
  }

  /// Copy regular user profile to current user UID
  Future<void> _copyRegularProfileToCurrentUser(
    RegularUserProfile existingProfile,
  ) async {
    final currentUser = _auth.currentUser!;
    debugPrint(
      '[AuthIssueFixService] 🔄 Copying regular user profile to current UID: ${currentUser.uid}',
    );

    // Update profile with current user's info
    final updatedProfile = existingProfile.copyWith(
      uid: currentUser.uid,
      phoneNumber: currentUser.phoneNumber ?? existingProfile.phoneNumber,
      email: currentUser.email ?? existingProfile.email,
      lastUpdated: DateTime.now(),
      needsSync: false, // Already saving to Firestore
    );

    // Save to Firestore with current UID
    await _firestore
        .collection('regularUsers')
        .doc(currentUser.uid)
        .set(updatedProfile.toFirestore());

    // Save to local storage
    await _hiveService.saveRegularUserProfile(updatedProfile);

    // Notify listeners
    _profileUpdateNotifier.notifyRegularUserProfileUpdate(updatedProfile);

    debugPrint(
      '[AuthIssueFixService] ✅ Regular user profile copied successfully',
    );
  }

  /// Get diagnostic information about current authentication state
  Future<Map<String, dynamic>> getAuthDiagnostics() async {
    final currentUser = _auth.currentUser;
    final diagnostics = <String, dynamic>{};

    if (currentUser == null) {
      diagnostics['error'] = 'No authenticated user';
      return diagnostics;
    }

    diagnostics['currentUser'] = {
      'uid': currentUser.uid,
      'email': currentUser.email,
      'phoneNumber': currentUser.phoneNumber,
      'displayName': currentUser.displayName,
      'providers': currentUser.providerData.map((p) => p.providerId).toList(),
    };

    // Check current UID profiles
    final hasVendor = await _checkVendorProfileExists(currentUser.uid);
    final hasRegular = await _checkRegularProfileExists(currentUser.uid);

    diagnostics['currentUidProfiles'] = {
      'hasVendorProfile': hasVendor,
      'hasRegularProfile': hasRegular,
    };

    // Search for profiles by contact info
    if (currentUser.phoneNumber != null) {
      final vendorByPhone = await _findVendorByPhone(currentUser.phoneNumber!);
      final regularByPhone = await _findRegularUserByPhone(
        currentUser.phoneNumber!,
      );

      diagnostics['profilesByPhone'] = {
        'vendorProfile': vendorByPhone?.toMap(),
        'regularProfile': regularByPhone?.toMap(),
      };
    }

    if (currentUser.email != null) {
      final vendorByEmail = await _findVendorByEmail(currentUser.email!);
      final regularByEmail = await _findRegularUserByEmail(currentUser.email!);

      diagnostics['profilesByEmail'] = {
        'vendorProfile': vendorByEmail?.toMap(),
        'regularProfile': regularByEmail?.toMap(),
      };
    }

    return diagnostics;
  }
}
