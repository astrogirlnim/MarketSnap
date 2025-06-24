import 'package:hive/hive.dart';

part 'user_settings.g.dart';

/// Represents user-configurable settings stored locally.
/// This model is managed by Hive for offline persistence.
@HiveType(typeId: 0)
class UserSettings extends HiveObject {
  /// Whether the user has enabled coarse location tagging on their snaps.
  /// Corresponds to checklist item 4.4.
  @HiveField(0)
  bool enableCoarseLocation;

  /// Whether the app should automatically compress videos to save space and bandwidth.
  /// Corresponds to checklist item 4.4.
  @HiveField(1)
  bool autoCompressVideo;

  /// Whether to save a copy of posted media to the device's gallery by default.
  /// Corresponds to checklist item 4.4.
  @HiveField(2)
  bool saveToDeviceDefault;

  UserSettings({
    this.enableCoarseLocation = false,
    this.autoCompressVideo = true,
    this.saveToDeviceDefault = false,
  });

  @override
  String toString() {
    return 'UserSettings(enableCoarseLocation: $enableCoarseLocation, autoCompressVideo: $autoCompressVideo, saveToDeviceDefault: $saveToDeviceDefault)';
  }
} 