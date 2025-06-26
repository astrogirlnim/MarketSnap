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
  late Future<List<StoryItem>> _storiesFuture;
  late Future<List<Snap>> _snapsFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _feedService.getStories();
    _snapsFuture = _feedService.getFeedSnaps();
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
    setState(() {
      _storiesFuture = _feedService.getStories();
      _snapsFuture = _feedService.getFeedSnaps();
    });
  }

  Widget _buildStoriesSection() {
    return FutureBuilder<List<StoryItem>>(
      future: _storiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 110, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const SizedBox(height: 110, child: Center(child: Text('Error loading stories')));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return StoryCarouselWidget(stories: snapshot.data!);
      },
    );
  }

  Widget _buildSnapsList() {
    return FutureBuilder<List<Snap>>(
      future: _snapsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const SliverFillRemaining(child: Center(child: Text('Error loading snaps')));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverFillRemaining(child: Center(child: Text('No snaps yet!')));
        }
        
        final snaps = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return FeedPostWidget(snap: snaps[index]);
            },
            childCount: snaps.length,
          ),
        );
      },
    );
  }
} 