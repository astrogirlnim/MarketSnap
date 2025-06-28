import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../../../../core/services/broadcast_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

/// Modal widget for creating new text broadcasts
/// Includes 100 character limit and optional location tagging
class CreateBroadcastModal extends StatefulWidget {
  final BroadcastService broadcastService;
  final HiveService hiveService;
  final VoidCallback? onBroadcastCreated;

  const CreateBroadcastModal({
    super.key,
    required this.broadcastService,
    required this.hiveService,
    this.onBroadcastCreated,
  });

  @override
  State<CreateBroadcastModal> createState() => _CreateBroadcastModalState();
}

class _CreateBroadcastModalState extends State<CreateBroadcastModal> {
  final TextEditingController _messageController = TextEditingController();
  final LocationService _locationService = LocationService();
  
  static const int _maxCharacters = 100;
  
  bool _includeLocation = false;
  bool _isPosting = false;
  bool _checkingLocation = false;
  String _locationStatus = '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _initializeLocationStatus();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to update character counter
  }

  /// Check if location is enabled in user settings
  bool _isLocationEnabledInSettings() {
    final settings = widget.hiveService.getUserSettings();
    return settings?.enableCoarseLocation ?? false;
  }

  /// Initialize location status message without checking permissions
  Future<void> _initializeLocationStatus() async {
    try {
      final status = await _locationService.getLocationStatusMessage();
      
      if (mounted) {
        setState(() {
          _locationStatus = status;
        });
      }

      developer.log('[CreateBroadcastModal] Initial location status: $status');
    } catch (e) {
      developer.log('[CreateBroadcastModal] Error getting location status: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Location permission needed to tag broadcasts with your market area.';
        });
      }
    }
  }

  /// Handle location toggle - request permission if needed
  Future<void> _onLocationToggled(bool value) async {
    if (!value) {
      // Simply disable location
      setState(() {
        _includeLocation = false;
      });
      return;
    }

    // Check if location is enabled in settings
    final settings = widget.hiveService.getUserSettings();
    final locationEnabled = settings?.enableCoarseLocation ?? false;
    
    if (!locationEnabled) {
      _showLocationDisabledDialog();
      return;
    }

    // Show loading state
    setState(() {
      _checkingLocation = true;
    });

    try {
      developer.log('[CreateBroadcastModal] Requesting location permission...');
      
      final granted = await _locationService.requestLocationPermission();
      
      if (granted) {
        await _initializeLocationStatus(); // Refresh status
        setState(() {
          _includeLocation = true;
          _checkingLocation = false;
        });
        developer.log('[CreateBroadcastModal] ✅ Location permission granted, toggle enabled');
      } else {
        setState(() {
          _checkingLocation = false;
        });
        _showLocationPermissionDialog();
      }
    } catch (e) {
      developer.log('[CreateBroadcastModal] ❌ Error requesting location permission: $e');
      setState(() {
        _checkingLocation = false;
      });
      _showLocationPermissionDialog();
    }
  }

  /// Show dialog when location is disabled in settings
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Disabled'),
        content: const Text(
          'Location tagging is disabled in your settings. Enable it in Settings & Help to include your market area with broadcasts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when location permission is denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Needed'),
        content: Text(_locationStatus),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final granted = await _locationService.requestLocationPermission();
              if (granted) {
                await _initializeLocationStatus();
                setState(() {
                  _includeLocation = true;
                });
                developer.log('[CreateBroadcastModal] ✅ Location permission granted on retry');
              } else {
                developer.log('[CreateBroadcastModal] ❌ Location permission denied again');
                // Could show another dialog or open app settings
                await _locationService.requestLocationPermission(); // This might open settings
              }
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Post the broadcast
  Future<void> _postBroadcast() async {
    final message = _messageController.text.trim();
    
    if (message.isEmpty) {
      _showErrorSnackbar('Please enter a message');
      return;
    }

    if (message.length > _maxCharacters) {
      _showErrorSnackbar('Message must be $_maxCharacters characters or less');
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      developer.log('[CreateBroadcastModal] Posting broadcast: "$message", includeLocation: $_includeLocation');

      final broadcastId = await widget.broadcastService.createBroadcast(
        message: message,
        includeLocation: _includeLocation,
      );

      if (broadcastId != null) {
        developer.log('[CreateBroadcastModal] ✅ Broadcast posted successfully: $broadcastId');
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: MarketSnapStatusMessage(
                message: 'Broadcast sent to your followers!',
                type: StatusType.success,
                showIcon: true,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              duration: const Duration(seconds: 3),
            ),
          );

          // Close modal and trigger callback
          Navigator.of(context).pop();
          widget.onBroadcastCreated?.call();
        }
      }
    } catch (e) {
      developer.log('[CreateBroadcastModal] ❌ Error posting broadcast: $e');
      _showErrorSnackbar('Failed to send broadcast: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MarketSnapStatusMessage(
            message: message,
            type: StatusType.error,
            showIcon: true,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _messageController.text.length;
    final charactersRemaining = _maxCharacters - currentLength;
    final isOverLimit = currentLength > _maxCharacters;
    final canPost = currentLength > 0 && !isOverLimit && !_isPosting;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusXl),
          topRight: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.seedBrown.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: AppSpacing.edgeInsetsCard,
            child: Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  color: AppColors.marketBlue,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Send Broadcast',
                  style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          Divider(color: AppColors.seedBrown.withAlpha((0.2 * 255).round())),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: AppSpacing.edgeInsetsCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'Send a quick message to all your followers',
                                              style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Message input
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.eggshell,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: isOverLimit ? AppColors.appleRed : AppColors.seedBrown,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'What\'s happening at your stall today?',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: AppSpacing.edgeInsetsCard,
                      ),
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Character counter
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$charactersRemaining',
                          style: AppTypography.caption.copyWith(
                            color: isOverLimit ? AppColors.appleRed : AppColors.textSecondary,
                            fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          ' characters remaining',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Location toggle
                  Container(
                    padding: AppSpacing.edgeInsetsCard,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.seedBrown, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: _includeLocation ? AppColors.leafGreen : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Include Market Area',
                                style: AppTypography.bodyLG.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_checkingLocation) 
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
                                ),
                              )
                            else 
                              Switch(
                                value: _includeLocation,
                                onChanged: _isLocationEnabledInSettings() ? _onLocationToggled : null,
                                activeColor: AppColors.leafGreen,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _locationStatus,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Post button
                  SizedBox(
                    width: double.infinity,
                    child: MarketSnapPrimaryButton(
                      text: _isPosting ? 'Sending...' : 'Send Broadcast',
                      onPressed: canPost ? _postBroadcast : null,
                      isLoading: _isPosting,
                      icon: Icons.send,
                    ),
                  ),

                  // Add some bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 