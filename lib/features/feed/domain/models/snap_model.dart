import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { photo, video }

class Snap {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorAvatarUrl;
  final String mediaUrl;
  final MediaType mediaType;
  final String? caption;
  final String? filterType;
  final DateTime createdAt;
  final DateTime expiresAt;

  Snap({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorAvatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.filterType,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Snap.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Snap(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      vendorAvatarUrl: data['vendorAvatarUrl'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: (data['mediaType'] == 'video')
          ? MediaType.video
          : MediaType.photo,
      caption: data['caption'],
      filterType: data['filterType'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  /// Creates a copy of this snap with updated fields
  Snap copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? vendorAvatarUrl,
    String? mediaUrl,
    MediaType? mediaType,
    String? caption,
    String? filterType,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return Snap(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorAvatarUrl: vendorAvatarUrl ?? this.vendorAvatarUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      filterType: filterType ?? this.filterType,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Updates this snap's cached profile data with fresh profile information
  /// Returns a new Snap instance with updated vendor name and avatar
  Snap updateProfileData({
    required String vendorName,
    required String vendorAvatarUrl,
  }) {
    return copyWith(vendorName: vendorName, vendorAvatarUrl: vendorAvatarUrl);
  }

  @override
  String toString() {
    return 'Snap(id: $id, vendorId: $vendorId, vendorName: $vendorName, mediaType: $mediaType, createdAt: $createdAt)';
  }
}
