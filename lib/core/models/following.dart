import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a following relationship between a user and a vendor.
class Following {
  /// Unique identifier for the following relationship
  final String followingId;

  /// UID of the user who is following
  final String followerUid;

  /// UID of the vendor being followed
  final String vendorUid;

  /// When the following relationship was created
  final DateTime createdAt;

  /// FCM token for push notifications (optional)
  final String? fcmToken;

  /// Whether notifications are enabled for this vendor
  final bool notificationsEnabled;

  /// Last time the follower viewed this vendor's snaps
  final DateTime? lastViewedAt;

  const Following({
    required this.followingId,
    required this.followerUid,
    required this.vendorUid,
    required this.createdAt,
    this.fcmToken,
    this.notificationsEnabled = true,
    this.lastViewedAt,
  });

  /// Creates a new following relationship
  factory Following.create({
    required String followerUid,
    required String vendorUid,
    String? fcmToken,
    bool notificationsEnabled = true,
  }) {
    final now = DateTime.now();
    
    return Following(
      followingId: '', // Will be set by Firestore
      followerUid: followerUid,
      vendorUid: vendorUid,
      createdAt: now,
      fcmToken: fcmToken,
      notificationsEnabled: notificationsEnabled,
      lastViewedAt: null,
    );
  }

  /// Creates a Following from Firestore document data
  factory Following.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Following(
      followingId: doc.id,
      followerUid: data['followerUid'] as String,
      vendorUid: data['vendorUid'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      fcmToken: data['fcmToken'] as String?,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      lastViewedAt: data['lastViewedAt'] != null
          ? (data['lastViewedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts Following to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'followerUid': followerUid,
      'vendorUid': vendorUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
      'notificationsEnabled': notificationsEnabled,
      'lastViewedAt': lastViewedAt != null
          ? Timestamp.fromDate(lastViewedAt!)
          : null,
    };
  }

  /// Creates a copy with updated fields
  Following copyWith({
    String? followingId,
    String? followerUid,
    String? vendorUid,
    DateTime? createdAt,
    String? fcmToken,
    bool? notificationsEnabled,
    DateTime? lastViewedAt,
  }) {
    return Following(
      followingId: followingId ?? this.followingId,
      followerUid: followerUid ?? this.followerUid,
      vendorUid: vendorUid ?? this.vendorUid,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
    );
  }

  /// Updates the last viewed timestamp
  Following markAsViewed() {
    return copyWith(lastViewedAt: DateTime.now());
  }

  /// Toggles notification settings
  Following toggleNotifications() {
    return copyWith(notificationsEnabled: !notificationsEnabled);
  }

  /// Updates the FCM token
  Following updateFcmToken(String newToken) {
    return copyWith(fcmToken: newToken);
  }

  /// Gets the duration since following
  Duration get followingDuration => DateTime.now().difference(createdAt);

  /// Gets the duration since last view (if available)
  Duration? get timeSinceLastView {
    if (lastViewedAt == null) return null;
    return DateTime.now().difference(lastViewedAt!);
  }

  /// Checks if this is a recent follow (within 24 hours)
  bool get isRecentFollow => followingDuration.inHours < 24;

  /// Checks if the follower has new content (hasn't viewed recently)
  bool get hasNewContent {
    if (lastViewedAt == null) return true;
    final timeSince = timeSinceLastView;
    return timeSince != null && timeSince.inHours > 1;
  }

  @override
  String toString() {
    return 'Following(id: $followingId, follower: $followerUid, vendor: $vendorUid, notifications: $notificationsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Following &&
        other.followingId == followingId &&
        other.followerUid == followerUid &&
        other.vendorUid == vendorUid &&
        other.createdAt == createdAt &&
        other.fcmToken == fcmToken &&
        other.notificationsEnabled == notificationsEnabled &&
        other.lastViewedAt == lastViewedAt;
  }

  @override
  int get hashCode {
    return followingId.hashCode ^
        followerUid.hashCode ^
        vendorUid.hashCode ^
        createdAt.hashCode ^
        fcmToken.hashCode ^
        notificationsEnabled.hashCode ^
        lastViewedAt.hashCode;
  }
}