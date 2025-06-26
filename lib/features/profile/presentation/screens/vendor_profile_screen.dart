import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../application/profile_service.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/application/settings_service.dart';
import '../../../../main.dart' as main;

/// Vendor Profile Form Screen
/// Allows vendors to create/edit their profile with stall name, market city, and avatar upload
class VendorProfileScreen extends StatefulWidget {
  final ProfileService profileService;
  final VoidCallback? onProfileComplete;
  final bool isInTabNavigation;

  const VendorProfileScreen({
    super.key,
    required this.profileService,
    this.onProfileComplete,
    this.isInTabNavigation = false,
  });

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _stallNameController = TextEditingController();
  final _marketCityController = TextEditingController();

  // Note: Location setting now managed in Settings & Help screen
  String? _localAvatarPath;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _stallNameController.dispose();
    _marketCityController.dispose();
    super.dispose();
  }

  /// Loads existing profile data if available
  Future<void> _loadExistingProfile() async {
    debugPrint('[VendorProfileScreen] Loading existing profile data');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = widget.profileService.getCurrentUserProfile();
      if (profile != null) {
        debugPrint(
          '[VendorProfileScreen] Found existing profile: ${profile.stallName}',
        );
        setState(() {
          _displayNameController.text = profile.displayName;
          _stallNameController.text = profile.stallName;
          _marketCityController.text = profile.marketCity;
          _localAvatarPath = profile.localAvatarPath;
        });
      } else {
        debugPrint('[VendorProfileScreen] No existing profile found');
      }
    } catch (e) {
      debugPrint('[VendorProfileScreen] Error loading profile: $e');
      setState(() {
        _errorMessage = 'Failed to load profile data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handles avatar image selection
  Future<void> _pickAvatar({bool fromCamera = false}) async {
    debugPrint(
      '[VendorProfileScreen] Picking avatar from ${fromCamera ? 'camera' : 'gallery'}',
    );

    try {
      final imagePath = await widget.profileService.pickAvatarImage(
        fromCamera: fromCamera,
      );
      if (imagePath != null) {
        setState(() {
          _localAvatarPath = imagePath;
        });
        debugPrint('[VendorProfileScreen] Avatar selected: $imagePath');
      }
    } catch (e) {
      debugPrint('[VendorProfileScreen] Error picking avatar: $e');
      _showErrorMessage('Failed to select avatar: $e');
    }
  }

  /// Shows avatar selection options
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.eggshell,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.edgeInsetsLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose Avatar Photo', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.lg),
                MarketSnapSecondaryButton(
                  text: 'Take Photo',
                  icon: Icons.camera_alt,
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAvatar(fromCamera: true);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                MarketSnapSecondaryButton(
                  text: 'Choose from Gallery',
                  icon: Icons.photo_library,
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAvatar(fromCamera: false);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_localAvatarPath != null)
                  MarketSnapSecondaryButton(
                    text: 'Remove Photo',
                    icon: Icons.delete,
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _localAvatarPath = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Validates form data
  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name is required';
    }
    if (value.trim().length < 2) {
      return 'Display name must be at least 2 characters';
    }
    return null;
  }

  String? _validateStallName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Stall name is required';
    }
    if (value.trim().length < 3) {
      return 'Stall name must be at least 3 characters';
    }
    return null;
  }

  String? _validateMarketCity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Market city is required';
    }
    if (value.trim().length < 2) {
      return 'Market city must be at least 2 characters';
    }
    return null;
  }

  /// Saves the profile
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    debugPrint('[VendorProfileScreen] Saving profile');

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.profileService.saveProfile(
        displayName: _displayNameController.text,
        stallName: _stallNameController.text,
        marketCity: _marketCityController.text,
        allowLocation: false, // Default - managed in Settings
        localAvatarPath: _localAvatarPath,
      );

      debugPrint('[VendorProfileScreen] Profile saved successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MarketSnapStatusMessage(
              message: 'Profile saved successfully!',
              type: StatusType.success,
              showIcon: true,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 3),
          ),
        );

        // Call completion callback
        widget.onProfileComplete?.call();
      }
    } catch (e) {
      debugPrint('[VendorProfileScreen] Error saving profile: $e');
      _showErrorMessage('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Shows error message
  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  /// Builds the avatar section
  Widget _buildAvatarSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showAvatarOptions,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.eggshell,
              border: Border.all(color: AppColors.seedBrown, width: 2),
            ),
            child: _localAvatarPath != null
                ? ClipOval(
                    child: Image.file(
                      File(_localAvatarPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppColors.soilTaupe,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person_add_alt_1,
                    size: 48,
                    color: AppColors.marketBlue,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _showAvatarOptions,
          child: Text(
            _localAvatarPath != null ? 'Change Avatar' : 'Add Avatar',
            style: AppTypography.body.copyWith(
              color: AppColors.marketBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optional - helps customers recognize your stall',
          style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    developer.log(
      '[VendorProfileScreen] Navigating to settings screen',
      name: 'VendorProfileScreen',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          settingsService: SettingsService(hiveService: main.hiveService),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: AppBar(
        title: Text('Vendor Profile', style: AppTypography.h1),
        backgroundColor: AppColors.cornsilk,
        elevation: 0,
        // Hide back button in these cases:
        // 1. During initial profile setup (when onProfileComplete is provided)
        // 2. When used in tab navigation (nowhere to go back to)
        leading: (widget.onProfileComplete != null || widget.isInTabNavigation)
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.soilCharcoal,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
        // Disable automatic back button during initial setup or tab navigation
        automaticallyImplyLeading:
            widget.onProfileComplete == null && !widget.isInTabNavigation,
        actions: [
          // Settings button for navigation to settings screen
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.soilCharcoal),
            onPressed: () => _navigateToSettings(context),
            tooltip: 'Settings & Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.edgeInsetsLg,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Set up your market stall profile',
                        style: AppTypography.h2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'This information helps customers find and recognize your stall at the farmers market.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Avatar Section
                      Center(child: _buildAvatarSection()),
                      const SizedBox(height: AppSpacing.xl),

                      // Error Message
                      if (_errorMessage != null) ...[
                        MarketSnapStatusMessage(
                          message: _errorMessage!,
                          type: StatusType.error,
                          showIcon: true,
                          onDismiss: () => setState(() => _errorMessage = null),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Form Fields
                      MarketSnapTextField(
                        labelText: 'Display Name',
                        hintText: 'Your name as customers will see it',
                        controller: _displayNameController,
                        prefixIcon: Icons.person,
                        validator: _validateDisplayName,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      MarketSnapTextField(
                        labelText: 'Stall Name',
                        hintText: 'e.g., "Fresh Valley Produce"',
                        controller: _stallNameController,
                        prefixIcon: Icons.store,
                        validator: _validateStallName,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      MarketSnapTextField(
                        labelText: 'Market City',
                        hintText: 'e.g., "Springfield"',
                        controller: _marketCityController,
                        prefixIcon: Icons.location_city,
                        validator: _validateMarketCity,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Note: Location setting moved to Settings & Help screen
                      const SizedBox(height: AppSpacing.md),

                      // Save Button
                      MarketSnapPrimaryButton(
                        text: 'Save Profile',
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                        icon: Icons.save,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Offline Notice
                      MarketSnapStatusMessage(
                        message:
                            'Your profile is saved locally and will sync when you\'re online',
                        type: StatusType.info,
                        showIcon: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
