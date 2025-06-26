import 'package:marketsnap/features/feed/domain/models/snap_model.dart';

class StoryItem {
  final String vendorId;
  final String vendorName;
  final String vendorAvatarUrl;
  final List<Snap> snaps;
  final bool hasUnseenSnaps;

  StoryItem({
    required this.vendorId,
    required this.vendorName,
    required this.vendorAvatarUrl,
    required this.snaps,
    this.hasUnseenSnaps = true,
  });
}
