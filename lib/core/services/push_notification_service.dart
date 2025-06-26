import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:marketsnap/features/messaging/presentation/screens/chat_screen.dart';
import 'package:marketsnap/features/profile/application/profile_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final GlobalKey<NavigatorState> navigatorKey;
  final ProfileService profileService;

  PushNotificationService({required this.navigatorKey, required this.profileService});

  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission();

    // Handler for when a message is opened from a notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message.data);
    });

    // Handler for when the app is opened from a terminated state
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message.data);
      }
    });

    // TODO: Handle foreground messages with an in-app notification banner
  }

  void _handleMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    if (type == 'new_message') {
      final fromUid = data['fromUid'];
      // Fetch the user profile to navigate to the chat screen
      final fromUser = await profileService.loadProfileFromFirestore(fromUid);

      if (fromUser != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(otherUser: fromUser),
          ),
        );
      }
    }
    // TODO: Handle other notification types like 'new_snap'
  }

  Future<String?> getFCMToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Error getting FCM token: $e');
      return null;
    }
  }
}

