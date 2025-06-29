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
    // Check if user has a vendor profile
    final vendorProfile = widget.profileService.getCurrentUserProfile();

    // User is a vendor if they have a vendor profile
    _isVendor = vendorProfile != null;

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
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Capture'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
    debugPrint('[MainShellScreen] Previous tab: $previousIndex, Current tab: $currentIndex');
    debugPrint('[MainShellScreen] Camera tab index: $cameraTabIndex');

    // If navigating away from camera tab, pause camera to free resources
    if (previousIndex == cameraTabIndex && currentIndex != cameraTabIndex) {
      debugPrint('[MainShellScreen] 📱 Navigating AWAY from camera tab - pausing camera');
      
      _cameraService.pauseCamera().catchError((error) {
        debugPrint('[MainShellScreen] ⚠️ Error pausing camera: $error');
      });
    }
    // If navigating to camera tab, resume camera with enhanced error handling
    else if (previousIndex != cameraTabIndex && currentIndex == cameraTabIndex) {
      debugPrint('[MainShellScreen] 📷 Navigating TO camera tab - resuming camera');
      
      // ✅ CAMERA UNAVAILABLE FIX: Check if camera is already working before resuming
      if (_cameraService.controller?.value.isInitialized == true) {
        debugPrint('[MainShellScreen] ✅ Camera already initialized and working, no resume needed');
        return;
      }
      
      // ✅ CAMERA UNAVAILABLE FIX: Add small delay to allow tab transition to complete
      Future.delayed(const Duration(milliseconds: 100), () {
        _cameraService.resumeCamera().then((success) {
          if (success) {
            debugPrint('[MainShellScreen] ✅ Camera resume successful');
          } else {
            debugPrint('[MainShellScreen] ❌ Camera resume failed - camera may show as unavailable');
            debugPrint('[MainShellScreen] Last error: ${_cameraService.lastError ?? "No specific error provided"}');
            
            // ✅ CAMERA UNAVAILABLE FIX: Force reset if stuck and retry
            if (_cameraService.isInitializingStuck) {
              debugPrint('[MainShellScreen] Camera service stuck, forcing reset...');
              _cameraService.forceResetInitialization();
            }
            
            // ✅ CAMERA UNAVAILABLE FIX: Trigger additional retry after a delay
            Future.delayed(const Duration(milliseconds: 500), () {
              debugPrint('[MainShellScreen] 🔄 Attempting delayed camera recovery...');
              _cameraService.resumeCamera().then((retrySuccess) {
                if (retrySuccess) {
                  debugPrint('[MainShellScreen] ✅ Delayed camera recovery successful');
                } else {
                  debugPrint('[MainShellScreen] ❌ Delayed camera recovery failed');
                }
              });
            });
          }
        }).catchError((error) {
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
      bottomNavigationBar: BottomNavigationBar(
        items: _navigationItems,
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.marketBlue,
        unselectedItemColor: AppColors.soilTaupe,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
