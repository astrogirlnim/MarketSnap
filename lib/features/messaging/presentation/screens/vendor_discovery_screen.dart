import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/features/auth/application/auth_service.dart';
import 'package:marketsnap/features/messaging/presentation/screens/chat_screen.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:marketsnap/main.dart';

class VendorDiscoveryScreen extends StatefulWidget {
  const VendorDiscoveryScreen({super.key});

  @override
  State<VendorDiscoveryScreen> createState() => _VendorDiscoveryScreenState();
}

class _VendorDiscoveryScreenState extends State<VendorDiscoveryScreen> {
  final AuthService _authService = authService;
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
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUserId = _authService.getCurrentUser()?.uid;
      if (currentUserId == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Fetch all vendors except the current user
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where('isComplete', isEqualTo: true)
          .get();

      final vendors = querySnapshot.docs
          .map((doc) => VendorProfile.fromMap(doc.data(), doc.id))
          .where((vendor) => vendor.uid != currentUserId) // Exclude current user
          .toList();

      setState(() {
        _vendors = vendors;
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

  void _startConversation(VendorProfile vendor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(otherUser: vendor),
      ),
    );
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.appleRed,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading vendors',
              style: AppTypography.h2.copyWith(color: AppColors.appleRed),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadVendors,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.marketBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vendors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.soilTaupe,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No vendors found',
              style: AppTypography.h2.copyWith(color: AppColors.soilTaupe),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Check back later for more vendors in your area',
              style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadVendors,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.marketBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVendors,
      color: AppColors.marketBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _vendors.length,
        itemBuilder: (context, index) {
          final vendor = _vendors[index];
          return _buildVendorCard(vendor);
        },
      ),
    );
  }

  Widget _buildVendorCard(VendorProfile vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppColors.eggshell,
      child: InkWell(
        onTap: () => _startConversation(vendor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.marketBlue,
                backgroundImage: vendor.avatarUrl.isNotEmpty
                    ? NetworkImage(vendor.avatarUrl)
                    : null,
                child: vendor.avatarUrl.isEmpty
                    ? Text(
                        vendor.displayName.isNotEmpty
                            ? vendor.displayName[0].toUpperCase()
                            : 'V',
                        style: AppTypography.h2.copyWith(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              
              // Vendor info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.displayName,
                      style: AppTypography.bodyLG.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.soilCharcoal,
                      ),
                    ),
                    if (vendor.stallName.isNotEmpty && vendor.stallName != vendor.displayName) ...[
                      const SizedBox(height: 2),
                      Text(
                        vendor.stallName,
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                        ),
                      ),
                    ],
                    if (vendor.marketCity.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.soilTaupe,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vendor.marketCity,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.soilTaupe,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (vendor.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        vendor.bio,
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Message button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.marketBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.message_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 