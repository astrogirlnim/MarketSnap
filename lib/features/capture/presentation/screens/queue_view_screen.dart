import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marketsnap/core/models/pending_media.dart';
import 'package:marketsnap/core/services/background_sync_service.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Screen to display the user's offline media queue
class QueueViewScreen extends StatefulWidget {
  const QueueViewScreen({super.key});

  @override
  State<QueueViewScreen> createState() => _QueueViewScreenState();
}

class _QueueViewScreenState extends State<QueueViewScreen> {
  late Box<PendingMediaItem> _pendingBox;
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[QueueViewScreen] Initializing QueueViewScreen');
    _initializeQueue();
    _checkConnectivity();
  }

  /// Initialize the Hive box and load queue data
  Future<void> _initializeQueue() async {
    try {
      _pendingBox = await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
      debugPrint('[QueueViewScreen] Loaded queue with ${_pendingBox.length} items');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[QueueViewScreen] Error loading queue: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);
    
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  /// Trigger manual sync if online
  Future<void> _triggerManualSync() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pendingBox.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Queue is empty - nothing to sync'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final backgroundSyncService = BackgroundSyncService();
      await backgroundSyncService.triggerImmediateSync();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.white),
              SizedBox(width: 8),
              Text('Sync completed successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Sync failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: AppBar(
        title: const Text(
          'Upload Queue',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.cornsilk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isOnline && _pendingBox.isNotEmpty)
            IconButton(
              icon: _isSyncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
                    ),
                  )
                : const Icon(Icons.sync, color: AppColors.marketBlue),
              onPressed: _isSyncing ? null : _triggerManualSync,
              tooltip: 'Sync now',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.marketBlue))
          : _buildQueueContent(),
    );
  }

  /// Build the main queue content
  Widget _buildQueueContent() {
    return Column(
      children: [
        // Status header
        _buildStatusHeader(),
        
        // Queue items list
        Expanded(
          child: _pendingBox.isEmpty
              ? _buildEmptyState()
              : _buildQueueList(),
        ),
      ],
    );
  }

  /// Build the status header showing connectivity and queue info
  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.seedBrown.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Connectivity status
          Row(
            children: [
              Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                color: _isOnline ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isOnline ? AppColors.success : AppColors.warning,
                ),
              ),
              const Spacer(),
                             if (_isSyncing) ...[
                 const SizedBox(
                   width: 16,
                   height: 16,
                   child: CircularProgressIndicator(
                     strokeWidth: 2,
                     valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
                   ),
                 ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Syncing...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Queue count
          Row(
            children: [
              Icon(
                Icons.queue,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_pendingBox.length} ${_pendingBox.length == 1 ? 'item' : 'items'} in queue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build empty state when queue is empty
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                   Icon(
           Icons.check_circle_outline,
           size: 64,
           color: AppColors.success.withValues(alpha: 0.5),
         ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Queue is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'All your posts have been uploaded!',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build the list of queued items
  Widget _buildQueueList() {
    return ValueListenableBuilder<Box<PendingMediaItem>>(
      valueListenable: _pendingBox.listenable(),
      builder: (context, box, _) {
        final items = box.values.toList();
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildQueueItem(item, index);
          },
        );
      },
    );
  }

  /// Build a single queue item
  Widget _buildQueueItem(PendingMediaItem item, int index) {
    final bool fileExists = File(item.filePath).existsSync();
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fileExists 
              ? AppColors.seedBrown.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Media type icon
          Container(
            width: 48,
            height: 48,
                         decoration: BoxDecoration(
               color: _getMediaTypeColor(item.mediaType).withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
             ),
            child: Icon(
              _getMediaTypeIcon(item.mediaType),
              color: _getMediaTypeColor(item.mediaType),
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppSpacing.md),
          
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                               // Caption
                 Text(
                   (item.caption?.isEmpty ?? true) ? 'No caption' : item.caption!,
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.w500,
                     color: (item.caption?.isEmpty ?? true)
                         ? AppColors.textSecondary 
                         : AppColors.textPrimary,
                   ),
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                 ),
                
                const SizedBox(height: AppSpacing.xs),
                
                // Media type and filter
                Row(
                  children: [
                    Text(
                      item.mediaType == MediaType.photo ? 'Photo' : 'Video',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                                         if (item.filterType != null && item.filterType != 'none') ...[
                       const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                       Text(
                         '${item.filterType!.toUpperCase()} filter',
                         style: const TextStyle(
                           fontSize: 14,
                           color: AppColors.textSecondary,
                         ),
                       ),
                     ],
                  ],
                ),
                
                // File status
                if (!fileExists) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Text(
                        'File missing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Queue position
                     Container(
             padding: const EdgeInsets.symmetric(
               horizontal: AppSpacing.sm,
               vertical: AppSpacing.xs,
             ),
             decoration: BoxDecoration(
               color: AppColors.marketBlue.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(16),
             ),
             child: Text(
               '#${index + 1}',
               style: const TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
                 color: AppColors.marketBlue,
               ),
             ),
           ),
        ],
      ),
    );
  }

  /// Get icon for media type
  IconData _getMediaTypeIcon(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.photo:
        return Icons.photo;
      case MediaType.video:
        return Icons.videocam;
    }
  }

  /// Get color for media type
  Color _getMediaTypeColor(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.photo:
        return AppColors.marketBlue;
      case MediaType.video:
        return AppColors.harvestOrange;
    }
  }

  @override
  void dispose() {
    // Don't close the box here as it's shared across the app
    super.dispose();
  }
} 