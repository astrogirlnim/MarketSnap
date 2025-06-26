import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/application/feed_service.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/features/feed/presentation/widgets/feed_post_widget.dart';
import 'package:marketsnap/features/feed/presentation/widgets/story_carousel_widget.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();

  @override
  void initState() {
    super.initState();
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
            );
          }, childCount: snaps.length),
        );
      },
    );
  }
}
