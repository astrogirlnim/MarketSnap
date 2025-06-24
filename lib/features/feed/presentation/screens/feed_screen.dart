import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/snap.dart';
import '../../../../core/models/vendor.dart';
import '../../../../core/models/following.dart';
import '../../../../core/services/feed_service.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/story_carousel.dart';
import '../../../../shared/presentation/widgets/snap_card.dart';

/// Main feed screen combining story carousel and vertical feed
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  
  // Data state
  Map<String, List<Snap>> _snapsByVendor = {};
  Map<String, Vendor> _vendors = {};
  Map<String, Following> _following = {};
  List<Snap> _feedSnaps = [];
  
  // UI state
  bool _isLoadingStories = true;
  bool _isLoadingFeed = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Load story reel and feed data
  Future<void> _loadData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      debugPrint('[FeedScreen] Loading feed data for user: ${currentUser.uid}');
      
      // Load story reel data
      final storyData = await _feedService.getStoryReelData(
        currentUserUid: currentUser.uid,
      );
      
      // Load followed snaps for main feed
      final feedSnaps = await _feedService.getFollowedSnaps(
        currentUserUid: currentUser.uid,
      );

      if (mounted) {
        setState(() {
          _snapsByVendor = storyData['snapsByVendor'] as Map<String, List<Snap>>;
          _vendors = storyData['vendors'] as Map<String, Vendor>;
          _following = storyData['following'] as Map<String, Following>;
          _feedSnaps = feedSnaps;
          _isLoadingStories = false;
          _isLoadingFeed = false;
          _error = null;
        });
      }
      
      debugPrint('[FeedScreen] Data loaded successfully');
      debugPrint('[FeedScreen] Stories: ${_snapsByVendor.length} vendors');
      debugPrint('[FeedScreen] Feed: ${_feedSnaps.length} snaps');
    } catch (e) {
      debugPrint('[FeedScreen] Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoadingStories = false;
          _isLoadingFeed = false;
          _error = 'Failed to load feed data';
        });
      }
    }
  }

  /// Refresh data
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    await _loadData();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Handle scroll events
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more feed items when near bottom
      _loadMoreFeedItems();
    }
  }

  /// Load more feed items (pagination)
  Future<void> _loadMoreFeedItems() async {
    // TODO: Implement pagination
    debugPrint('[FeedScreen] Load more items requested');
  }

  /// Handle story tap
  void _onStoryTap(String vendorId, List<Snap> snaps) {
    debugPrint('[FeedScreen] Story tapped: $vendorId with ${snaps.length} snaps');
    // TODO: Navigate to story viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening story for ${_vendors[vendorId]?.stallName ?? vendorId}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handle add story tap
  void _onAddStoryTap() {
    debugPrint('[FeedScreen] Add story tapped');
    // TODO: Navigate to camera
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add story feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Handle snap tap
  void _onSnapTap(Snap snap) {
    debugPrint('[FeedScreen] Snap tapped: ${snap.snapId}');
    // TODO: Navigate to snap detail view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${snap.mediaType} from ${_vendors[snap.vendorUid]?.stallName ?? 'Unknown vendor'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handle vendor tap
  void _onVendorTap(String vendorId) {
    debugPrint('[FeedScreen] Vendor tapped: $vendorId');
    // TODO: Navigate to vendor profile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening profile for ${_vendors[vendorId]?.stallName ?? 'Unknown vendor'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handle snap like
  void _onSnapLike(Snap snap) {
    debugPrint('[FeedScreen] Snap liked: ${snap.snapId}');
    // TODO: Implement like functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Like feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Handle snap share
  void _onSnapShare(Snap snap) {
    debugPrint('[FeedScreen] Snap shared: ${snap.snapId}');
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarketSnap'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: _isRefreshing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(currentUser),
    );
  }

  /// Build main body content
  Widget _buildBody(User? currentUser) {
    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Story carousel section
          SliverToBoxAdapter(
            child: StoryCarouselSection(
              title: 'Stories',
              snapsByVendor: _snapsByVendor,
              vendors: _vendors,
              following: _following,
              currentUserUid: currentUser?.uid,
              onStoryTap: _onStoryTap,
              onAddStoryTap: _onAddStoryTap,
              onRefresh: _refreshData,
              isLoading: _isLoadingStories,
              isRefreshing: _isRefreshing,
              showSeeAll: false,
            ),
          ),

          // Feed section divider
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.sectionSpacing),
          ),

          // Feed header
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenEdge,
              child: Text(
                'Recent Snaps',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.sm),
          ),

          // Feed items
          _buildFeedContent(),
        ],
      ),
    );
  }

  /// Build feed content (loading, empty, or snap cards)
  Widget _buildFeedContent() {
    if (_isLoadingFeed) {
      return SliverToBoxAdapter(
        child: _buildFeedLoadingState(),
      );
    }

    if (_feedSnaps.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyFeedState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final snap = _feedSnaps[index];
          final vendor = _vendors[snap.vendorUid];

          if (vendor == null) {
            return const SizedBox.shrink();
          }

          return SnapCard(
            snap: snap,
            vendor: vendor,
            onTap: () => _onSnapTap(snap),
            onVendorTap: () => _onVendorTap(vendor.vendorId),
            onLike: () => _onSnapLike(snap),
            onShare: () => _onSnapShare(snap),
            isLiked: false, // TODO: Track like state
          );
        },
        childCount: _feedSnaps.length,
      ),
    );
  }

  /// Build feed loading state
  Widget _buildFeedLoadingState() {
    return Container(
      padding: AppSpacing.screenEdge,
      child: Column(
        children: List.generate(3, (index) => 
          Container(
            height: 300,
            margin: EdgeInsets.only(bottom: AppSpacing.feedSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.snapCardBorderRadius),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }

  /// Build empty feed state
  Widget _buildEmptyFeedState() {
    return Container(
      height: 300,
      padding: AppSpacing.screenEdge,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No snaps yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Follow vendors to see their latest snaps in your feed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to discover/search screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Discover vendors feature coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Discover Vendors'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: AppSpacing.screenEdge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'Failed to load feed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}