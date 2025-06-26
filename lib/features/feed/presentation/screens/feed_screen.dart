import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/application/feed_service.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/features/feed/presentation/widgets/feed_post_widget.dart';
import 'package:marketsnap/features/feed/presentation/widgets/story_carousel_widget.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/core/services/hive_service.dart';

class FeedScreen extends StatefulWidget {
  final HiveService hiveService;

  const FeedScreen({super.key, required this.hiveService});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedService _feedService;

  @override
  void initState() {
    super.initState();
    _feedService = FeedService(hiveService: widget.hiveService);
    developer.log(
      '[FeedScreen] Initializing feed screen with real-time streams',
      name: 'FeedScreen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarketSnap'),
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildStoriesSection()),
            _buildSnapsList(),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshFeed() async {
    developer.log('[FeedScreen] Manual refresh triggered', name: 'FeedScreen');
    // With streams, we don't need to manually refresh as data updates automatically
    // But we'll trigger a rebuild to satisfy the RefreshIndicator
    setState(() {});
  }

  /// Handle snap deletion with user feedback
  Future<void> _handleSnapDeletion(Snap snap) async {
    developer.log(
      '[FeedScreen] Deleting snap: ${snap.id}',
      name: 'FeedScreen',
    );

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            backgroundColor: AppColors.eggshell,
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.marketBlue),
                SizedBox(width: 16),
                Text('Deleting snap...'),
              ],
            ),
          );
        },
      );

      // Attempt to delete from Firestore and Storage
      await _feedService.deleteSnap(snap);

      // Also try to remove from pending queue in case it wasn't uploaded yet
      await _feedService.removePendingMediaByContent(
        caption: snap.caption,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snap deleted successfully'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }

      developer.log(
        '[FeedScreen] Snap deleted successfully: ${snap.id}',
        name: 'FeedScreen',
      );
    } catch (e) {
      developer.log(
        '[FeedScreen] Error deleting snap: $e',
        name: 'FeedScreen',
      );

      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete snap: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildStoriesSection() {
    return StreamBuilder<List<StoryItem>>(
      stream: _feedService.getStoriesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          developer.log(
            '[FeedScreen] Stories stream: waiting for data',
            name: 'FeedScreen',
          );
          return const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          developer.log(
            '[FeedScreen] Stories stream error: ${snapshot.error}',
            name: 'FeedScreen',
          );
          return const SizedBox(
            height: 110,
            child: Center(child: Text('Error loading stories')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          developer.log(
            '[FeedScreen] Stories stream: no data available',
            name: 'FeedScreen',
          );
          return const SizedBox.shrink();
        }

        final stories = snapshot.data!;
        developer.log(
          '[FeedScreen] Stories stream: displaying ${stories.length} stories',
          name: 'FeedScreen',
        );
        return StoryCarouselWidget(stories: stories);
      },
    );
  }

  Widget _buildSnapsList() {
    return StreamBuilder<List<Snap>>(
      stream: _feedService.getFeedSnapsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          developer.log(
            '[FeedScreen] Snaps stream: waiting for data',
            name: 'FeedScreen',
          );
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          developer.log(
            '[FeedScreen] Snaps stream error: ${snapshot.error}',
            name: 'FeedScreen',
          );
          return const SliverFillRemaining(
            child: Center(child: Text('Error loading snaps')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          developer.log(
            '[FeedScreen] Snaps stream: no data available',
            name: 'FeedScreen',
          );
          return const SliverFillRemaining(
            child: Center(child: Text('No snaps yet!')),
          );
        }

        final snaps = snapshot.data!;
        developer.log(
          '[FeedScreen] Snaps stream: displaying ${snaps.length} snaps',
          name: 'FeedScreen',
        );

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final snap = snaps[index];
            return FeedPostWidget(
              snap: snap,
              isCurrentUserPost: snap.vendorId == _feedService.currentUserId,
              onDelete: snap.vendorId == _feedService.currentUserId
                  ? () => _handleSnapDeletion(snap)
                  : null,
            );
          }, childCount: snaps.length),
        );
      },
    );
  }
}
