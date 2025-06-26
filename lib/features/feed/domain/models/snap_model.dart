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
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
