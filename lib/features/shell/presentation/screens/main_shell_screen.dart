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
    
    debugPrint('[MainShellScreen] User type detected: ${_isVendor ? 'Vendor' : 'Regular User'}');
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

  /// ✅ BUFFER OVERFLOW FIX: Pause/resume camera based on tab visibility
  void _handleCameraVisibilityChange(int previousIndex, int currentIndex) {
    const int cameraTabIndex = 1; // Camera is at index 1 for vendors

    // If navigating away from camera tab, pause camera to free resources
    if (previousIndex == cameraTabIndex && currentIndex != cameraTabIndex) {
      debugPrint(
        '[MainShellScreen] Navigating away from camera tab - pausing camera',
      );
      _cameraService.pauseCamera().catchError((error) {
        debugPrint('[MainShellScreen] Error pausing camera: $error');
      });
    }
    // If navigating to camera tab, resume camera
    else if (previousIndex != cameraTabIndex &&
        currentIndex == cameraTabIndex) {
      debugPrint(
        '[MainShellScreen] Navigating to camera tab - resuming camera',
      );
      _cameraService
          .resumeCamera()
          .then((success) {
            if (!success) {
              debugPrint('[MainShellScreen] Camera resume failed');
            }
          })
          .catchError((error) {
            debugPrint('[MainShellScreen] Error resuming camera: $error');
          });
    }
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
