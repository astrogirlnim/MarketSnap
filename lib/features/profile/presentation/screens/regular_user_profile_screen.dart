import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

import '../../application/profile_service.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../auth/application/auth_service.dart';

/// Regular User Profile Form Screen
/// Simplified profile for regular users (no stall info, just basic profile)
class RegularUserProfileScreen extends StatefulWidget {
  final ProfileService profileService;
  final VoidCallback? onProfileComplete;
  final bool isInTabNavigation;

  const RegularUserProfileScreen({
    super.key,
    required this.profileService,
    this.onProfileComplete,
    this.isInTabNavigation = false,
  });

  @override
  State<RegularUserProfileScreen> createState() =>
      _RegularUserProfileScreenState();
}

class _RegularUserProfileScreenState extends State<RegularUserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();

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
    super.dispose();
  }

  /// Loads existing profile data if available
  Future<void> _loadExistingProfile() async {
    developer.log(
      '[RegularUserProfileScreen] Loading existing profile data',
      name: 'RegularUserProfileScreen',
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final regularProfile = widget.profileService
          .getCurrentRegularUserProfile();
      if (regularProfile != null) {
        developer.log(
          '[RegularUserProfileScreen] Found existing regular profile: ${regularProfile.displayName}',
          name: 'RegularUserProfileScreen',
        );
        setState(() {
          _displayNameController.text = regularProfile.displayName;
          _localAvatarPath = regularProfile.localAvatarPath;
        });
      } else {
        developer.log(
          '[RegularUserProfileScreen] No existing regular profile found',
          name: 'RegularUserProfileScreen',
        );
      }
    } catch (e) {
      developer.log(
        '[RegularUserProfileScreen] Error loading profile: $e',
        name: 'RegularUserProfileScreen',
      );
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
  Future<void> _pickAvatar({required bool fromCamera}) async {
    developer.log(
      '[RegularUserProfileScreen] Picking avatar from ${fromCamera ? 'camera' : 'gallery'}',
      name: 'RegularUserProfileScreen',
    );

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _localAvatarPath = image.path;
        });
        developer.log(
          '[RegularUserProfileScreen] Avatar selected: ${image.path}',
          name: 'RegularUserProfileScreen',
        );
      }
    } catch (e) {
      developer.log(
        '[RegularUserProfileScreen] Error picking avatar: $e',
        name: 'RegularUserProfileScreen',
      );
      _showErrorMessage('Failed to select avatar: $e');
    }
  }

  /// Shows avatar selection options
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.eggshell,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusLg),
          topRight: Radius.circular(AppSpacing.radiusLg),
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

  /// Validates display name
  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name is required';
    }
    if (value.trim().length < 2) {
      return 'Display name must be at least 2 characters';
    }
    return null;
  }

  /// Saves the profile
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    developer.log(
      '[RegularUserProfileScreen] Saving regular user profile',
      name: 'RegularUserProfileScreen',
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.profileService.saveRegularUserProfile(
        displayName: _displayNameController.text,
        localAvatarPath: _localAvatarPath,
      );

      developer.log(
        '[RegularUserProfileScreen] Regular profile saved successfully',
        name: 'RegularUserProfileScreen',
      );

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
      developer.log(
        '[RegularUserProfileScreen] Error saving profile: $e',
        name: 'RegularUserProfileScreen',
      );
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
          'Optional - helps vendors recognize you',
          style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Navigate to settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  /// Sign out the current user
  Future<void> _signOut() async {
    debugPrint('[RegularUserProfileScreen] User sign out requested');

    // Show confirmation dialog
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.eggshell,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Sign Out', style: AppTypography.h2),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.appleRed),
            child: Text(
              'Sign Out',
              style: AppTypography.body.copyWith(
                color: AppColors.appleRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.eggshell,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          content: Row(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
              ),
              const SizedBox(width: 20),
              Text('Signing out...', style: AppTypography.body),
            ],
          ),
        ),
      );
    }

    try {
      await _authService.signOut();
      debugPrint('[RegularUserProfileScreen] User signed out successfully');

      // Close loading dialog and navigate to auth
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/', (route) => false); // Go to auth
      }
    } catch (e) {
      debugPrint('[RegularUserProfileScreen] Error signing out: $e');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MarketSnapStatusMessage(
              message: 'Error signing out: $e',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: widget.isInTabNavigation
          ? AppBar(
              backgroundColor: AppColors.cornsilk,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'My Profile',
                style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: AppColors.soilCharcoal,
                  ),
                  onPressed: _navigateToSettings,
                  tooltip: 'Settings',
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.appleRed),
                  onPressed: _signOut,
                  tooltip: 'Sign Out',
                ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.cornsilk,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.soilCharcoal,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Set up your profile',
                style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
              ),
              centerTitle: true,
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
                      if (!widget.isInTabNavigation) ...[
                        Text(
                          'Welcome to the community!',
                          style: AppTypography.h2,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Set up your profile to connect with vendors and discover fresh finds.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.soilTaupe,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

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
                        hintText: 'Your name as it appears to vendors',
                        controller: _displayNameController,
                        prefixIcon: Icons.person,
                        validator: _validateDisplayName,
                      ),
                      const SizedBox(height: AppSpacing.lg),

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
                            'Profile saved locally and will sync when connected to internet',
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
