import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../../application/settings_service.dart';
import '../../../../core/models/user_settings.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../shared/presentation/widgets/version_display_widget.dart';
import '../../../../main.dart' as main;

/// Settings & Help Screen for MarketSnap
/// Implements Phase 3.4 MVP requirements:
/// - Toggles: coarse location, auto-compress video, save-to-device default
/// - External link to support email
/// - Display free-storage indicator (≥ 100 MB check)
class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsScreen({super.key, required this.settingsService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings? _currentSettings;
  String? _storageStatus;
  bool? _hasSufficientStorage; // Cache storage check result
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    developer.log(
      '[SettingsScreen] Initializing settings screen',
      name: 'SettingsScreen',
    );
    _loadSettings();
  }

  /// Load current settings and storage information
  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      developer.log(
        '[SettingsScreen] Loading current settings...',
        name: 'SettingsScreen',
      );

      // Load current settings
      final settings = widget.settingsService.getCurrentSettings();

      // ✅ PERFORMANCE FIX: Load storage status using cached values
      final storageStatus = await widget.settingsService
          .getStorageStatusMessage();
      final hasSufficientStorage = await widget.settingsService
          .hasSufficientStorage();

      setState(() {
        _currentSettings = settings;
        _storageStatus = storageStatus;
        _hasSufficientStorage = hasSufficientStorage;
        _isLoading = false;
      });

      developer.log(
        '[SettingsScreen] Settings loaded successfully: $settings',
        name: 'SettingsScreen',
      );
      developer.log(
        '[SettingsScreen] Storage status: $storageStatus',
        name: 'SettingsScreen',
      );
      developer.log(
        '[SettingsScreen] Has sufficient storage: $hasSufficientStorage',
        name: 'SettingsScreen',
      );
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error loading settings: $e',
        name: 'SettingsScreen',
      );
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  /// Update a specific setting
  Future<void> _updateSetting({
    bool? enableCoarseLocation,
    bool? autoCompressVideo,
    bool? saveToDeviceDefault,
  }) async {
    if (_currentSettings == null) return;

    try {
      developer.log(
        '[SettingsScreen] Updating setting...',
        name: 'SettingsScreen',
      );

      await widget.settingsService.updateSettings(
        enableCoarseLocation: enableCoarseLocation,
        autoCompressVideo: autoCompressVideo,
        saveToDeviceDefault: saveToDeviceDefault,
      );

      // Reload settings to get updated values
      final updatedSettings = widget.settingsService.getCurrentSettings();

      setState(() {
        _currentSettings = updatedSettings;
      });

      developer.log(
        '[SettingsScreen] Setting updated successfully',
        name: 'SettingsScreen',
      );

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error updating setting: $e',
        name: 'SettingsScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Open support email
  Future<void> _openSupportEmail() async {
    try {
      developer.log(
        '[SettingsScreen] Opening support email...',
        name: 'SettingsScreen',
      );

      final success = await widget.settingsService.openSupportEmail();

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please email support@marketsnap.app directly.',
            ),
            backgroundColor: AppColors.sunsetAmber,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (success && mounted) {
        // Optional: Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening email app...'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error opening support email: $e',
        name: 'SettingsScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening support: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Refresh storage information
  /// ✅ PERFORMANCE FIX: Uses explicit cache refresh for manual updates
  Future<void> _refreshStorage() async {
    try {
      developer.log(
        '[SettingsScreen] Refreshing storage information...',
        name: 'SettingsScreen',
      );

      // Show loading state for refresh
      setState(() {
        _storageStatus = 'Refreshing...';
      });

      // ✅ PERFORMANCE FIX: Force refresh storage cache
      await widget.settingsService.refreshStorageCache();

      // Get updated values from refreshed cache
      final storageStatus = await widget.settingsService
          .getStorageStatusMessage();
      final hasSufficientStorage = await widget.settingsService
          .hasSufficientStorage();

      setState(() {
        _storageStatus = storageStatus;
        _hasSufficientStorage = hasSufficientStorage;
      });

      developer.log(
        '[SettingsScreen] Storage refreshed: $storageStatus',
        name: 'SettingsScreen',
      );
      developer.log(
        '[SettingsScreen] Storage sufficiency refreshed: $hasSufficientStorage',
        name: 'SettingsScreen',
      );

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage information updated'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error refreshing storage: $e',
        name: 'SettingsScreen',
      );

      setState(() {
        _storageStatus = 'Refresh failed';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh storage: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 3),
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
        title: Text(
          'Settings & Help',
          style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
        ),
        backgroundColor: AppColors.cornsilk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.soilCharcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message
                    if (_errorMessage != null) ...[
                      MarketSnapStatusMessage(
                        message: _errorMessage!,
                        type: StatusType.error,
                        showIcon: true,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // App Settings Section
                    Text(
                      'App Settings',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Configure your MarketSnap preferences',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (_currentSettings != null) _buildSettingsCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // Storage Information Section
                    Text(
                      'Storage Information',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Monitor your device storage usage',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildStorageCard(),
                    const SizedBox(height: AppSpacing.xl),

                    // Help & Support Section
                    Text(
                      'Help & Support',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Get assistance and contact support',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildHelpCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // Account Management Section
                    Text(
                      'Account',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your account settings',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildAccountCard(),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build settings toggles card
  Widget _buildSettingsCard() {
    return MarketSnapCard(
      child: Column(
        children: [
          // Coarse Location Toggle
          _buildSettingToggle(
            title: 'Location Tagging',
            description: 'Include approximate location with your snaps',
            value: _currentSettings!.enableCoarseLocation,
            onChanged: (value) => _updateSetting(enableCoarseLocation: value),
            icon: Icons.location_on_outlined,
          ),

          const Divider(color: AppColors.seedBrown, height: AppSpacing.lg),

          // Auto Compress Video Toggle
          _buildSettingToggle(
            title: 'Auto-Compress Videos',
            description: 'Automatically compress videos to save bandwidth',
            value: _currentSettings!.autoCompressVideo,
            onChanged: (value) => _updateSetting(autoCompressVideo: value),
            icon: Icons.video_settings_outlined,
          ),

          const Divider(color: AppColors.seedBrown, height: AppSpacing.lg),

          // Save to Device Toggle
          _buildSettingToggle(
            title: 'Save to Device',
            description: 'Keep a copy of posted media in your gallery',
            value: _currentSettings!.saveToDeviceDefault,
            onChanged: (value) => _updateSetting(saveToDeviceDefault: value),
            icon: Icons.save_alt_outlined,
          ),
        ],
      ),
    );
  }

  /// Build individual setting toggle
  Widget _buildSettingToggle({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.marketBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.marketBlue, size: 20),
        ),

        const SizedBox(width: AppSpacing.md),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.soilCharcoal,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: AppTypography.caption.copyWith(
                  color: AppColors.soilTaupe,
                ),
              ),
            ],
          ),
        ),

        // Toggle switch
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.leafGreen,
          inactiveThumbColor: AppColors.soilTaupe,
          inactiveTrackColor: AppColors.seedBrown.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  /// Build storage information card
  Widget _buildStorageCard() {
    return MarketSnapCard(
      child: Column(
        children: [
          // Storage status row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.harvestOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storage_outlined,
                  color: AppColors.harvestOrange,
                  size: 20,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Storage',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _storageStatus ?? 'Calculating...',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                  ],
                ),
              ),

              // Refresh button
              IconButton(
                onPressed: _refreshStorage,
                icon: const Icon(Icons.refresh, color: AppColors.marketBlue),
                tooltip: 'Refresh storage info',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Storage warning if needed
          if (_hasSufficientStorage == false)
            MarketSnapStatusMessage(
              message:
                  'Low storage: Consider freeing up space for optimal performance',
              type: StatusType.warning,
              showIcon: true,
            ),
        ],
      ),
    );
  }

  /// Build help and support card
  Widget _buildHelpCard() {
    return MarketSnapCard(
      child: Column(
        children: [
          // Support email option
          InkWell(
            onTap: _openSupportEmail,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      color: AppColors.leafGreen,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Support',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.soilCharcoal,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Get help from our support team',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.soilTaupe,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.soilTaupe,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // App version info
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cornsilk,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.seedBrown.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'MarketSnap',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.marketBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Connecting farmers markets with the community',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.soilTaupe,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const VersionDisplayWidget(
                  showBuildNumber: true,
                  alignment: Alignment.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build account management card
  Widget _buildAccountCard() {
    return MarketSnapCard(
      child: Column(
        children: [
          // Delete Account option
          InkWell(
            onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: _isDeletingAccount ? 0.6 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.appleRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isDeletingAccount
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.appleRed,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.delete_forever_outlined,
                              color: AppColors.appleRed,
                              size: 20,
                            ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _isDeletingAccount
                                  ? AppColors.soilTaupe
                                  : AppColors.appleRed,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Permanently delete your account and all data',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.soilTaupe,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!_isDeletingAccount)
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.soilTaupe,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show account deletion confirmation dialog
  Future<void> _confirmDeleteAccount() async {
    developer.log(
      '[SettingsScreen] User initiated account deletion confirmation',
      name: 'SettingsScreen',
    );

    try {
      // Get user data summary
      final dataSummary = await main.accountDeletionService.getUserDataSummary();
      
      if (!mounted) return;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildDeleteConfirmationDialog(dataSummary),
      );

      if (confirmed == true) {
        await _executeAccountDeletion();
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error preparing account deletion: $e',
        name: 'SettingsScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to prepare account deletion: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Build delete account confirmation dialog
  Widget _buildDeleteConfirmationDialog(Map<String, dynamic> dataSummary) {
    final profileType = dataSummary['profileType'] ?? 'none';
    final displayName = dataSummary['displayName'] ?? 'Unknown';
    final snapsCount = dataSummary['snapsCount'] ?? 0;
    final messagesCount = dataSummary['messagesCount'] ?? 0;
    final followersCount = dataSummary['followersCount'] ?? 0;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.appleRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_outlined,
              color: AppColors.appleRed,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Delete Account',
              style: AppTypography.h2.copyWith(
                color: AppColors.appleRed,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to permanently delete your account?',
            style: AppTypography.bodyLG.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.soilCharcoal,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // User profile info
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cornsilk,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.seedBrown.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account: $displayName',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.soilCharcoal,
                  ),
                ),
                Text(
                  'Type: ${profileType == 'vendor' ? 'Vendor' : 'Regular User'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.soilTaupe,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                
                Text(
                  'Data to be deleted:',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.soilCharcoal,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                
                _buildDataItem('📸 Snaps', snapsCount),
                _buildDataItem('💬 Messages', messagesCount),
                if (profileType == 'vendor') _buildDataItem('👥 Followers', followersCount),
                _buildDataItem('📱 Local data', 1),
                _buildDataItem('🔐 Account', 1),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.appleRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.appleRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.appleRed,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This action cannot be undone. All your data will be permanently deleted.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.appleRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.body.copyWith(
              color: AppColors.soilTaupe,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.appleRed,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Delete Forever',
            style: AppTypography.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build data item for confirmation dialog
  Widget _buildDataItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.soilTaupe,
            ),
          ),
          Text(
            count.toString(),
            style: AppTypography.caption.copyWith(
              color: AppColors.soilCharcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Execute account deletion
  Future<void> _executeAccountDeletion() async {
    developer.log(
      '[SettingsScreen] Executing account deletion',
      name: 'SettingsScreen',
    );

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      // Show progress indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text('Deleting account...'),
              ],
            ),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(minutes: 2), // Long duration for deletion process
          ),
        );
      }

      // Perform account deletion
      await main.accountDeletionService.deleteAccount();

      developer.log(
        '[SettingsScreen] Account deletion completed successfully',
        name: 'SettingsScreen',
      );

      // Clear snackbar and show success message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully. Redirecting to login...'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 3),
          ),
        );
        
        // The AuthWrapper will automatically detect the user is signed out
        // and redirect to AuthWelcomeScreen - no manual navigation needed
        developer.log(
          '[SettingsScreen] User signed out, AuthWrapper will handle redirect',
          name: 'SettingsScreen',
        );

        // Add debugging to monitor auth state changes
        developer.log(
          '[SettingsScreen] Current auth service user: ${main.authService.currentUser?.uid ?? 'null'}',
          name: 'SettingsScreen',
        );
        developer.log(
          '[SettingsScreen] Is authenticated: ${main.authService.isAuthenticated}',
          name: 'SettingsScreen',
        );

        // Force navigation as backup if AuthWrapper doesn't respond quickly
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && main.authService.currentUser == null) {
            developer.log(
              '[SettingsScreen] Force navigating to root - user is null after delay',
              name: 'SettingsScreen',
            );
            
            // Navigate to the root and let AuthWrapper handle the auth state
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Account deletion failed: $e',
        name: 'SettingsScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deletion failed: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }
}
