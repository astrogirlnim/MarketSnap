import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In a real app, we would also fetch user's follow list.
  // For now, we'll fetch recent snaps from all vendors.

  Future<List<StoryItem>> getStories() async {
    // 1. For simplicity, we'll get stories from a few recent vendors.
    // In a real app, this would be based on followed vendors.
    final snapsQuery = await _firestore
        .collection('snaps')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final snaps = snapsQuery.docs.map((doc) => Snap.fromFirestore(doc)).toList();

    // 2. Group snaps by vendor
    final Map<String, List<Snap>> snapsByVendor = {};
    for (var snap in snaps) {
      if (!snapsByVendor.containsKey(snap.vendorId)) {
        snapsByVendor[snap.vendorId] = [];
      }
      snapsByVendor[snap.vendorId]!.add(snap);
    }

    // 3. Create StoryItems
    final List<StoryItem> stories = [];
    snapsByVendor.forEach((vendorId, vendorSnaps) {
      if (vendorSnaps.isNotEmpty) {
        stories.add(StoryItem(
          vendorId: vendorId,
          vendorName: vendorSnaps.first.vendorName,
          vendorAvatarUrl: vendorSnaps.first.vendorAvatarUrl,
          snaps: vendorSnaps,
        ));
      }
    });

    return stories;
  }

  Future<List<Snap>> getFeedSnaps({DocumentSnapshot? lastDocument, int limit = 10}) async {
    // For now, fetching all recent snaps.
    // A real implementation would filter by followed vendors.
    Query query = _firestore
        .collection('snaps')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final querySnapshot = await query.get();
    final snaps = querySnapshot.docs.map((doc) => Snap.fromFirestore(doc)).toList();
    return snaps;
  }
} 