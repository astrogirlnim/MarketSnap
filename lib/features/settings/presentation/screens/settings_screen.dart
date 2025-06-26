import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../../application/settings_service.dart';
import '../../../../core/models/user_settings.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../shared/presentation/widgets/version_display_widget.dart';
import '../../../../core/services/account_deletion_service.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../features/auth/application/auth_service.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

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

      // Load storage status
      final storageStatus = await widget.settingsService
          .getStorageStatusMessage();

      setState(() {
        _currentSettings = settings;
        _storageStatus = storageStatus;
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
  Future<void> _refreshStorage() async {
    try {
      developer.log(
        '[SettingsScreen] Refreshing storage information...',
        name: 'SettingsScreen',
      );

      final storageStatus = await widget.settingsService
          .getStorageStatusMessage();

      setState(() {
        _storageStatus = storageStatus;
      });

      developer.log(
        '[SettingsScreen] Storage refreshed: $storageStatus',
        name: 'SettingsScreen',
      );
    } catch (e) {
      developer.log(
        '[SettingsScreen] Error refreshing storage: $e',
        name: 'SettingsScreen',
      );
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
                      'Account Management',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your account and data',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildAccountManagementCard(),

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
          FutureBuilder<bool>(
            future: widget.settingsService.hasSufficientStorage(),
            builder: (context, snapshot) {
              if (snapshot.hasData && !snapshot.data!) {
                return MarketSnapStatusMessage(
                  message:
                      'Low storage: Consider freeing up space for optimal performance',
                  type: StatusType.warning,
                  showIcon: true,
                );
              }
              return const SizedBox.shrink();
            },
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

  /// Build account management card with delete account option
  Widget _buildAccountManagementCard() {
    return MarketSnapCard(
      child: Column(
        children: [
          // Delete Account option
          InkWell(
            onTap: _showDeleteAccountDialog,
            borderRadius: BorderRadius.circular(8),
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
                    child: const Icon(
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
                            color: AppColors.appleRed,
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

                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.soilTaupe,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show initial delete account confirmation dialog
  Future<void> _showDeleteAccountDialog() async {
    final accountDeletionService = AccountDeletionService(
      hiveService: main.hiveService,
    );

    // Check if user can delete account
    if (!accountDeletionService.canDeleteAccount()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete account. Please ensure you are signed in.'),
            backgroundColor: AppColors.appleRed,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Get account data summary
    final dataSummary = await accountDeletionService.getAccountDataSummary();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.eggshell,
          title: Row(
            children: [
              const Icon(Icons.warning, color: AppColors.appleRed),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: AppTypography.h2.copyWith(color: AppColors.appleRed),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This action cannot be undone. The following data will be permanently deleted:',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 16),
                
                // Data summary
                if (dataSummary.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cornsilk,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.seedBrown.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        if (dataSummary['snaps'] != null)
                          _buildDataRow('Snaps', dataSummary['snaps']!),
                        if (dataSummary['messages'] != null)
                          _buildDataRow('Messages', dataSummary['messages']!),
                        if (dataSummary['pendingMedia'] != null)
                          _buildDataRow('Pending uploads', dataSummary['pendingMedia']!),
                        _buildDataRow('Profile data', 1),
                        _buildDataRow('Settings', 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  'Type "DELETE" to confirm:',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) {
                    // This will be handled in the stateful dialog
                  },
                  decoration: const InputDecoration(
                    hintText: 'Type DELETE here',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteAccountConfirmationDialog();
              },
              child: Text(
                'Continue',
                style: AppTypography.body.copyWith(
                  color: AppColors.appleRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build data row for account deletion summary
  Widget _buildDataRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption),
          Text(
            count.toString(),
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Show final confirmation dialog with typing verification
  Future<void> _showDeleteAccountConfirmationDialog() async {
    String confirmationText = '';
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.eggshell,
              title: Text(
                'Final Confirmation',
                style: AppTypography.h2.copyWith(color: AppColors.appleRed),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type "DELETE" to permanently delete your account:',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: !isDeleting,
                    onChanged: (value) {
                      setDialogState(() {
                        confirmationText = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
                  ),
                ),
                TextButton(
                  onPressed: confirmationText == 'DELETE' && !isDeleting
                      ? () => _executeAccountDeletion(setDialogState)
                      : null,
                  child: Text(
                    isDeleting ? 'Deleting...' : 'Delete Account',
                    style: AppTypography.body.copyWith(
                      color: confirmationText == 'DELETE' && !isDeleting
                          ? AppColors.appleRed
                          : AppColors.soilTaupe,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Execute the account deletion process
  Future<void> _executeAccountDeletion(StateSetter setDialogState) async {
    setDialogState(() {
      // This will be used to update the dialog state
    });

    final accountDeletionService = AccountDeletionService(
      hiveService: main.hiveService,
    );

    try {
      String currentProgress = 'Starting deletion process...';
      
      setDialogState(() {
        currentProgress = 'Starting deletion process...';
      });

      await accountDeletionService.deleteAccountCompletely(
        onProgress: (progress) {
          if (mounted) {
            setDialogState(() {
              currentProgress = progress;
            });
          }
          developer.log(
            '[SettingsScreen] Account deletion progress: $progress',
            name: 'SettingsScreen',
          );
        },
      );

      // Account deletion successful - close dialog and navigate to auth
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        // Navigate to auth screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: AppColors.leafGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      developer.log(
        '[SettingsScreen] Account deletion failed: $e',
        name: 'SettingsScreen',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: AppColors.appleRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
