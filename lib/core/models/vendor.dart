import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a farmer's market vendor profile.
class Vendor {
  /// Unique identifier for the vendor (matches Firebase Auth UID)
  final String vendorId;

  /// Display name of the vendor's stall
  final String stallName;

  /// Market name or city where the vendor operates
  final String marketCity;

  /// Vendor's profile/avatar image URL
  final String? avatarUrl;

  /// Optional bio or description
  final String? bio;

  /// Vendor's specialty or main products
  final String? specialty;

  /// Contact phone number (optional)
  final String? phoneNumber;

  /// Contact email (optional)
  final String? email;

  /// When the vendor profile was created
  final DateTime createdAt;

  /// When the vendor profile was last updated
  final DateTime updatedAt;

  /// Whether the vendor is currently active/verified
  final bool isActive;

  /// Number of followers
  final int followerCount;

  /// Number of snaps posted
  final int snapCount;

  /// Location data for the market (optional)
  final Map<String, dynamic>? marketLocation;

  /// Operating hours or schedule
  final Map<String, dynamic>? schedule;

  const Vendor({
    required this.vendorId,
    required this.stallName,
    required this.marketCity,
    this.avatarUrl,
    this.bio,
    this.specialty,
    this.phoneNumber,
    this.email,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.followerCount = 0,
    this.snapCount = 0,
    this.marketLocation,
    this.schedule,
  });

  /// Creates a new vendor profile
  factory Vendor.create({
    required String vendorId,
    required String stallName,
    required String marketCity,
    String? avatarUrl,
    String? bio,
    String? specialty,
    String? phoneNumber,
    String? email,
    bool isActive = true,
    Map<String, dynamic>? marketLocation,
    Map<String, dynamic>? schedule,
  }) {
    final now = DateTime.now();
    
    return Vendor(
      vendorId: vendorId,
      stallName: stallName,
      marketCity: marketCity,
      avatarUrl: avatarUrl,
      bio: bio,
      specialty: specialty,
      phoneNumber: phoneNumber,
      email: email,
      createdAt: now,
      updatedAt: now,
      isActive: isActive,
      followerCount: 0,
      snapCount: 0,
      marketLocation: marketLocation,
      schedule: schedule,
    );
  }

  /// Creates a Vendor from Firestore document data
  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Vendor(
      vendorId: doc.id,
      stallName: data['stallName'] as String,
      marketCity: data['marketCity'] as String,
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      specialty: data['specialty'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool? ?? true,
      followerCount: data['followerCount'] as int? ?? 0,
      snapCount: data['snapCount'] as int? ?? 0,
      marketLocation: data['marketLocation'] as Map<String, dynamic>?,
      schedule: data['schedule'] as Map<String, dynamic>?,
    );
  }

  /// Converts Vendor to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'stallName': stallName,
      'marketCity': marketCity,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'specialty': specialty,
      'phoneNumber': phoneNumber,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'followerCount': followerCount,
      'snapCount': snapCount,
      'marketLocation': marketLocation,
      'schedule': schedule,
    };
  }

  /// Creates a copy with updated fields
  Vendor copyWith({
    String? vendorId,
    String? stallName,
    String? marketCity,
    String? avatarUrl,
    String? bio,
    String? specialty,
    String? phoneNumber,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? followerCount,
    int? snapCount,
    Map<String, dynamic>? marketLocation,
    Map<String, dynamic>? schedule,
  }) {
    return Vendor(
      vendorId: vendorId ?? this.vendorId,
      stallName: stallName ?? this.stallName,
      marketCity: marketCity ?? this.marketCity,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      specialty: specialty ?? this.specialty,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      followerCount: followerCount ?? this.followerCount,
      snapCount: snapCount ?? this.snapCount,
      marketLocation: marketLocation ?? this.marketLocation,
      schedule: schedule ?? this.schedule,
    );
  }

  /// Gets the vendor's initials for avatar fallback
  String get initials {
    final words = stallName.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return 'V';
  }

  /// Gets the display name (stall name with city)
  String get displayName => '$stallName, $marketCity';

  /// Gets a short display name (just stall name)
  String get shortDisplayName => stallName;

  @override
  String toString() {
    return 'Vendor(id: $vendorId, stall: $stallName, city: $marketCity, followers: $followerCount, snaps: $snapCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Vendor &&
        other.vendorId == vendorId &&
        other.stallName == stallName &&
        other.marketCity == marketCity &&
        other.avatarUrl == avatarUrl &&
        other.bio == bio &&
        other.specialty == specialty &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isActive == isActive &&
        other.followerCount == followerCount &&
        other.snapCount == snapCount;
  }

  @override
  int get hashCode {
    return vendorId.hashCode ^
        stallName.hashCode ^
        marketCity.hashCode ^
        avatarUrl.hashCode ^
        bio.hashCode ^
        specialty.hashCode ^
        phoneNumber.hashCode ^
        email.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        isActive.hashCode ^
        followerCount.hashCode ^
        snapCount.hashCode;
  }
}