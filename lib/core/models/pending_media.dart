import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'pending_media.g.dart';

const _uuid = Uuid();

/// Enum for the type of media being queued.
@HiveType(typeId: 2)
enum MediaType {
  @HiveField(0)
  photo,

  @HiveField(1)
  video,
}

/// Represents a media item that is pending upload.
/// Stored in a Hive box when the device is offline.
@HiveType(typeId: 3)
class PendingMediaItem extends HiveObject {
  /// A unique identifier for the queue item.
  @HiveField(0)
  final String id;

  /// The local file path of the media.
  @HiveField(1)
  final String filePath;

  /// The type of media (photo or video).
  @HiveField(2)
  final MediaType mediaType;

  /// The timestamp when the item was created.
  @HiveField(3)
  final DateTime createdAt;

  /// Optional: User-added caption for the media.
  @HiveField(4)
  final String? caption;

  /// Optional: Coarse location data.
  /// Stored as a map for flexibility, e.g., {'lat': 34.5, 'lon': -118.2}.
  @HiveField(5)
  final Map<String, double>? location;

  /// The ID of the vendor who created this snap.
  @HiveField(6)
  final String vendorId;

  PendingMediaItem({
    required this.filePath,
    required this.mediaType,
    required this.vendorId,
    this.caption,
    this.location,
    String? id,
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  @override
  String toString() {
    return 'PendingMediaItem(id: $id, vendorId: $vendorId, type: $mediaType, path: $filePath, queuedAt: $createdAt)';
  }
}
