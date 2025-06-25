import 'package:hive/hive.dart';

part 'vendor_profile.g.dart';

/// Represents a vendor's profile data stored both locally in Hive and in Firestore.
/// This model handles offline-first vendor profile management.
@HiveType(typeId: 1)
class VendorProfile extends HiveObject {
  /// Firebase Auth UID of the vendor
  @HiveField(0)
  String uid;

  /// Display name of the vendor
  @HiveField(1)
  String displayName;

  /// Name of the vendor's market stall
  @HiveField(2)
  String stallName;

  /// City where the vendor's market is located
  @HiveField(3)
  String marketCity;

  /// URL to the vendor's avatar image (Firebase Storage URL)
  @HiveField(4)
  String? avatarURL;

  /// Whether the vendor allows location tagging on their snaps
  @HiveField(5)
  bool allowLocation;

  /// Local path to avatar image (before upload to Firebase)
  @HiveField(6)
  String? localAvatarPath;

  /// Whether the profile needs to be synced to Firestore
  @HiveField(7)
  bool needsSync;

  /// Last updated timestamp (stored as milliseconds since epoch)
  @HiveField(8)
  int lastUpdatedMillis;

  VendorProfile({
    required this.uid,
    required this.displayName,
    required this.stallName,
    required this.marketCity,
    this.avatarURL,
    this.allowLocation = false,
    this.localAvatarPath,
    this.needsSync = true,
    DateTime? lastUpdated,
  }) : lastUpdatedMillis = (lastUpdated ?? DateTime.now()).millisecondsSinceEpoch;

  /// Getter for lastUpdated as DateTime
  DateTime get lastUpdated => DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis);

  /// Creates a VendorProfile from Firestore document data
  factory VendorProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return VendorProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      stallName: data['stallName'] ?? '',
      marketCity: data['marketCity'] ?? '',
      avatarURL: data['avatarURL'],
      allowLocation: data['allowLocation'] ?? false,
      needsSync: false, // Data from Firestore is already synced
      lastUpdated: DateTime.now(),
    );
  }

  /// Converts VendorProfile to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'stallName': stallName,
      'marketCity': marketCity,
      'avatarURL': avatarURL,
      'allowLocation': allowLocation,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Creates a copy of this profile with updated fields
  VendorProfile copyWith({
    String? uid,
    String? displayName,
    String? stallName,
    String? marketCity,
    String? avatarURL,
    bool? allowLocation,
    String? localAvatarPath,
    bool? needsSync,
    DateTime? lastUpdated,
  }) {
    return VendorProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      stallName: stallName ?? this.stallName,
      marketCity: marketCity ?? this.marketCity,
      avatarURL: avatarURL ?? this.avatarURL,
      allowLocation: allowLocation ?? this.allowLocation,
      localAvatarPath: localAvatarPath ?? this.localAvatarPath,
      needsSync: needsSync ?? this.needsSync,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Returns true if the profile has all required fields filled
  bool get isComplete {
    return uid.isNotEmpty &&
           displayName.trim().isNotEmpty &&
           stallName.trim().isNotEmpty &&
           marketCity.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'VendorProfile(uid: $uid, displayName: $displayName, stallName: $stallName, marketCity: $marketCity, avatarURL: $avatarURL, allowLocation: $allowLocation, needsSync: $needsSync)';
  }
} 