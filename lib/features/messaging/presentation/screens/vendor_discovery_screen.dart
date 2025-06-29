import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/features/auth/application/auth_service.dart';
import 'package:marketsnap/features/messaging/presentation/screens/chat_screen.dart';
import 'package:marketsnap/features/profile/presentation/screens/vendor_profile_view_screen.dart';

import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:marketsnap/main.dart' as main;
import 'package:marketsnap/features/profile/application/profile_service.dart';

class VendorDiscoveryScreen extends StatefulWidget {
  const VendorDiscoveryScreen({super.key});

  @override
  State<VendorDiscoveryScreen> createState() => _VendorDiscoveryScreenState();
}

class _VendorDiscoveryScreenState extends State<VendorDiscoveryScreen> {
  final AuthService _authService = main.authService;
  List<VendorProfile> _vendors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _error = 'Please log in to discover vendors';
          _isLoading = false;
        });
        return;
      }

      debugPrint(
        '[VendorDiscoveryScreen] Loading vendors for user: $currentUserId',
      );

      // First, try to get all vendors
      final snapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .get();

      debugPrint(
        '[VendorDiscoveryScreen] Total vendors found: ${snapshot.docs.length}',
      );

      final allVendors = snapshot.docs
          .map((doc) {
            debugPrint('[VendorDiscoveryScreen] Processing vendor: ${doc.id}');
            try {
              return VendorProfile.fromFirestore(doc.data(), doc.id);
            } catch (e) {
              debugPrint(
                '[VendorDiscoveryScreen] Error parsing vendor ${doc.id}: $e',
              );
              return null;
            }
          })
          .where((vendor) => vendor != null)
          .cast<VendorProfile>()
          .where(
            (vendor) => vendor.uid != currentUserId,
          ) // Exclude current user
          .toList();

      debugPrint(
        '[VendorDiscoveryScreen] Vendors after filtering: ${allVendors.length}',
      );

      setState(() {
        _vendors = allVendors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[VendorDiscoveryScreen] Error loading vendors: $e');
      setState(() {
        _error = 'Failed to load vendors: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Vendors'),
        backgroundColor: AppColors.eggshell,
        foregroundColor: AppColors.soilCharcoal,
        elevation: 0,
      ),
      backgroundColor: AppColors.cornsilk,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Error', style: AppTypography.bodyLG),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _loadVendors();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _vendors.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.store_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text('No vendors found', style: AppTypography.bodyLG),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new vendors',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _vendors.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final vendor = _vendors[index];
                return _VendorCard(
                  vendor: vendor,
                  profileService: main.profileService,
                  onMessageTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(otherUser: vendor),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorProfile vendor;
  final ProfileService profileService;
  final VoidCallback onMessageTap;

  const _VendorCard({
    required this.vendor,
    required this.profileService,
    required this.onMessageTap,
  });

  /// ✅ ADD: Cross-platform URL rewriting for avatars to fix iOS emulator Firebase Storage access
  String _rewriteUrlForCurrentPlatform(String originalUrl) {
    // Only rewrite Firebase Storage emulator URLs
    if (!originalUrl.contains('googleapis.com') && 
        (originalUrl.contains('localhost') || originalUrl.contains('10.0.2.2'))) {
      
      debugPrint('[VendorDiscoveryScreen] 🔄 Avatar URL rewriting for cross-platform compatibility');
      debugPrint('[VendorDiscoveryScreen] - Original URL: $originalUrl');
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: Convert Android emulator URL to iOS format
        final rewritten = originalUrl.replaceAll('10.0.2.2', 'localhost');
        debugPrint('[VendorDiscoveryScreen] - iOS rewrite: $rewritten');
        return rewritten;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Android: Convert iOS emulator URL to Android format  
        final rewritten = originalUrl.replaceAll('localhost', '10.0.2.2');
        debugPrint('[VendorDiscoveryScreen] - Android rewrite: $rewritten');
        return rewritten;
      }
    }
    
    // No rewriting needed for production URLs or non-emulator environments
    return originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            vendor.avatarURL?.isNotEmpty == true
                ? CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(_rewriteUrlForCurrentPlatform(vendor.avatarURL!)),
                    backgroundColor: AppColors.marketBlue,
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('[VendorDiscoveryScreen] ❌ Avatar load error for ${vendor.displayName}: $exception');
                    },
                  )
                : CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.marketBlue,
                    child: Text(
                      vendor.displayName.isNotEmpty
                          ? vendor.displayName[0].toUpperCase()
                          : '?',
                      style: AppTypography.bodyLG.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.displayName,
                    style: AppTypography.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vendor.stallName,
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilTaupe,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vendor.marketCity,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                // View Profile Button
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VendorProfileViewScreen(
                          vendor: vendor,
                          profileService: profileService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.marketBlue.withValues(
                      alpha: 0.1,
                    ),
                    foregroundColor: AppColors.marketBlue,
                  ),
                  tooltip: 'View Profile',
                ),
                const SizedBox(height: AppSpacing.xs),
                // Message Button
                IconButton(
                  onPressed: onMessageTap,
                  icon: const Icon(Icons.message),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.leafGreen.withValues(alpha: 0.1),
                    foregroundColor: AppColors.leafGreen,
                  ),
                  tooltip: 'Send Message',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
