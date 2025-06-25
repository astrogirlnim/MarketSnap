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

  /// Phone number for account linking and contact
  @HiveField(9)
  String? phoneNumber;

  /// Email address for account linking and contact
  @HiveField(10)
  String? email;

  VendorProfile({
    required this.uid,
    required this.displayName,
    required this.stallName,
    required this.marketCity,
    this.avatarURL,
    this.allowLocation = false,
    this.localAvatarPath,
    this.needsSync = true,
    this.phoneNumber,
    this.email,
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
      phoneNumber: data['phoneNumber'],
      email: data['email'],
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
      'phoneNumber': phoneNumber,
      'email': email,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Converts VendorProfile to a Map for general use
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'stallName': stallName,
      'marketCity': marketCity,
      'avatarURL': avatarURL,
      'allowLocation': allowLocation,
      'phoneNumber': phoneNumber,
      'email': email,
      'needsSync': needsSync,
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
    String? phoneNumber,
    String? email,
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
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
    return 'VendorProfile(uid: $uid, displayName: $displayName, stallName: $stallName, marketCity: $marketCity, phoneNumber: $phoneNumber, email: $email, avatarURL: $avatarURL, allowLocation: $allowLocation, needsSync: $needsSync)';
  }
} 