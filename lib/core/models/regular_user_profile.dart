import 'package:hive/hive.dart';

part 'regular_user_profile.g.dart';

/// Represents a regular user's profile data stored both locally in Hive and in Firestore.
/// Regular users have a simpler profile compared to vendors.
@HiveType(typeId: 4)
class RegularUserProfile extends HiveObject {
  /// Firebase Auth UID of the user
  @HiveField(0)
  String uid;

  /// Display name of the user
  @HiveField(1)
  String displayName;

  /// URL to the user's avatar image (Firebase Storage URL)
  @HiveField(2)
  String? avatarURL;

  /// Local path to avatar image (before upload to Firebase)
  @HiveField(3)
  String? localAvatarPath;

  /// Whether the profile needs to be synced to Firestore
  @HiveField(4)
  bool needsSync;

  /// Last updated timestamp (stored as milliseconds since epoch)
  @HiveField(5)
  int lastUpdatedMillis;

  /// Phone number for account linking and contact
  @HiveField(6)
  String? phoneNumber;

  /// Email address for account linking and contact
  @HiveField(7)
  String? email;

  RegularUserProfile({
    required this.uid,
    required this.displayName,
    this.avatarURL,
    this.localAvatarPath,
    this.needsSync = true,
    this.phoneNumber,
    this.email,
    DateTime? lastUpdated,
  }) : lastUpdatedMillis =
           (lastUpdated ?? DateTime.now()).millisecondsSinceEpoch;

  /// Getter for lastUpdated as DateTime
  DateTime get lastUpdated =>
      DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis);

  /// Creates a RegularUserProfile from Firestore document data
  factory RegularUserProfile.fromFirestore(
    Map<String, dynamic> data,
    String uid,
  ) {
    return RegularUserProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      avatarURL: data['avatarURL'],
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      needsSync: false, // Data from Firestore is already synced
      lastUpdated: DateTime.now(),
    );
  }

  /// Converts RegularUserProfile to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'avatarURL': avatarURL,
      'phoneNumber': phoneNumber,
      'email': email,
      'userType': 'regular', // Explicitly mark as regular user
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Converts RegularUserProfile to a Map for general use
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarURL': avatarURL,
      'phoneNumber': phoneNumber,
      'email': email,
      'needsSync': needsSync,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Creates a copy of this profile with updated fields
  RegularUserProfile copyWith({
    String? uid,
    String? displayName,
    String? avatarURL,
    String? localAvatarPath,
    bool? needsSync,
    String? phoneNumber,
    String? email,
    DateTime? lastUpdated,
  }) {
    return RegularUserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarURL: avatarURL ?? this.avatarURL,
      localAvatarPath: localAvatarPath ?? this.localAvatarPath,
      needsSync: needsSync ?? this.needsSync,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Returns true if the profile has all required fields filled
  bool get isComplete {
    return uid.isNotEmpty && displayName.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'RegularUserProfile(uid: $uid, displayName: $displayName, phoneNumber: $phoneNumber, email: $email, avatarURL: $avatarURL, needsSync: $needsSync)';
  }
}
