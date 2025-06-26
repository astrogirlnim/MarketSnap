import 'package:flutter/material.dart';
import 'package:marketsnap/features/capture/presentation/screens/camera_preview_screen.dart';
import 'package:marketsnap/features/capture/application/camera_service.dart';
import 'package:marketsnap/features/feed/presentation/screens/feed_screen.dart';
import 'package:marketsnap/features/profile/presentation/screens/vendor_profile_screen.dart';
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

  List<Widget> get _widgetOptions => <Widget>[
    const FeedScreen(),
    CameraPreviewScreen(hiveService: widget.hiveService),
    VendorProfileScreen(
      profileService: widget.profileService,
      isInTabNavigation: true, // This prevents back button from showing
      // No onProfileComplete callback means this is a view/edit mode, not initial setup
    ),
  ];

  /// ✅ BUFFER OVERFLOW FIX: Handle tab navigation with camera lifecycle management
  void _onItemTapped(int index) {
    final int previousIndex = _selectedIndex;
    
    setState(() {
      _selectedIndex = index;
    });

    // ✅ BUFFER OVERFLOW FIX: Manage camera lifecycle based on tab visibility
    _handleCameraVisibilityChange(previousIndex, index);
  }

  /// ✅ BUFFER OVERFLOW FIX: Pause/resume camera based on tab visibility
  void _handleCameraVisibilityChange(int previousIndex, int currentIndex) {
    const int cameraTabIndex = 1; // Camera is at index 1

    // If navigating away from camera tab, pause camera to free resources
    if (previousIndex == cameraTabIndex && currentIndex != cameraTabIndex) {
      debugPrint('[MainShellScreen] Navigating away from camera tab - pausing camera');
      _cameraService.pauseCamera().catchError((error) {
        debugPrint('[MainShellScreen] Error pausing camera: $error');
      });
    }
    
    // If navigating to camera tab, resume camera
    else if (previousIndex != cameraTabIndex && currentIndex == cameraTabIndex) {
      debugPrint('[MainShellScreen] Navigating to camera tab - resuming camera');
      _cameraService.resumeCamera().then((success) {
        if (!success) {
          debugPrint('[MainShellScreen] Camera resume failed');
        }
      }).catchError((error) {
        debugPrint('[MainShellScreen] Error resuming camera: $error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.marketBlue,
        unselectedItemColor: AppColors.soilTaupe,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 