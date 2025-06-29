import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:marketsnap/features/feed/application/feed_service.dart';
import 'package:marketsnap/features/feed/domain/models/snap_model.dart';
import 'package:marketsnap/features/feed/domain/models/story_item_model.dart';
import 'package:marketsnap/features/feed/presentation/widgets/feed_post_widget.dart';
import 'package:marketsnap/features/feed/presentation/widgets/story_carousel_widget.dart';
import 'package:marketsnap/features/feed/presentation/widgets/broadcast_widget.dart';
import 'package:marketsnap/features/feed/presentation/widgets/create_broadcast_modal.dart';
import 'package:marketsnap/features/feed/presentation/screens/story_viewer_screen.dart';
import 'package:marketsnap/core/models/broadcast.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:marketsnap/main.dart'; // Import to access global services

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Use global feed service instance with profile update notifier
  final FeedService _feedService = feedService;

  /// Check if current user is a vendor (can create broadcasts)
  bool get _canCreateBroadcasts {
    final profile = profileService.getCurrentUserProfile();
    // If profile is a VendorProfile, user is a vendor and can create broadcasts
    return profile != null && profile.runtimeType.toString() == 'VendorProfile';
  }

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
            SliverToBoxAdapter(child: _buildBroadcastsSection()),
            _buildSnapsList(),
          ],
        ),
      ),
      // Add floating action button for vendors to create broadcasts
      floatingActionButton: _canCreateBroadcasts ? _buildBroadcastFAB() : null,
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
        return StoryCarouselWidget(
          stories: stories,
          onStoryTap: (tappedStory) => _handleStoryTap(stories, tappedStory),
        );
      },
    );
  }

  /// Handle story tap - navigate to story viewer
  void _handleStoryTap(List<StoryItem> allStories, StoryItem tappedStory) {
    developer.log(
      '[FeedScreen] Story tapped: ${tappedStory.vendorName} with ${tappedStory.snaps.length} snaps',
      name: 'FeedScreen',
    );

    // Find the index of the tapped story
    final tappedIndex = allStories.indexWhere(
      (story) => story.vendorId == tappedStory.vendorId,
    );

    if (tappedIndex == -1) {
      developer.log(
        '[FeedScreen] Error: Could not find tapped story in stories list',
        name: 'FeedScreen',
      );
      return;
    }

    // Navigate to story viewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          stories: allStories,
          initialStoryIndex: tappedIndex,
        ),
      ),
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
              onDelete: (snapId) async {
                try {
                  await _feedService.deleteSnap(snapId);
                  developer.log('[FeedScreen] Snap deleted successfully: $snapId');
                } catch (e) {
                  developer.log('[FeedScreen] Error deleting snap: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete post: $e'),
                        backgroundColor: AppColors.appleRed,
                      ),
                    );
                  }
                }
              },
            );
          }, childCount: snaps.length),
        );
      },
    );
  }

  Widget _buildBroadcastsSection() {
    return StreamBuilder<List<Broadcast>>(
      stream: broadcastService.getBroadcastsStream(limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          developer.log(
            '[FeedScreen] Broadcasts stream: waiting for data',
            name: 'FeedScreen',
          );
          return const SizedBox.shrink(); // Don't show loading for broadcasts
        }
        if (snapshot.hasError) {
          developer.log(
            '[FeedScreen] Broadcasts stream error: ${snapshot.error}',
            name: 'FeedScreen',
          );
          return const SizedBox.shrink(); // Hide on error
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          developer.log(
            '[FeedScreen] Broadcasts stream: no data available',
            name: 'FeedScreen',
          );
          return const SizedBox.shrink(); // Hide when no broadcasts
        }

        final broadcasts = snapshot.data!;
        developer.log(
          '[FeedScreen] Broadcasts stream: displaying ${broadcasts.length} broadcasts',
          name: 'FeedScreen',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: AppColors.marketBlue, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Market Broadcasts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Broadcasts list
            ...broadcasts.map(
              (broadcast) => BroadcastWidget(
                broadcast: broadcast,
                isCurrentUserPost:
                    broadcast.vendorUid == _feedService.currentUserId,
                onDelete: () async {
                  // Capture context before async operation
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await broadcastService.deleteBroadcast(broadcast.id);
                    developer.log(
                      '[FeedScreen] Broadcast deleted: ${broadcast.id}',
                    );
                  } catch (e) {
                    developer.log('[FeedScreen] Error deleting broadcast: $e');
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete broadcast: $e'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }

  Widget? _buildBroadcastFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCreateBroadcastModal,
      backgroundColor: AppColors.marketBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.campaign),
      label: const Text('Broadcast'),
    );
  }

  void _showCreateBroadcastModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateBroadcastModal(
          broadcastService: broadcastService,
          hiveService: hiveService,
          onBroadcastCreated: () {
            developer.log('[FeedScreen] Broadcast created successfully');
            // Feed will automatically update via stream
          },
        ),
      ),
    );
  }
}
