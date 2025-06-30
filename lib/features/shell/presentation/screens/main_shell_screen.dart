import 'package:flutter/material.dart';
import 'package:marketsnap/features/capture/presentation/screens/camera_preview_screen.dart';
import 'package:marketsnap/features/capture/application/camera_service.dart';
import 'package:marketsnap/features/feed/presentation/screens/feed_screen.dart';
import 'package:marketsnap/features/messaging/presentation/screens/conversation_list_screen.dart';
import 'package:marketsnap/features/profile/presentation/screens/vendor_profile_screen.dart';
import 'package:marketsnap/features/profile/presentation/screens/regular_user_profile_screen.dart';
import 'package:marketsnap/features/profile/application/profile_service.dart';
import 'package:marketsnap/core/services/hive_service.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';

class MainShellScreen extends StatefulWidget {
  final ProfileService profileService;
  final HiveService hiveService;

  const MainShellScreen({
    super.key,
    required this.profileService,
    required this.hiveService,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  final CameraService _cameraService = CameraService.instance;
  late final List<Widget> _widgetOptions;
  late final List<BottomNavigationBarItem> _navigationItems;
  late final bool _isVendor;

  @override
  void initState() {
    super.initState();
    _determineUserType();
    _setupNavigationForUserType();
  }

  /// Determines if the current user is a vendor or regular user
  void _determineUserType() {
    final uid = widget.profileService.currentUserUid;
    debugPrint('[MainShellScreen] Determining user type for UID: $uid');

    // Check if user has a vendor profile
    final vendorProfile = widget.profileService.getCurrentUserProfile();
    final regularProfile = widget.profileService.getCurrentRegularUserProfile();

    debugPrint(
      '[MainShellScreen] Vendor profile: ${vendorProfile != null ? 'EXISTS' : 'NULL'}',
    );
    debugPrint(
      '[MainShellScreen] Regular profile: ${regularProfile != null ? 'EXISTS' : 'NULL'}',
    );

    // For vendor UIDs (starting with 'vendor-'), prefer vendor type
    if (uid != null && uid.startsWith('vendor-')) {
      debugPrint('[MainShellScreen] UID suggests vendor type: $uid');
      _isVendor = true;
    } else if (uid != null && uid.startsWith('user-')) {
      debugPrint('[MainShellScreen] UID suggests regular user type: $uid');
      _isVendor = false;
    } else {
      // Fallback to profile-based detection
      _isVendor = vendorProfile != null && regularProfile == null;
    }

    debugPrint(
      '[MainShellScreen] User type detected: ${_isVendor ? 'Vendor' : 'Regular User'}',
    );
  }

  /// Sets up navigation tabs based on user type
  void _setupNavigationForUserType() {
    if (_isVendor) {
      // Vendor navigation: Feed, Camera, Messages, Profile
      _widgetOptions = <Widget>[
        const FeedScreen(),
        CameraPreviewScreen(hiveService: widget.hiveService),
        const ConversationListScreen(),
        VendorProfileScreen(
          profileService: widget.profileService,
          isInTabNavigation: true,
        ),
      ];

      _navigationItems = const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.storefront_rounded), // More market-themed than home
          label: 'Feed',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.camera_alt_rounded,
          ), // Rounded camera for friendliness
          label: 'Capture',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded), // More friendly than message
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle_rounded), // Rounded for friendliness
          label: 'Profile',
        ),
      ];
    } else {
      // Regular user navigation: Feed, Messages, Profile (no camera)
      _widgetOptions = <Widget>[
        const FeedScreen(),
        const ConversationListScreen(),
        RegularUserProfileScreen(
          profileService: widget.profileService,
          isInTabNavigation: true,
        ),
      ];

      _navigationItems = const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(
            Icons.shopping_basket_rounded,
          ), // Perfect for regular users browsing market
          label: 'Feed',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded), // Consistent with vendor
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle_rounded), // Consistent with vendor
          label: 'Profile',
        ),
      ];
    }
  }

  /// ✅ BUFFER OVERFLOW FIX: Handle tab navigation with camera lifecycle management
  void _onItemTapped(int index) {
    final int previousIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;
    });

    // ✅ BUFFER OVERFLOW FIX: Only manage camera lifecycle for vendors
    if (_isVendor) {
      _handleCameraVisibilityChange(previousIndex, index);
    }
  }

  /// ✅ CAMERA UNAVAILABLE FIX: Enhanced camera visibility change handling with better error recovery
  void _handleCameraVisibilityChange(int previousIndex, int currentIndex) {
    const int cameraTabIndex = 1; // Camera is at index 1 for vendors

    debugPrint('[MainShellScreen] ========== TAB NAVIGATION ==========');
    debugPrint(
      '[MainShellScreen] Previous tab: $previousIndex, Current tab: $currentIndex',
    );
    debugPrint('[MainShellScreen] Camera tab index: $cameraTabIndex');

    // If navigating away from camera tab, pause camera to free resources
    if (previousIndex == cameraTabIndex && currentIndex != cameraTabIndex) {
      debugPrint(
        '[MainShellScreen] 📱 Navigating AWAY from camera tab - pausing camera',
      );

      _cameraService.pauseCamera().catchError((error) {
        debugPrint('[MainShellScreen] ⚠️ Error pausing camera: $error');
      });
    }
    // If navigating to camera tab, resume camera with enhanced error handling
    else if (previousIndex != cameraTabIndex &&
        currentIndex == cameraTabIndex) {
      debugPrint(
        '[MainShellScreen] 📷 Navigating TO camera tab - resuming camera',
      );

      // ✅ CAMERA UNAVAILABLE FIX: Check if camera is already working before resuming
      if (_cameraService.controller?.value.isInitialized == true) {
        debugPrint(
          '[MainShellScreen] ✅ Camera already initialized and working, no resume needed',
        );
        return;
      }

      // ✅ CAMERA UNAVAILABLE FIX: Add small delay to allow tab transition to complete
      Future.delayed(const Duration(milliseconds: 100), () {
        _cameraService
            .resumeCamera()
            .then((success) {
              if (success) {
                debugPrint('[MainShellScreen] ✅ Camera resume successful');
              } else {
                debugPrint(
                  '[MainShellScreen] ❌ Camera resume failed - camera may show as unavailable',
                );
                debugPrint(
                  '[MainShellScreen] Last error: ${_cameraService.lastError ?? "No specific error provided"}',
                );

                // ✅ CAMERA UNAVAILABLE FIX: Force reset if stuck and retry
                if (_cameraService.isInitializingStuck) {
                  debugPrint(
                    '[MainShellScreen] Camera service stuck, forcing reset...',
                  );
                  _cameraService.forceResetInitialization();
                }

                // ✅ CAMERA UNAVAILABLE FIX: Trigger additional retry after a delay
                Future.delayed(const Duration(milliseconds: 500), () {
                  debugPrint(
                    '[MainShellScreen] 🔄 Attempting delayed camera recovery...',
                  );
                  _cameraService.resumeCamera().then((retrySuccess) {
                    if (retrySuccess) {
                      debugPrint(
                        '[MainShellScreen] ✅ Delayed camera recovery successful',
                      );
                    } else {
                      debugPrint(
                        '[MainShellScreen] ❌ Delayed camera recovery failed',
                      );
                    }
                  });
                });
              }
            })
            .catchError((error) {
              debugPrint('[MainShellScreen] ⚠️ Error resuming camera: $error');

              // ✅ CAMERA UNAVAILABLE FIX: Force reset and retry on error
              _cameraService.forceResetInitialization();

              Future.delayed(const Duration(milliseconds: 1000), () {
                debugPrint('[MainShellScreen] 🔄 Attempting error recovery...');
                _cameraService.resumeCamera();
              });
            });
      });
    }

    debugPrint('[MainShellScreen] ========== TAB NAVIGATION END ==========');
  }

  @override
  void dispose() {
    debugPrint('[MainShellScreen] Disposing MainShellScreen');
    // While the CameraService is a singleton, if we wanted to be extra cautious,
    // we could pause it here. However, it's managed by tab navigation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: Container(
        // Add brand-friendly container styling
        decoration: BoxDecoration(
          color: AppColors.eggshell,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.soilCharcoal.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BottomNavigationBar(
              items: _navigationItems,
              currentIndex: _selectedIndex,
              selectedItemColor: AppColors.marketBlue,
              unselectedItemColor: AppColors.soilTaupe,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
              selectedIconTheme: const IconThemeData(
                size: 26,
                color: AppColors.marketBlue,
              ),
              unselectedIconTheme: const IconThemeData(
                size: 24,
                color: AppColors.soilTaupe,
              ),
              showSelectedLabels: true,
              showUnselectedLabels: true,
            ),
          ),
        ),
      ),
    );
  }
}
