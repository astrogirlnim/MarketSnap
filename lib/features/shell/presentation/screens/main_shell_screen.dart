import 'package:flutter/material.dart';
import 'package:marketsnap/features/capture/presentation/screens/camera_preview_screen.dart';
import 'package:marketsnap/features/feed/presentation/screens/feed_screen.dart';
import 'package:marketsnap/features/profile/presentation/screens/vendor_profile_screen.dart';
import 'package:marketsnap/features/profile/application/profile_service.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';

class MainShellScreen extends StatefulWidget {
  final ProfileService profileService;
  
  const MainShellScreen({super.key, required this.profileService});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  List<Widget> get _widgetOptions => <Widget>[
    const FeedScreen(),
    const CameraPreviewScreen(),
    VendorProfileScreen(
      profileService: widget.profileService,
      isInTabNavigation: true, // This prevents back button from showing
      // No onProfileComplete callback means this is a view/edit mode, not initial setup
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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