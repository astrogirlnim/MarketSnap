import 'package:flutter_test/flutter_test.dart';
import 'package:marketsnap/core/models/user_settings.dart';
import 'package:marketsnap/core/services/secure_storage_service.dart';

// Mock SecureStorageService for testing
class MockSecureStorageService extends SecureStorageService {
  @override
  Future<List<int>> getHiveEncryptionKey() async {
    return List.generate(32, (index) => index);
  }
}

void main() {
  group('UserSettings Posting Preference Tests', () {
    test('should default to feed posting preference (false)', () {
      final settings = UserSettings();
      expect(
        settings.preferStoryPosting,
        false,
        reason: 'Default posting preference should be feed (false)',
      );
    });

    test('should create UserSettings with story posting preference', () {
      final settings = UserSettings(preferStoryPosting: true);
      expect(
        settings.preferStoryPosting,
        true,
        reason: 'Should be able to create UserSettings with story preference',
      );
    });

    test(
      'should create UserSettings with all fields including posting preference',
      () {
        final settings = UserSettings(
          enableCoarseLocation: true,
          autoCompressVideo: false,
          saveToDeviceDefault: true,
          preferStoryPosting: true,
        );

        expect(settings.enableCoarseLocation, true);
        expect(settings.autoCompressVideo, false);
        expect(settings.saveToDeviceDefault, true);
        expect(settings.preferStoryPosting, true);
      },
    );

    test('should include posting preference in toString output', () {
      final settings = UserSettings(preferStoryPosting: true);
      final stringOutput = settings.toString();

      expect(
        stringOutput.contains('preferStoryPosting: true'),
        true,
        reason: 'toString should include preferStoryPosting field',
      );
    });

    test('should maintain separate values for different preferences', () {
      final feedSettings = UserSettings(preferStoryPosting: false);
      final storySettings = UserSettings(preferStoryPosting: true);

      expect(feedSettings.preferStoryPosting, false);
      expect(storySettings.preferStoryPosting, true);
      expect(
        feedSettings.preferStoryPosting != storySettings.preferStoryPosting,
        true,
        reason:
            'Different instances should maintain separate preference values',
      );
    });
  });

  group('UserSettings Integration Tests', () {
    test(
      'should maintain default values for other fields when setting posting preference',
      () {
        final settings = UserSettings(preferStoryPosting: true);

        // Verify other fields maintain their defaults
        expect(
          settings.enableCoarseLocation,
          false,
          reason: 'Default should be maintained',
        );
        expect(
          settings.autoCompressVideo,
          true,
          reason: 'Default should be maintained',
        );
        expect(
          settings.saveToDeviceDefault,
          false,
          reason: 'Default should be maintained',
        );
        expect(
          settings.preferStoryPosting,
          true,
          reason: 'Specified value should be set',
        );
      },
    );
  });

  group('Story vs Feed Logic Simulation', () {
    test('should simulate MediaReviewScreen posting choice logic', () {
      // Simulate the logic that would happen in MediaReviewScreen

      // User starts with default settings (feed preference)
      var userSettings = UserSettings();
      var postToStory = userSettings.preferStoryPosting; // false
      expect(postToStory, false, reason: 'Should start with feed preference');

      // User changes to story posting
      userSettings = UserSettings(
        enableCoarseLocation: userSettings.enableCoarseLocation,
        autoCompressVideo: userSettings.autoCompressVideo,
        saveToDeviceDefault: userSettings.saveToDeviceDefault,
        preferStoryPosting: true, // User chose stories
      );
      postToStory = userSettings.preferStoryPosting; // true
      expect(postToStory, true, reason: 'Should update to story preference');

      // Next session should remember the story preference
      var nextSessionSettings = UserSettings(
        enableCoarseLocation: userSettings.enableCoarseLocation,
        autoCompressVideo: userSettings.autoCompressVideo,
        saveToDeviceDefault: userSettings.saveToDeviceDefault,
        preferStoryPosting:
            userSettings.preferStoryPosting, // Persisted from previous session
      );
      var nextSessionPostToStory = nextSessionSettings.preferStoryPosting;
      expect(
        nextSessionPostToStory,
        true,
        reason: 'Next session should remember story preference',
      );
    });
  });
}
