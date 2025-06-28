import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:marketsnap/features/messaging/presentation/screens/chat_screen.dart';
import 'package:marketsnap/features/profile/application/profile_service.dart';
import 'package:marketsnap/features/feed/presentation/screens/feed_screen.dart';
import 'package:marketsnap/core/services/follow_service.dart';

/// Service for managing Firebase Cloud Messaging (FCM) push notifications
/// Handles permissions, deep-linking, token management, and fallback notifications
class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final GlobalKey<NavigatorState> navigatorKey;
  final ProfileService profileService;
  final FollowService followService;

  // Track notification permission status
  NotificationSettings? _notificationSettings;
  bool _hasRequestedPermissions = false;
  
  // In-app notification overlay key for fallback banners
  OverlayEntry? _currentInAppNotification;

  PushNotificationService({
    required this.navigatorKey,
    required this.profileService,
    required this.followService,
  });

  /// Initialize push notification service with comprehensive setup
  Future<void> initialize() async {
    debugPrint('[PushNotificationService] 🚀 Initializing push notification service');
    
    try {
      // Request permissions with proper settings
      await requestPermissions();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      // Set up token refresh listener
      _setupTokenRefreshListener();
      
      // Set up foreground message handler
      _setupForegroundMessageHandler();
      
      debugPrint('[PushNotificationService] ✅ Push notification service initialized successfully');
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error initializing push notification service: $e');
      rethrow;
    }
  }

  /// Request FCM permissions with comprehensive settings
  Future<bool> requestPermissions() async {
    if (_hasRequestedPermissions) {
      debugPrint('[PushNotificationService] 📱 Permissions already requested, returning cached result');
      return _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized;
    }

    debugPrint('[PushNotificationService] 📱 Requesting FCM permissions');
    
    try {
      _notificationSettings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _hasRequestedPermissions = true;
      
      final isAuthorized = _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized;
      
      debugPrint('[PushNotificationService] 📱 Permission status: ${_notificationSettings?.authorizationStatus}');
      debugPrint('[PushNotificationService] 🔔 Alert enabled: ${_notificationSettings?.alert}');
      debugPrint('[PushNotificationService] 🔊 Sound enabled: ${_notificationSettings?.sound}');
      debugPrint('[PushNotificationService] 🔢 Badge enabled: ${_notificationSettings?.badge}');
      
      if (isAuthorized) {
        debugPrint('[PushNotificationService] ✅ Push notifications are authorized');
      } else {
        debugPrint('[PushNotificationService] ⚠️ Push notifications not authorized - will use in-app fallback');
      }

      return isAuthorized;
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error requesting permissions: $e');
      _hasRequestedPermissions = true; // Prevent infinite retry
      return false;
    }
  }

  /// Check if push notifications are currently authorized
  bool get isAuthorized {
    return _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Check if the user has denied push notifications
  bool get isDenied {
    return _notificationSettings?.authorizationStatus == AuthorizationStatus.denied;
  }

  /// Set up message handlers for background and terminated app states
  Future<void> _setupMessageHandlers() async {
    // Handler for when a message is opened from a notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] 📱 Notification opened from background: ${message.data}');
      _handleMessage(message.data);
    });

    // Handler for when the app is opened from a terminated state
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[PushNotificationService] 📱 Notification opened from terminated state: ${initialMessage.data}');
      // Delay handling to ensure app is fully initialized
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessage(initialMessage.data);
      });
    }
  }

  /// Set up foreground message handler with in-app banner fallback
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] 📱 Foreground message received: ${message.notification?.title}');
      
      // Show in-app banner for foreground messages
      _showInAppNotificationBanner(message);
    });
  }

  /// Set up FCM token refresh listener
  void _setupTokenRefreshListener() {
    _fcm.onTokenRefresh.listen((String newToken) {
      debugPrint('[PushNotificationService] 🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
      _handleTokenRefresh(newToken);
    }).onError((error) {
      debugPrint('[PushNotificationService] ❌ Error in token refresh listener: $error');
    });
  }

  /// Handle FCM token refresh by updating all user profiles and followed vendors
  Future<void> _handleTokenRefresh(String newToken) async {
    try {
      debugPrint('[PushNotificationService] 🔄 Handling token refresh');
      
      // Save new token to user profile
      await profileService.saveFCMToken(newToken);
      
      // Update token for all followed vendors
      await followService.updateFCMTokenForFollowedVendors();
      
      debugPrint('[PushNotificationService] ✅ Token refresh handled successfully');
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error handling token refresh: $e');
    }
  }

  /// Handle deep-linking from push notification messages
  void _handleMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    debugPrint('[PushNotificationService] 📱 Handling message of type: $type');
    debugPrint('[PushNotificationService] 📱 Message data: $data');

    try {
      switch (type) {
        case 'new_message':
          await _handleNewMessageDeepLink(data);
          break;
        case 'new_snap':
          await _handleNewSnapDeepLink(data);
          break;
        case 'new_story':
          await _handleNewStoryDeepLink(data);
          break;
        case 'new_broadcast':
          await _handleNewBroadcastDeepLink(data);
          break;
        default:
          debugPrint('[PushNotificationService] ⚠️ Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error handling message: $e');
    }
  }

  /// Handle deep-link for new message notifications
  Future<void> _handleNewMessageDeepLink(Map<String, dynamic> data) async {
    final fromUid = data['fromUid'];
    if (fromUid == null) {
      debugPrint('[PushNotificationService] ❌ Missing fromUid in new_message notification');
      return;
    }

    // Fetch the user profile to navigate to the chat screen
    final fromUser = await profileService.loadAnyUserProfileFromFirestore(fromUid);

    if (fromUser != null) {
      debugPrint('[PushNotificationService] 📱 Navigating to chat with ${fromUser.displayName}');
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(otherUser: fromUser),
        ),
      );
    } else {
      debugPrint('[PushNotificationService] ❌ Could not load user profile for fromUid: $fromUid');
    }
  }

  /// Handle deep-link for new snap notifications
  Future<void> _handleNewSnapDeepLink(Map<String, dynamic> data) async {
    final vendorId = data['vendorId'];
    final snapId = data['snapId'];
    
    if (vendorId == null || snapId == null) {
      debugPrint('[PushNotificationService] ❌ Missing vendorId or snapId in new_snap notification');
      return;
    }

    debugPrint('[PushNotificationService] 📱 Navigating to snap $snapId from vendor $vendorId');
    
    // Navigate to feed screen and focus on the specific vendor's content
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const FeedScreen(),
      ),
      (route) => false, // Remove all previous routes
    );
    
    // TODO: Add logic to scroll to specific snap once feed screen supports it
  }

  /// Handle deep-link for new story notifications  
  Future<void> _handleNewStoryDeepLink(Map<String, dynamic> data) async {
    final vendorId = data['vendorId'];
    
    if (vendorId == null) {
      debugPrint('[PushNotificationService] ❌ Missing vendorId in new_story notification');
      return;
    }

    debugPrint('[PushNotificationService] 📱 Navigating to story from vendor $vendorId');
    
    // Navigate to feed screen where stories are displayed
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const FeedScreen(),
      ),
      (route) => false,
    );
    
    // TODO: Add logic to focus on specific vendor's story once story carousel supports it
  }

  /// Handle deep-link for new broadcast notifications
  Future<void> _handleNewBroadcastDeepLink(Map<String, dynamic> data) async {
    final vendorId = data['vendorId'];
    
    if (vendorId == null) {
      debugPrint('[PushNotificationService] ❌ Missing vendorId in new_broadcast notification');
      return;
    }

    debugPrint('[PushNotificationService] 📱 Navigating to broadcast from vendor $vendorId');
    
    // Navigate to feed screen where broadcasts would be displayed
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const FeedScreen(),
      ),
      (route) => false,
    );
  }

  /// Show in-app notification banner when push notifications are disabled or app is in foreground
  void _showInAppNotificationBanner(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[PushNotificationService] ❌ No context available for in-app banner');
      return;
    }

    // Clear any existing in-app notification
    _clearInAppNotification();

    final notification = message.notification;
    if (notification == null) {
      debugPrint('[PushNotificationService] ❌ No notification content for in-app banner');
      return;
    }

    debugPrint('[PushNotificationService] 📱 Showing in-app notification banner: ${notification.title}');

    // Create overlay entry for in-app notification banner
    _currentInAppNotification = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: GestureDetector(
              onTap: () {
                _clearInAppNotification();
                _handleMessage(message.data);
              },
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.title ?? 'New Notification',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (notification.body != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            notification.body!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _clearInAppNotification,
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Add overlay
    Overlay.of(context).insert(_currentInAppNotification!);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _clearInAppNotification();
    });
  }

  /// Clear current in-app notification banner
  void _clearInAppNotification() {
    if (_currentInAppNotification != null) {
      debugPrint('[PushNotificationService] 📱 Clearing in-app notification banner');
      _currentInAppNotification!.remove();
      _currentInAppNotification = null;
    }
  }

  /// Get FCM token for the current device
  Future<String?> getFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[PushNotificationService] 📱 FCM token obtained: ${token.substring(0, 20)}...');
      } else {
        debugPrint('[PushNotificationService] ❌ No FCM token available');
      }
      return token;
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Check if FCM token refresh is needed and handle it
  Future<void> refreshTokenIfNeeded() async {
    try {
      debugPrint('[PushNotificationService] 🔄 Checking if token refresh is needed');
      
      final currentToken = await getFCMToken();
      if (currentToken != null) {
        await _handleTokenRefresh(currentToken);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Error refreshing token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    debugPrint('[PushNotificationService] 🧹 Disposing push notification service');
    _clearInAppNotification();
  }
}
