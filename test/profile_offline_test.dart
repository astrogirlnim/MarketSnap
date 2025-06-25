import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/services/hive_service.dart';
import 'package:marketsnap/core/services/secure_storage_service.dart';

/// Mock path provider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/tmp/test_documents';
  }
}

/// Mock secure storage service for testing
class MockSecureStorageService implements SecureStorageService {
  final List<int> _mockKey = List.generate(32, (index) => index); // Mock 256-bit key

  @override
  Future<List<int>> getHiveEncryptionKey() async {
    return _mockKey;
  }

  @override
  Future<void> deleteHiveEncryptionKey() async {
    // Mock implementation - do nothing
  }
}

void main() {
  group('Vendor Profile Offline Caching Tests', () {
    late HiveService hiveService;
    late MockSecureStorageService mockSecureStorage;

    setUpAll(() async {
      // Set up mock path provider
      PathProviderPlatform.instance = MockPathProviderPlatform();
      
      // Initialize Hive for testing in unique directory
      await Hive.initFlutter('/tmp/test_hive_profile');
      
      // Clear any existing test boxes
      await Hive.deleteBoxFromDisk('test_vendorProfile');
      await Hive.deleteBoxFromDisk('test_userSettings');
      await Hive.deleteBoxFromDisk('test_pendingMediaQueue');
    });

    setUp(() async {
      // Clear any registered adapters before each test
      Hive.resetAdapters();
      
      mockSecureStorage = MockSecureStorageService();
      hiveService = HiveService(mockSecureStorage);
      
      // Initialize HiveService for this test
      await hiveService.init();
    });

    tearDown(() async {
      await hiveService.close();
      
      // Clean up test boxes
      try {
        await Hive.deleteBoxFromDisk('vendorProfile');
        await Hive.deleteBoxFromDisk('userSettings');
        await Hive.deleteBoxFromDisk('pendingMediaQueue');
      } catch (e) {
        // Ignore errors if boxes don't exist
      }
    });

    tearDownAll(() async {
      await Hive.close();
    });

    test('should save vendor profile to local storage', () async {
      // Arrange
      const uid = 'test_user_123';
      final profile = VendorProfile(
        uid: uid,
        displayName: 'John Farmer',
        stallName: 'Fresh Valley Produce',
        marketCity: 'Springfield',
        allowLocation: true,
      );

      // Act
      await hiveService.saveVendorProfile(profile);

      // Assert
      final retrievedProfile = hiveService.getVendorProfile(uid);
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.uid, equals(uid));
      expect(retrievedProfile.displayName, equals('John Farmer'));
      expect(retrievedProfile.stallName, equals('Fresh Valley Produce'));
      expect(retrievedProfile.marketCity, equals('Springfield'));
      expect(retrievedProfile.allowLocation, equals(true));
      expect(retrievedProfile.needsSync, equals(true));
    });

    test('should persist vendor profile across app restarts', () async {
      // Arrange
      const uid = 'test_user_456';
      final profile = VendorProfile(
        uid: uid,
        displayName: 'Jane Market',
        stallName: 'Organic Delights',
        marketCity: 'Shelbyville',
        avatarURL: 'https://example.com/avatar.jpg',
        allowLocation: false,
      );

      // Act - Save profile
      await hiveService.saveVendorProfile(profile);
      
      // Simulate app restart by closing and reopening Hive
      await hiveService.close();
      
      // Reinitialize HiveService (simulating app restart)
      final newHiveService = HiveService(mockSecureStorage);
      await newHiveService.init();

      // Assert - Profile should still be available
      final retrievedProfile = newHiveService.getVendorProfile(uid);
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.displayName, equals('Jane Market'));
      expect(retrievedProfile.stallName, equals('Organic Delights'));
      expect(retrievedProfile.marketCity, equals('Shelbyville'));
      expect(retrievedProfile.avatarURL, equals('https://example.com/avatar.jpg'));
      expect(retrievedProfile.allowLocation, equals(false));

      await newHiveService.close();
    });

    test('should update existing vendor profile', () async {
      // Arrange
      const uid = 'test_user_789';
      final initialProfile = VendorProfile(
        uid: uid,
        displayName: 'Bob Farmer',
        stallName: 'Old Farm Stand',
        marketCity: 'Capital City',
      );

      // Act - Save initial profile
      await hiveService.saveVendorProfile(initialProfile);
      
      // Update profile
      final updatedProfile = initialProfile.copyWith(
        stallName: 'New Farm Stand',
        avatarURL: 'https://example.com/new_avatar.jpg',
        allowLocation: true,
      );
      await hiveService.saveVendorProfile(updatedProfile);

      // Assert - Profile should be updated
      final retrievedProfile = hiveService.getVendorProfile(uid);
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.stallName, equals('New Farm Stand'));
      expect(retrievedProfile.avatarURL, equals('https://example.com/new_avatar.jpg'));
      expect(retrievedProfile.allowLocation, equals(true));
      expect(retrievedProfile.displayName, equals('Bob Farmer')); // Unchanged
      expect(retrievedProfile.marketCity, equals('Capital City')); // Unchanged
    });

    test('should handle multiple vendor profiles', () async {
      // Arrange
      final profiles = [
        VendorProfile(
          uid: 'user_1',
          displayName: 'Alice',
          stallName: 'Alice\'s Apples',
          marketCity: 'Town A',
        ),
        VendorProfile(
          uid: 'user_2',
          displayName: 'Bob',
          stallName: 'Bob\'s Berries',
          marketCity: 'Town B',
        ),
        VendorProfile(
          uid: 'user_3',
          displayName: 'Carol',
          stallName: 'Carol\'s Carrots',
          marketCity: 'Town C',
        ),
      ];

      // Act - Save all profiles
      for (final profile in profiles) {
        await hiveService.saveVendorProfile(profile);
      }

      // Assert - All profiles should be retrievable
      for (final originalProfile in profiles) {
        final retrievedProfile = hiveService.getVendorProfile(originalProfile.uid);
        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile!.uid, equals(originalProfile.uid));
        expect(retrievedProfile.stallName, equals(originalProfile.stallName));
      }
    });

    test('should track sync status correctly', () async {
      // Arrange
      const uid = 'test_sync_user';
      final profile = VendorProfile(
        uid: uid,
        displayName: 'Sync Test',
        stallName: 'Sync Test Stand',
        marketCity: 'Sync City',
        needsSync: true,
      );

      // Act - Save profile (should need sync)
      await hiveService.saveVendorProfile(profile);
      
      // Assert - Profile should need sync
      final profilesNeedingSync = hiveService.getProfilesNeedingSync();
      expect(profilesNeedingSync.length, equals(1));
      expect(profilesNeedingSync.first.uid, equals(uid));

      // Act - Mark as synced
      await hiveService.markProfileAsSynced(uid);

      // Assert - Profile should no longer need sync
      final updatedProfilesNeedingSync = hiveService.getProfilesNeedingSync();
      expect(updatedProfilesNeedingSync.length, equals(0));

      final syncedProfile = hiveService.getVendorProfile(uid);
      expect(syncedProfile!.needsSync, equals(false));
    });

    test('should validate profile completeness', () async {
      // Arrange & Act & Assert - Complete profile
      const completeUid = 'complete_user';
      final completeProfile = VendorProfile(
        uid: completeUid,
        displayName: 'Complete User',
        stallName: 'Complete Stand',
        marketCity: 'Complete City',
      );
      await hiveService.saveVendorProfile(completeProfile);
      expect(hiveService.hasCompleteVendorProfile(completeUid), equals(true));

      // Arrange & Act & Assert - Incomplete profile (missing stall name)
      const incompleteUid = 'incomplete_user';
      final incompleteProfile = VendorProfile(
        uid: incompleteUid,
        displayName: 'Incomplete User',
        stallName: '', // Empty stall name
        marketCity: 'Incomplete City',
      );
      await hiveService.saveVendorProfile(incompleteProfile);
      expect(hiveService.hasCompleteVendorProfile(incompleteUid), equals(false));
    });

    test('should handle profile deletion', () async {
      // Arrange
      const uid = 'delete_test_user';
      final profile = VendorProfile(
        uid: uid,
        displayName: 'Delete Test',
        stallName: 'Delete Test Stand',
        marketCity: 'Delete City',
      );

      // Act - Save then delete
      await hiveService.saveVendorProfile(profile);
      expect(hiveService.getVendorProfile(uid), isNotNull);
      
      await hiveService.deleteVendorProfile(uid);

      // Assert - Profile should be deleted
      expect(hiveService.getVendorProfile(uid), isNull);
      expect(hiveService.hasCompleteVendorProfile(uid), equals(false));
    });

    test('should handle non-existent profile gracefully', () async {
      // Arrange
      const nonExistentUid = 'non_existent_user';

      // Act & Assert
      expect(hiveService.getVendorProfile(nonExistentUid), isNull);
      expect(hiveService.hasCompleteVendorProfile(nonExistentUid), equals(false));
      
      // Should not throw when marking non-existent profile as synced
      await hiveService.markProfileAsSynced(nonExistentUid);
      
      // Should not throw when deleting non-existent profile
      await hiveService.deleteVendorProfile(nonExistentUid);
    });

    test('should preserve all profile fields through storage cycle', () async {
      // Arrange
      const uid = 'full_fields_user';
      final now = DateTime.now();
      final profile = VendorProfile(
        uid: uid,
        displayName: 'Full Fields User',
        stallName: 'Full Fields Stand',
        marketCity: 'Full Fields City',
        avatarURL: 'https://example.com/avatar.jpg',
        allowLocation: true,
        localAvatarPath: '/local/path/avatar.jpg',
        needsSync: false,
        lastUpdated: now,
      );

      // Act
      await hiveService.saveVendorProfile(profile);
      final retrievedProfile = hiveService.getVendorProfile(uid);

      // Assert - All fields should be preserved
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.uid, equals(uid));
      expect(retrievedProfile.displayName, equals('Full Fields User'));
      expect(retrievedProfile.stallName, equals('Full Fields Stand'));
      expect(retrievedProfile.marketCity, equals('Full Fields City'));
      expect(retrievedProfile.avatarURL, equals('https://example.com/avatar.jpg'));
      expect(retrievedProfile.allowLocation, equals(true));
      expect(retrievedProfile.localAvatarPath, equals('/local/path/avatar.jpg'));
      expect(retrievedProfile.needsSync, equals(false));
      // Note: DateTime comparison might have slight precision differences
      expect(retrievedProfile.lastUpdated.difference(now).inMilliseconds.abs(), lessThan(1000));
    });
  });
} 