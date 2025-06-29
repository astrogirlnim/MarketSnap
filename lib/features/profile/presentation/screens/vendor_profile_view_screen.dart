import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../shared/presentation/widgets/follow_button.dart';
import '../../../../core/models/vendor_profile.dart';
import '../../../../core/services/follow_service.dart';
import '../../application/profile_service.dart';

/// Screen for viewing another vendor's profile (read-only)
/// Shows vendor information and allows regular users to follow/unfollow
class VendorProfileViewScreen extends StatefulWidget {
  final VendorProfile vendor;
  final ProfileService profileService;

  const VendorProfileViewScreen({
    super.key,
    required this.vendor,
    required this.profileService,
  });

  @override
  State<VendorProfileViewScreen> createState() =>
      _VendorProfileViewScreenState();
}

class _VendorProfileViewScreenState extends State<VendorProfileViewScreen> {
  late final FollowService _followService;
  bool _isCurrentUser = false;
  bool _isRegularUser = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkUserType();
  }

  void _initializeServices() {
    _followService = FollowService();
  }

  void _checkUserType() {
    final currentProfile = widget.profileService.getCurrentUserProfile();
    final regularProfile = widget.profileService.getCurrentRegularUserProfile();

    // Check if this is the current user's own profile
    _isCurrentUser = currentProfile?.uid == widget.vendor.uid;

    // Check if current user is a regular user (not a vendor)
    _isRegularUser = regularProfile != null && currentProfile == null;

    developer.log(
      '[VendorProfileViewScreen] User type - IsCurrentUser: $_isCurrentUser, IsRegularUser: $_isRegularUser',
      name: 'VendorProfileViewScreen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: AppBar(
        backgroundColor: AppColors.cornsilk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.soilCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isCurrentUser ? 'My Profile' : widget.vendor.displayName,
          style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
        ),
        centerTitle: true,
        // ✅ REMOVED: Redundant AppBar follow button to fix overflow and eliminate duplication
        // The main follow section in the content area provides better UX with "Stay Updated" messaging
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.edgeInsetsLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Section
              _buildAvatarSection(),
              const SizedBox(height: AppSpacing.xl),

              // Vendor Information
              _buildVendorInfo(),
              const SizedBox(height: AppSpacing.xl),

              // Follow Button (Large version for main content area)
              if (_isRegularUser && !_isCurrentUser) ...[
                _buildFollowSection(),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Contact Information
              _buildContactInfo(),
              const SizedBox(height: AppSpacing.xl),

              // Footer message
              _buildFooterMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.eggshell,
            border: Border.all(color: AppColors.seedBrown, width: 2),
          ),
          child:
              widget.vendor.avatarURL != null &&
                  widget.vendor.avatarURL!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    widget.vendor.avatarURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        size: 48,
                        color: AppColors.soilTaupe,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.marketBlue,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Icon(Icons.person, size: 48, color: AppColors.marketBlue),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.vendor.displayName,
          style: AppTypography.h1.copyWith(
            color: AppColors.soilCharcoal,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVendorInfo() {
    return Container(
      width: double.infinity,
      padding: AppSpacing.edgeInsetsCard,
      decoration: BoxDecoration(
        color: AppColors.eggshell,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.seedBrown, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vendor Information',
            style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stall Name
          _buildInfoRow(
            icon: Icons.storefront,
            label: 'Stall Name',
            value: widget.vendor.stallName,
          ),
          const SizedBox(height: AppSpacing.md),

          // Market City
          _buildInfoRow(
            icon: Icons.location_city,
            label: 'Market City',
            value: widget.vendor.marketCity,
          ),

          // Location sharing status
          if (widget.vendor.allowLocation) ...[
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'Location Sharing',
              value: 'Enabled',
              valueColor: AppColors.leafGreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.marketBlue, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.soilTaupe,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.body.copyWith(
                  color: valueColor ?? AppColors.soilCharcoal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowSection() {
    return Container(
      width: double.infinity,
      padding: AppSpacing.edgeInsetsCard,
      decoration: BoxDecoration(
        color: AppColors.marketBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.marketBlue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_active,
            color: AppColors.marketBlue,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stay Updated',
            style: AppTypography.h2.copyWith(color: AppColors.marketBlue),
          ),
          const SizedBox(height: AppSpacing.xs),
          // ✅ IMPROVED: Added flexible text wrapping to prevent overflow with long vendor names
          Flexible(
            child: Text(
              'Follow ${widget.vendor.displayName} to get notified when they post fresh finds!',
              style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              maxLines: null, // Allow text to wrap to multiple lines if needed
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FollowButton(
            vendorId: widget.vendor.uid,
            followService: _followService,
            onFollowStatusChanged: () {
              developer.log(
                '[VendorProfileViewScreen] ✅ Follow status changed for vendor: ${widget.vendor.uid}',
                name: 'VendorProfileViewScreen',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    if (widget.vendor.phoneNumber == null && widget.vendor.email == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: AppSpacing.edgeInsetsCard,
      decoration: BoxDecoration(
        color: AppColors.eggshell,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.seedBrown, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Phone Number
          if (widget.vendor.phoneNumber != null) ...[
            _buildInfoRow(
              icon: Icons.phone,
              label: 'Phone',
              value: widget.vendor.phoneNumber!,
            ),
            if (widget.vendor.email != null)
              const SizedBox(height: AppSpacing.md),
          ],

          // Email
          if (widget.vendor.email != null) ...[
            _buildInfoRow(
              icon: Icons.email,
              label: 'Email',
              value: widget.vendor.email!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterMessage() {
    return MarketSnapStatusMessage(
      message: _isCurrentUser
          ? 'This is how your profile appears to other users'
          : 'Send a message to connect with ${widget.vendor.displayName}',
      type: _isCurrentUser ? StatusType.info : StatusType.info,
      showIcon: true,
    );
  }
}
