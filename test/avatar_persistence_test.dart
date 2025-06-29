import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../lib/features/profile/application/profile_service.dart';
import '../lib/core/services/hive_service.dart';
import '../lib/core/services/profile_update_notifier.dart';
import '../lib/core/models/vendor_profile.dart';
import '../lib/core/models/regular_user_profile.dart';

// Mock classes
class MockHiveService extends Mock implements HiveService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockImagePicker extends Mock implements ImagePicker {}
class MockUser extends Mock implements User {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockReference extends Mock implements Reference {}
class MockUploadTask extends Mock implements UploadTask {}
class MockTaskSnapshot extends Mock implements TaskSnapshot {}

void main() {
  group('Avatar Persistence Bug Fix Tests', () {
    late ProfileService profileService;
    late MockHiveService mockHiveService;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseStorage mockStorage;
    late MockFirebaseAuth mockAuth;
    late MockImagePicker mockImagePicker;
    late ProfileUpdateNotifier profileUpdateNotifier;
    late MockUser mockUser;

    setUp(() {
      mockHiveService = MockHiveService();
      mockFirestore = MockFirebaseFirestore();
      mockStorage = MockFirebaseStorage();
      mockAuth = MockFirebaseAuth();
      mockImagePicker = MockImagePicker();
      profileUpdateNotifier = ProfileUpdateNotifier();
      mockUser = MockUser();

      // Setup auth mock
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-user-123');

      profileService = ProfileService(
        hiveService: mockHiveService,
        firestore: mockFirestore,
        storage: mockStorage,
        auth: mockAuth,
        imagePicker: mockImagePicker,
        profileUpdateNotifier: profileUpdateNotifier,
      );
    });

    group('Vendor Profile Avatar Persistence', () {
      test('should preserve existing avatar URL when updating profile without new avatar', () async {
        // Arrange
        final existingProfile = VendorProfile(
          uid: 'test-user-123',
          displayName: 'Old Name',
          stallName: 'Old Stall',
          marketCity: 'Old City',
          avatarURL: 'https://example.com/old-avatar.jpg',
          needsSync: false,
        );

        when(mockHiveService.getVendorProfile('test-user-123'))
            .thenReturn(existingProfile);
        when(mockHiveService.saveVendorProfile(any))
            .thenAnswer((_) async {});

        // Mock Firestore operations
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        when(mockFirestore.collection('vendors')).thenReturn(mockCollection);
        when(mockCollection.doc('test-user-123')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {});

        // Act - Update profile without changing avatar
        await profileService.saveProfile(
          displayName: 'New Name',
          stallName: 'New Stall',
          marketCity: 'New City',
          allowLocation: false,
          localAvatarPath: null, // No new avatar
        );

        // Assert - Verify avatar URL is preserved
        final captured = verify(mockHiveService.saveVendorProfile(captureAny))
            .captured;
        final savedProfile = captured.first as VendorProfile;

        expect(savedProfile.avatarURL, equals('https://example.com/old-avatar.jpg'));
        expect(savedProfile.localAvatarPath, isNull);
        expect(savedProfile.displayName, equals('New Name'));
        expect(savedProfile.needsSync, isTrue);
      });

      test('should clear avatar URL when new local avatar is provided', () async {
        // Arrange
        final existingProfile = VendorProfile(
          uid: 'test-user-123',
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          avatarURL: 'https://example.com/old-avatar.jpg',
          needsSync: false,
        );

        when(mockHiveService.getVendorProfile('test-user-123'))
            .thenReturn(existingProfile);
        when(mockHiveService.saveVendorProfile(any))
            .thenAnswer((_) async {});

        // Mock storage upload
        final mockRef = MockReference();
        final mockUploadTask = MockUploadTask();
        final mockSnapshot = MockTaskSnapshot();
        
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child('vendors/test-user-123/avatar.jpg')).thenReturn(mockRef);
        when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
        when(mockUploadTask.then(any)).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.ref).thenReturn(mockRef);
        when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://example.com/new-avatar.jpg');

        // Mock Firestore operations
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        when(mockFirestore.collection('vendors')).thenReturn(mockCollection);
        when(mockCollection.doc('test-user-123')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {});

        // Act - Update profile with new avatar
        await profileService.saveProfile(
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          allowLocation: false,
          localAvatarPath: '/path/to/new/avatar.jpg',
        );

        // Assert - Verify old URL is cleared and local path is set
        final captured = verify(mockHiveService.saveVendorProfile(captureAny))
            .captured;
        final savedProfile = captured.first as VendorProfile;

        expect(savedProfile.avatarURL, isNull); // Should be cleared
        expect(savedProfile.localAvatarPath, equals('/path/to/new/avatar.jpg'));
        expect(savedProfile.needsSync, isTrue);
      });

      test('should handle sync completion correctly', () async {
        // Arrange
        const uid = 'test-user-123';
        final initialProfile = VendorProfile(
          uid: uid,
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          needsSync: true,
        );

        final syncedProfile = initialProfile.copyWith(needsSync: false);

        // First call returns profile needing sync, second call returns synced profile
        when(mockHiveService.getVendorProfile(uid))
            .thenReturnOnMockitoWhen(initialProfile)
            .thenReturnOnMockitoWhen(syncedProfile);

        // Act
        final result = await profileService.waitForSyncCompletion(uid, timeout: Duration(seconds: 5));

        // Assert
        expect(result, isTrue);
        verify(mockHiveService.getVendorProfile(uid)).called(greaterThan(1));
      });

      test('should timeout if sync takes too long', () async {
        // Arrange
        const uid = 'test-user-123';
        final profileNeedingSync = VendorProfile(
          uid: uid,
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          needsSync: true, // Always needs sync
        );

        when(mockHiveService.getVendorProfile(uid)).thenReturn(profileNeedingSync);

        // Act
        final result = await profileService.waitForSyncCompletion(uid, timeout: Duration(milliseconds: 200));

        // Assert
        expect(result, isFalse);
      });
    });

    group('Regular User Profile Avatar Persistence', () {
      test('should preserve existing avatar URL when updating regular user profile without new avatar', () async {
        // Arrange
        final existingProfile = RegularUserProfile(
          uid: 'test-user-123',
          displayName: 'Old Name',
          avatarURL: 'https://example.com/old-avatar.jpg',
          needsSync: false,
        );

        when(mockHiveService.getRegularUserProfile('test-user-123'))
            .thenReturn(existingProfile);
        when(mockHiveService.saveRegularUserProfile(any))
            .thenAnswer((_) async {});

        // Mock Firestore operations
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        when(mockFirestore.collection('regularUsers')).thenReturn(mockCollection);
        when(mockCollection.doc('test-user-123')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {});

        // Act - Update profile without changing avatar
        await profileService.saveRegularUserProfile(
          displayName: 'New Name',
          localAvatarPath: null, // No new avatar
        );

        // Assert - Verify avatar URL is preserved
        final captured = verify(mockHiveService.saveRegularUserProfile(captureAny))
            .captured;
        final savedProfile = captured.first as RegularUserProfile;

        expect(savedProfile.avatarURL, equals('https://example.com/old-avatar.jpg'));
        expect(savedProfile.localAvatarPath, isNull);
        expect(savedProfile.displayName, equals('New Name'));
        expect(savedProfile.needsSync, isTrue);
      });

      test('should clear avatar URL when new local avatar is provided for regular user', () async {
        // Arrange
        final existingProfile = RegularUserProfile(
          uid: 'test-user-123',
          displayName: 'Test User',
          avatarURL: 'https://example.com/old-avatar.jpg',
          needsSync: false,
        );

        when(mockHiveService.getRegularUserProfile('test-user-123'))
            .thenReturn(existingProfile);
        when(mockHiveService.saveRegularUserProfile(any))
            .thenAnswer((_) async {});

        // Mock storage upload for regular users
        final mockRef = MockReference();
        final mockUploadTask = MockUploadTask();
        final mockSnapshot = MockTaskSnapshot();
        
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child('regularUsers/test-user-123/avatar.jpg')).thenReturn(mockRef);
        when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
        when(mockUploadTask.then(any)).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.ref).thenReturn(mockRef);
        when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://example.com/new-avatar.jpg');

        // Mock Firestore operations
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        when(mockFirestore.collection('regularUsers')).thenReturn(mockCollection);
        when(mockCollection.doc('test-user-123')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {});

        // Act - Update profile with new avatar
        await profileService.saveRegularUserProfile(
          displayName: 'Test User',
          localAvatarPath: '/path/to/new/avatar.jpg',
        );

        // Assert - Verify old URL is cleared and local path is set
        final captured = verify(mockHiveService.saveRegularUserProfile(captureAny))
            .captured;
        final savedProfile = captured.first as RegularUserProfile;

        expect(savedProfile.avatarURL, isNull); // Should be cleared
        expect(savedProfile.localAvatarPath, equals('/path/to/new/avatar.jpg'));
        expect(savedProfile.needsSync, isTrue);
      });
    });

    group('Profile Update Notifications', () {
      test('should broadcast profile updates when profile is saved', () async {
        // Arrange
        bool updateReceived = false;
        VendorProfile? receivedProfile;

        profileUpdateNotifier.vendorProfileUpdates.listen((profile) {
          updateReceived = true;
          receivedProfile = profile;
        });

        when(mockHiveService.getVendorProfile('test-user-123')).thenReturn(null);
        when(mockHiveService.saveVendorProfile(any)).thenAnswer((_) async {});

        // Act
        await profileService.saveProfile(
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          allowLocation: false,
        );

        // Allow async operations to complete
        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(updateReceived, isTrue);
        expect(receivedProfile, isNotNull);
        expect(receivedProfile!.displayName, equals('Test User'));
      });

      test('should broadcast regular user profile updates when profile is saved', () async {
        // Arrange
        bool updateReceived = false;
        RegularUserProfile? receivedProfile;

        profileUpdateNotifier.regularUserProfileUpdates.listen((profile) {
          updateReceived = true;
          receivedProfile = profile;
        });

        when(mockHiveService.getRegularUserProfile('test-user-123')).thenReturn(null);
        when(mockHiveService.saveRegularUserProfile(any)).thenAnswer((_) async {});

        // Act
        await profileService.saveRegularUserProfile(
          displayName: 'Test User',
        );

        // Allow async operations to complete
        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(updateReceived, isTrue);
        expect(receivedProfile, isNotNull);
        expect(receivedProfile!.displayName, equals('Test User'));
      });
    });

    group('Error Handling', () {
      test('should handle avatar upload errors gracefully', () async {
        // Arrange
        when(mockHiveService.getVendorProfile('test-user-123')).thenReturn(null);
        when(mockHiveService.saveVendorProfile(any)).thenAnswer((_) async {});

        // Mock storage upload failure
        final mockRef = MockReference();
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child('vendors/test-user-123/avatar.jpg')).thenReturn(mockRef);
        when(mockRef.putFile(any, any)).thenThrow(Exception('Upload failed'));

        // Act & Assert
        expect(
          () => profileService.saveProfile(
            displayName: 'Test User',
            stallName: 'Test Stall',
            marketCity: 'Test City',
            allowLocation: false,
            localAvatarPath: '/path/to/avatar.jpg',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should save profile locally even if sync fails', () async {
        // Arrange
        when(mockHiveService.getVendorProfile('test-user-123')).thenReturn(null);
        when(mockHiveService.saveVendorProfile(any)).thenAnswer((_) async {});

        // Mock Firestore failure
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        when(mockFirestore.collection('vendors')).thenReturn(mockCollection);
        when(mockCollection.doc('test-user-123')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenThrow(Exception('Firestore error'));

        // Act - Should not throw despite sync failure
        await profileService.saveProfile(
          displayName: 'Test User',
          stallName: 'Test Stall',
          marketCity: 'Test City',
          allowLocation: false,
        );

        // Assert - Profile should still be saved locally
        verify(mockHiveService.saveVendorProfile(any)).called(1);
      });
    });
  });
}

// Extension to help with mockito when chaining
extension on PostExpectation {
  PostExpectation thenReturnOnMockitoWhen(dynamic value) {
    return thenReturn(value);
  }
} 