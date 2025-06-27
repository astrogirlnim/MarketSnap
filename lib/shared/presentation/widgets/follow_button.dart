import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'market_snap_components.dart';
import '../../../core/services/follow_service.dart';

/// A button widget for following/unfollowing vendors
/// Shows different states: loading, following, not following
/// Integrates with FollowService for backend operations
class FollowButton extends StatefulWidget {
  final String vendorId;
  final FollowService followService;
  final VoidCallback? onFollowStatusChanged;

  const FollowButton({
    super.key,
    required this.vendorId,
    required this.followService,
    this.onFollowStatusChanged,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  /// Checks the current follow status for this vendor
  Future<void> _checkFollowStatus() async {
    if (!mounted) return;

    developer.log(
      '[FollowButton] Checking follow status for vendor: ${widget.vendorId}',
      name: 'FollowButton',
    );

    try {
      final isFollowing = await widget.followService.isFollowingVendor(
        widget.vendorId,
      );

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoading = false;
        });

        developer.log(
          '[FollowButton] Follow status loaded: $_isFollowing',
          name: 'FollowButton',
        );
      }
    } catch (e) {
      developer.log(
        '[FollowButton] Error checking follow status: $e',
        name: 'FollowButton',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handles follow/unfollow action
  Future<void> _toggleFollowStatus() async {
    if (_isActionInProgress || !mounted) return;

    setState(() {
      _isActionInProgress = true;
    });

    developer.log(
      '[FollowButton] Toggling follow status: $_isFollowing -> ${!_isFollowing}',
      name: 'FollowButton',
    );

    try {
      if (_isFollowing) {
        await widget.followService.unfollowVendor(widget.vendorId);
      } else {
        await widget.followService.followVendor(widget.vendorId);
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        // Show success message
        _showSuccessMessage(
          _isFollowing ? 'Following vendor!' : 'Unfollowed vendor',
        );

        // Notify parent of status change
        widget.onFollowStatusChanged?.call();

        developer.log(
          '[FollowButton] ✅ Follow status updated successfully',
          name: 'FollowButton',
        );
      }
    } catch (e) {
      developer.log(
        '[FollowButton] Error toggling follow status: $e',
        name: 'FollowButton',
      );

      if (mounted) {
        _showErrorMessage(
          'Failed to ${_isFollowing ? 'unfollow' : 'follow'} vendor',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  /// Shows success message to user
  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MarketSnapStatusMessage(
          message: message,
          type: StatusType.success,
          showIcon: true,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error message to user
  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MarketSnapStatusMessage(
          message: message,
          type: StatusType.error,
          showIcon: true,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Container(
        width: 120,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.eggshell,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.seedBrown),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
            ),
          ),
        ),
      );
    }

    // Follow/Unfollow button
    return SizedBox(
      width: 120,
      height: 40,
      child: _isFollowing ? _buildUnfollowButton() : _buildFollowButton(),
    );
  }

  /// Builds the follow button (when not following)
  Widget _buildFollowButton() {
    return MarketSnapPrimaryButton(
      text: 'Follow',
      onPressed: _isActionInProgress ? null : _toggleFollowStatus,
      isLoading: _isActionInProgress,
      icon: Icons.person_add,
    );
  }

  /// Builds the unfollow button (when following)
  Widget _buildUnfollowButton() {
    return MarketSnapSecondaryButton(
      text: 'Following',
      onPressed: _isActionInProgress ? null : _toggleFollowStatus,
      isLoading: _isActionInProgress,
      icon: Icons.check,
    );
  }
}

/// A compact version of the follow button for use in smaller spaces
class CompactFollowButton extends StatefulWidget {
  final String vendorId;
  final FollowService followService;
  final VoidCallback? onFollowStatusChanged;

  const CompactFollowButton({
    super.key,
    required this.vendorId,
    required this.followService,
    this.onFollowStatusChanged,
  });

  @override
  State<CompactFollowButton> createState() => _CompactFollowButtonState();
}

class _CompactFollowButtonState extends State<CompactFollowButton> {
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (!mounted) return;

    try {
      final isFollowing = await widget.followService.isFollowingVendor(
        widget.vendorId,
      );

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollowStatus() async {
    if (_isActionInProgress || !mounted) return;

    setState(() {
      _isActionInProgress = true;
    });

    try {
      if (_isFollowing) {
        await widget.followService.unfollowVendor(widget.vendorId);
      } else {
        await widget.followService.followVendor(widget.vendorId);
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        widget.onFollowStatusChanged?.call();
      }
    } catch (e) {
      // Silently handle error for compact button
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: _isActionInProgress ? null : _toggleFollowStatus,
      icon: _isActionInProgress
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
              ),
            )
          : Icon(
              _isFollowing ? Icons.person_remove : Icons.person_add,
              color: _isFollowing ? AppColors.appleRed : AppColors.marketBlue,
            ),
      tooltip: _isFollowing ? 'Unfollow' : 'Follow',
      style: IconButton.styleFrom(
        backgroundColor: _isFollowing
            ? AppColors.appleRed.withValues(alpha: 0.1)
            : AppColors.marketBlue.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }
}
