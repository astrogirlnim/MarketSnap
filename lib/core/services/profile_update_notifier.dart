import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vendor_profile.dart';
import '../models/regular_user_profile.dart';

/// Service for broadcasting profile updates across the application
/// Uses streams to notify components when user profiles change
class ProfileUpdateNotifier {
  static final ProfileUpdateNotifier _instance =
      ProfileUpdateNotifier._internal();
  factory ProfileUpdateNotifier() => _instance;
  ProfileUpdateNotifier._internal();

  // Stream controllers for different types of profile updates
  final StreamController<VendorProfile> _vendorProfileUpdateController =
      StreamController<VendorProfile>.broadcast();
  final StreamController<RegularUserProfile>
  _regularUserProfileUpdateController =
      StreamController<RegularUserProfile>.broadcast();
  final StreamController<String> _profileDeleteController =
      StreamController<String>.broadcast();

  // Streams for components to listen to
  Stream<VendorProfile> get vendorProfileUpdates =>
      _vendorProfileUpdateController.stream;
  Stream<RegularUserProfile> get regularUserProfileUpdates =>
      _regularUserProfileUpdateController.stream;
  Stream<String> get profileDeletes => _profileDeleteController.stream;

  /// Notify all listeners that a vendor profile has been updated
  void notifyVendorProfileUpdate(VendorProfile profile) {
    debugPrint(
      '[ProfileUpdateNotifier] 📢 Broadcasting vendor profile update for: ${profile.displayName} (${profile.uid})',
    );
    _vendorProfileUpdateController.add(profile);
  }

  /// Notify all listeners that a regular user profile has been updated
  void notifyRegularUserProfileUpdate(RegularUserProfile profile) {
    debugPrint(
      '[ProfileUpdateNotifier] 📢 Broadcasting regular user profile update for: ${profile.displayName} (${profile.uid})',
    );
    _regularUserProfileUpdateController.add(profile);
  }

  /// Notify all listeners that a profile has been deleted
  void notifyProfileDelete(String uid) {
    debugPrint(
      '[ProfileUpdateNotifier] 📢 Broadcasting profile deletion for UID: $uid',
    );
    _profileDeleteController.add(uid);
  }

  /// Combined stream for any profile update (vendor or regular user)
  Stream<Map<String, dynamic>> get allProfileUpdates async* {
    await for (final update in StreamGroup.merge([
      vendorProfileUpdates.map(
        (profile) => {
          'type': 'vendor',
          'profile': profile,
          'uid': profile.uid,
          'displayName': profile.displayName,
          'avatarURL': profile.avatarURL,
        },
      ),
      regularUserProfileUpdates.map(
        (profile) => {
          'type': 'regular',
          'profile': profile,
          'uid': profile.uid,
          'displayName': profile.displayName,
          'avatarURL': profile.avatarURL,
        },
      ),
      profileDeletes.map((uid) => {'type': 'delete', 'uid': uid}),
    ])) {
      yield update;
    }
  }

  /// Dispose of stream controllers when no longer needed
  void dispose() {
    debugPrint('[ProfileUpdateNotifier] 🗑️ Disposing profile update notifier');
    _vendorProfileUpdateController.close();
    _regularUserProfileUpdateController.close();
    _profileDeleteController.close();
  }
}

// Stream helper for merging multiple streams
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subscriptions = <StreamSubscription>[];

    for (final stream in streams) {
      subscriptions.add(
        stream.listen(controller.add, onError: controller.addError),
      );
    }

    // Close controller when all streams are done
    bool allDone = false;
    void checkAllDone() {
      if (!allDone && subscriptions.every((s) => s.isPaused)) {
        allDone = true;
        controller.close();
      }
    }

    for (final subscription in subscriptions) {
      subscription.onDone(checkAllDone);
    }

    return controller.stream;
  }
}
