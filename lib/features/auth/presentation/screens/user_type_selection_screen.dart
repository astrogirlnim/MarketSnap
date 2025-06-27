import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../core/models/user_type.dart';

/// Screen for selecting user type (vendor or regular user) after authentication
class UserTypeSelectionScreen extends StatefulWidget {
  final Function(UserType) onUserTypeSelected;

  const UserTypeSelectionScreen({super.key, required this.onUserTypeSelected});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  UserType? _selectedUserType;

  @override
  Widget build(BuildContext context) {
    developer.log(
      '[UserTypeSelectionScreen] Building user type selection screen',
      name: 'UserTypeSelectionScreen',
    );

    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // No back button since this is part of onboarding
        title: Text(
          'Welcome to MarketSnap!',
          style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.edgeInsetsScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Welcome message
              Text('Choose your role', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This helps us customize your MarketSnap experience.',
                style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Vendor option
              _buildUserTypeCard(
                userType: UserType.vendor,
                title: UserType.vendor.displayName,
                description: UserType.vendor.description,
                icon: Icons.storefront_outlined,
                isSelected: _selectedUserType == UserType.vendor,
                onTap: () {
                  setState(() {
                    _selectedUserType = UserType.vendor;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Regular user option
              _buildUserTypeCard(
                userType: UserType.regular,
                title: UserType.regular.displayName,
                description: UserType.regular.description,
                icon: Icons.person_outlined,
                isSelected: _selectedUserType == UserType.regular,
                onTap: () {
                  setState(() {
                    _selectedUserType = UserType.regular;
                  });
                },
              ),

              const Spacer(),

              // Continue button
              MarketSnapPrimaryButton(
                text: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: _selectedUserType != null
                    ? () {
                        developer.log(
                          '[UserTypeSelectionScreen] User selected: ${_selectedUserType!.displayName}',
                          name: 'UserTypeSelectionScreen',
                        );
                        widget.onUserTypeSelected(_selectedUserType!);
                      }
                    : null,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Help text
              Center(
                child: Text(
                  'You can always change this later in your settings.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.soilTaupe,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard({
    required UserType userType,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.edgeInsetsCard,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.marketBlue.withValues(alpha: 0.1)
              : AppColors.eggshell,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.marketBlue : AppColors.seedBrown,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.marketBlue : AppColors.soilTaupe,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.eggshell, size: 28),
            ),

            const SizedBox(width: AppSpacing.lg),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h2.copyWith(
                      color: isSelected
                          ? AppColors.marketBlue
                          : AppColors.soilCharcoal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.marketBlue, size: 24)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: AppColors.soilTaupe,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
