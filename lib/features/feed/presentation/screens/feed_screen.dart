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
    print('[FeedScreen] Initializing feed screen with real-time streams');
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
            SliverToBoxAdapter(
              child: _buildStoriesSection(),
            ),
            _buildSnapsList(),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshFeed() async {
    print('[FeedScreen] Manual refresh triggered');
    // With streams, we don't need to manually refresh as data updates automatically
    // But we'll trigger a rebuild to satisfy the RefreshIndicator
    setState(() {});
  }

  Widget _buildStoriesSection() {
    return StreamBuilder<List<StoryItem>>(
      stream: _feedService.getStoriesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[FeedScreen] Stories stream: waiting for data');
          return const SizedBox(height: 110, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          print('[FeedScreen] Stories stream error: ${snapshot.error}');
          return const SizedBox(height: 110, child: Center(child: Text('Error loading stories')));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print('[FeedScreen] Stories stream: no data available');
          return const SizedBox.shrink();
        }
        
        final stories = snapshot.data!;
        print('[FeedScreen] Stories stream: displaying ${stories.length} stories');
        return StoryCarouselWidget(stories: stories);
      },
    );
  }

  Widget _buildSnapsList() {
    return StreamBuilder<List<Snap>>(
      stream: _feedService.getFeedSnapsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[FeedScreen] Snaps stream: waiting for data');
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          print('[FeedScreen] Snaps stream error: ${snapshot.error}');
          return const SliverFillRemaining(child: Center(child: Text('Error loading snaps')));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print('[FeedScreen] Snaps stream: no data available');
          return const SliverFillRemaining(child: Center(child: Text('No snaps yet!')));
        }
        
        final snaps = snapshot.data!;
        print('[FeedScreen] Snaps stream: displaying ${snaps.length} snaps');
        
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final snap = snaps[index];
              return FeedPostWidget(
                snap: snap,
                isCurrentUserPost: snap.vendorId == _feedService.currentUserId,
              );
            },
            childCount: snaps.length,
          ),
        );
      },
    );
  }
} 