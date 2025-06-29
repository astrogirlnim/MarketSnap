import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../application/profile_service.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../auth/application/auth_service.dart';
import 'vendor_knowledge_base_screen.dart';
import '../../../../core/services/profile_update_notifier.dart';
import '../../../../core/models/vendor_profile.dart';
import '../../../../main.dart' as main;
import 'dart:async';

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
  final AuthService _authService = AuthService();

  // Note: Location setting now managed in Settings & Help screen
  String? _localAvatarPath;
  String? _avatarURL;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSaving = false;
  StreamSubscription<VendorProfile>? _profileUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    
    // ✅ Listen for profile updates from sync process
    _profileUpdateSubscription = main.profileUpdateNotifier.vendorProfileUpdates.listen(_onProfileUpdate);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _stallNameController.dispose();
    _marketCityController.dispose();
    
    // ✅ Cancel profile update subscription
    _profileUpdateSubscription?.cancel();
    
    super.dispose();
  }

  /// ✅ Handle profile updates from sync process
  void _onProfileUpdate(VendorProfile profile) {
    // Only update if it's the current user's profile
    final currentUid = widget.profileService.currentUserUid;
    if (profile.uid == currentUid && mounted) {
      debugPrint('[VendorProfileScreen] 📢 Received profile update from sync - updating UI');
      setState(() {
        _displayNameController.text = profile.displayName;
        _stallNameController.text = profile.stallName;
        _marketCityController.text = profile.marketCity;
        _localAvatarPath = profile.localAvatarPath;
        _avatarURL = profile.avatarURL;
      });
      
      debugPrint('[VendorProfileScreen] ✅ UI updated with synced avatar state:');
      debugPrint('[VendorProfileScreen] - Local path: $_localAvatarPath');
      debugPrint('[VendorProfileScreen] - Remote URL: $_avatarURL');
    }
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
        debugPrint('[VendorProfileScreen] 🖼️ Avatar status:');
        debugPrint('[VendorProfileScreen] - localAvatarPath: ${profile.localAvatarPath}');
        debugPrint('[VendorProfileScreen] - avatarURL: ${profile.avatarURL}');
        
        setState(() {
          _displayNameController.text = profile.displayName;
          _stallNameController.text = profile.stallName;
          _marketCityController.text = profile.marketCity;
          _localAvatarPath = profile.localAvatarPath;
          _avatarURL = profile.avatarURL;
        });
        
        debugPrint('[VendorProfileScreen] ✅ Profile loaded with avatar state:');
        debugPrint('[VendorProfileScreen] - Local path: $_localAvatarPath');
        debugPrint('[VendorProfileScreen] - Remote URL: $_avatarURL');
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
          debugPrint('[VendorProfileScreen] 🖼️ New local avatar selected, clearing remote URL');
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
                if (_localAvatarPath != null || _avatarURL != null)
                  MarketSnapSecondaryButton(
                    text: 'Remove Photo',
                    icon: Icons.delete,
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _localAvatarPath = null;
                        _avatarURL = null;
                      });
                      debugPrint('[VendorProfileScreen] 🗑️ Avatar removed (both local and remote)');
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

    debugPrint('[VendorProfileScreen] 🔄 Starting profile save process');

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Save profile with comprehensive avatar handling
      await widget.profileService.saveProfile(
        displayName: _displayNameController.text,
        stallName: _stallNameController.text,
        marketCity: _marketCityController.text,
        allowLocation: false, // Default - managed in Settings
        localAvatarPath: _localAvatarPath,
      );

      debugPrint('[VendorProfileScreen] ✅ Profile saved successfully');

      // ✅ CRITICAL FIX: Wait for sync completion instead of arbitrary delay
      debugPrint('[VendorProfileScreen] ⏳ Waiting for sync process to complete...');
      final currentUid = widget.profileService.currentUserUid;
      if (currentUid != null) {
        final syncCompleted = await widget.profileService.waitForSyncCompletion(
          currentUid,
          timeout: const Duration(seconds: 15),
        );
        
        if (syncCompleted) {
          debugPrint('[VendorProfileScreen] ✅ Sync completed successfully');
          // Reload profile to get the final synced state
          await _loadExistingProfile();
        } else {
          debugPrint('[VendorProfileScreen] ⚠️ Sync timed out, but profile saved locally');
          // Still reload to get current state
          await _loadExistingProfile();
        }
      }

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
      debugPrint('[VendorProfileScreen] ❌ Error saving profile: $e');
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
    final bool hasLocalAvatar = _localAvatarPath != null;
    final bool hasRemoteAvatar = _avatarURL?.isNotEmpty == true;
    final bool hasAnyAvatar = hasLocalAvatar || hasRemoteAvatar;
    
    debugPrint('[VendorProfileScreen] 🖼️ Avatar display logic:');
    debugPrint('[VendorProfileScreen] - hasLocalAvatar: $hasLocalAvatar');
    debugPrint('[VendorProfileScreen] - hasRemoteAvatar: $hasRemoteAvatar');
    debugPrint('[VendorProfileScreen] - hasAnyAvatar: $hasAnyAvatar');
    debugPrint('[VendorProfileScreen] - _localAvatarPath: $_localAvatarPath');
    debugPrint('[VendorProfileScreen] - _avatarURL: $_avatarURL');
    
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
            child: hasAnyAvatar
                ? ClipOval(
                    child: hasLocalAvatar
                        ? Image.file(
                            File(_localAvatarPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('[VendorProfileScreen] ❌ Local avatar load error: $error');
                              return Icon(
                                Icons.broken_image,
                                size: 48,
                                color: AppColors.soilTaupe,
                              );
                            },
                          )
                        : Image.network(
                            _avatarURL!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                debugPrint('[VendorProfileScreen] ✅ Remote avatar loaded successfully');
                                return child;
                              }
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
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('[VendorProfileScreen] ❌ Remote avatar load error: $error');
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
            hasAnyAvatar ? 'Change Avatar' : 'Add Avatar',
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
        if (kDebugMode && hasAnyAvatar) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasLocalAvatar 
                ? '🔵 Local avatar selected (will upload)' 
                : '🟢 Synced avatar from server',
            style: AppTypography.caption.copyWith(
              color: hasLocalAvatar ? Colors.blue : Colors.green,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    developer.log(
      '[VendorProfileScreen] Navigating to settings screen',
      name: 'VendorProfileScreen',
    );

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  /// Navigate to vendor knowledge base screen
  void _navigateToKnowledgeBase(BuildContext context) {
    developer.log(
      '[VendorProfileScreen] Navigating to knowledge base screen',
      name: 'VendorProfileScreen',
    );

    Navigator.of(
      context,
    ).push(MaterialPageRoute(
      builder: (context) => const VendorKnowledgeBaseScreen(),
    ));
  }

  /// Sign out the current user
  Future<void> _signOut() async {
    debugPrint('[VendorProfileScreen] User sign out requested');

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
      debugPrint('[VendorProfileScreen] User signed out successfully');

      // Close loading dialog and navigate to auth
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/', (route) => false); // Go to auth
      }
    } catch (e) {
      debugPrint('[VendorProfileScreen] Error signing out: $e');

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
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.appleRed),
            onPressed: _signOut,
            tooltip: 'Sign Out',
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

                      // Vendor Management Section
                      Container(
                        width: double.infinity,
                        padding: AppSpacing.edgeInsetsCard,
                        decoration: BoxDecoration(
                          color: AppColors.leafGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.leafGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Smart Features',
                                  style: AppTypography.h2.copyWith(color: AppColors.leafGreen),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Manage your AI-powered customer assistance and view analytics.',
                              style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            MarketSnapSecondaryButton(
                              text: 'Knowledge Base',
                              icon: Icons.quiz,
                              onPressed: () => _navigateToKnowledgeBase(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Create FAQs that automatically appear when customers post about your products.',
                              style: AppTypography.caption.copyWith(color: AppColors.soilTaupe),
                            ),
                          ],
                        ),
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
