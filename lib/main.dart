import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/services/hive_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/account_linking_service.dart';
import 'core/services/messaging_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/device_gallery_save_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'features/auth/application/auth_service.dart';
import 'features/auth/presentation/screens/auth_welcome_screen.dart';
import 'features/capture/presentation/screens/camera_preview_screen.dart';
import 'features/capture/application/lut_filter_service.dart';
import 'features/profile/application/profile_service.dart';
import 'features/profile/presentation/screens/vendor_profile_screen.dart';
import 'features/shell/presentation/screens/main_shell_screen.dart';
import 'shared/presentation/widgets/version_display_widget.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'features/auth/presentation/screens/user_type_selection_screen.dart';
import 'features/profile/presentation/screens/regular_user_profile_screen.dart';
import 'core/models/user_type.dart';
import 'core/services/profile_update_notifier.dart';
import 'features/feed/application/feed_service.dart';
import 'core/services/account_deletion_service.dart';
import 'core/services/follow_service.dart';
import 'core/services/broadcast_service.dart';
import 'features/settings/application/settings_service.dart';

// It's better to use a service locator like get_it, but for this stage,
// a global variable is simple and effective.
late final HiveService hiveService;
late final BackgroundSyncService backgroundSyncService;
late final AuthService authService;
late final LutFilterService lutFilterService;
late final ProfileService profileService;
late final AccountLinkingService accountLinkingService;
late final MessagingService messagingService;
late final FollowService followService;
late final PushNotificationService pushNotificationService;
late final ProfileUpdateNotifier profileUpdateNotifier;
late final FeedService feedService;
late final AccountDeletionService accountDeletionService;
late final BroadcastService broadcastService;
late final SettingsService settingsService;
late final DeviceGallerySaveService deviceGallerySaveService;

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint('[main] Environment variables loaded.');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // In debug mode, point to the local emulators
  if (kDebugMode) {
    try {
      debugPrint('[main] Debug mode detected, using local emulators.');

      // ✅ CRITICAL FIX: Clear any existing authentication state before connecting to emulators
      try {
        await FirebaseAuth.instance.signOut();
        debugPrint(
          '[main] Cleared existing authentication state for emulator setup.',
        );
      } catch (signOutError) {
        debugPrint('[main] No existing auth to clear: $signOutError');
      }

      // Configure emulators with proper error handling and platform-specific logic
      try {
        // For iOS simulator, we need to be more careful with emulator configuration
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('[main] Configuring emulators for iOS simulator...');
          // Add a longer delay to ensure Firebase is fully initialized on iOS
          await Future.delayed(const Duration(milliseconds: 500));

          // Try to configure Auth emulator with iOS-specific error handling
          try {
            await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
            debugPrint('[main] iOS Auth emulator configured successfully.');
          } catch (iosAuthError) {
            debugPrint('[main] iOS Auth emulator failed: $iosAuthError');
            // For iOS, we'll continue without the emulator if it fails
            debugPrint('[main] Continuing without Auth emulator on iOS...');
          }
        } else {
          // ✅ FIX: Android configuration with proper host mapping
          // Android emulator maps localhost to 10.0.2.2
          const authHost = '10.0.2.2';
          await FirebaseAuth.instance.useAuthEmulator(authHost, 9099);
          debugPrint('Mapping Auth Emulator host "localhost" to "$authHost".');
          debugPrint('[main] Auth emulator configured.');
        }
      } catch (e) {
        debugPrint('[main] Auth emulator configuration failed: $e');
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint(
            '[main] iOS emulator configuration failure is non-fatal, continuing...',
          );
        }
      }

      try {
        // ✅ FIX: Android configuration with proper host mapping
        const firestoreHost = '10.0.2.2';
        FirebaseFirestore.instance.useFirestoreEmulator(firestoreHost, 8080);
        debugPrint(
          'Mapping Firestore Emulator host "localhost" to "$firestoreHost".',
        );
        debugPrint('[main] Firestore emulator configured.');

        // ✅ Additional configuration to ensure emulator persistence is disabled
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('[main] Firestore settings configured for emulator mode.');
      } catch (e) {
        debugPrint('[main] Firestore emulator configuration failed: $e');
      }

      try {
        // ✅ FIX: Android configuration with proper host mapping
        const storageHost = '10.0.2.2';
        await FirebaseStorage.instance.useStorageEmulator(storageHost, 9199);
        debugPrint(
          'Mapping Storage Emulator host "localhost" to "$storageHost".',
        );
      } catch (e) {
        debugPrint('[main] Storage emulator configuration failed: $e');
      }

      try {
        // ✅ FIX: Configure Firebase Functions emulator
        const functionsHost = '10.0.2.2';
        FirebaseFunctions.instance.useFunctionsEmulator(functionsHost, 5001);
        debugPrint(
          'Mapping Functions Emulator host "localhost" to "$functionsHost".',
        );
      } catch (e) {
        debugPrint('[main] Functions emulator configuration failed: $e');
      }

      debugPrint('[main] Firebase emulators configured successfully.');
    } catch (e) {
      debugPrint('[main] Error configuring Firebase emulators: $e');
    }
  }

  // Initialize Firebase App Check with proper configuration
  try {
    // IMPORTANT for Android builds:
    // Ensure your debug and release SHA-1 certificate fingerprints are registered
    // in the Firebase console for your Android app settings.
    // Without the correct SHA-1, App Check (and Google Sign-In) will fail.
    // To get your debug SHA-1, run this in your project's `android` directory:
    // ./gradlew signingReport
    if (kDebugMode) {
      // ✅ FIX: Disable App Check entirely in debug mode to prevent authentication issues
      debugPrint(
        '[main] Debug mode: Skipping App Check initialization to prevent auth issues.',
      );
      debugPrint('[main] App Check will be enabled in production builds only.');
    } else {
      // Use production providers for release builds
      debugPrint('[main] Initializing Firebase App Check for production...');
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      debugPrint(
        '[main] Firebase App Check initialized with production providers.',
      );

      // Verify App Check is working by trying to get a token
      try {
        final token = await FirebaseAppCheck.instance.getToken(true);
        if (token != null) {
          debugPrint('[main] Firebase App Check token obtained successfully.');
        } else {
          debugPrint('[main] Warning: Firebase App Check token is null.');
        }
      } catch (tokenError) {
        debugPrint(
          '[main] Warning: Could not get App Check token: $tokenError',
        );
      }
    }
  } catch (e) {
    debugPrint('[main] Firebase App Check initialization failed: $e');
    debugPrint(
      '[main] Continuing without App Check - some features may be limited.',
    );
    // Continue without App Check if it fails - not critical for basic functionality
  }

  // Initialize and schedule background sync service
  try {
    hiveService = HiveService(SecureStorageService());
    await hiveService.init();
    debugPrint('[main] Hive service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing Hive service: $e');
    // Create minimal fallback Hive service
    try {
      hiveService = HiveService(SecureStorageService());
      debugPrint(
        '[main] Fallback Hive service created (may have limited functionality).',
      );
    } catch (fallbackError) {
      debugPrint('[main] CRITICAL: Cannot create Hive service: $fallbackError');
      rethrow;
    }
  }

  // Initialize authentication service with Hive support
  try {
    authService = AuthService(hiveService: hiveService);
    debugPrint('[main] Auth service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing auth service: $e');
    // Create a fallback AuthService without Hive if initialization fails
    try {
      authService = AuthService();
      debugPrint('[main] Fallback auth service created without cached data.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Fallback auth service failed: $fallbackError',
      );
      // This should never happen, but if it does, we need to exit gracefully
      rethrow;
    }
  }

  // Initialize profile update notifier
  try {
    profileUpdateNotifier = ProfileUpdateNotifier();
    debugPrint('[main] Profile update notifier initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing profile update notifier: $e');
    // Create fallback profile update notifier
    try {
      profileUpdateNotifier = ProfileUpdateNotifier();
      debugPrint('[main] Fallback profile update notifier created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create profile update notifier: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize profile service
  try {
    profileService = ProfileService(
      hiveService: hiveService,
      profileUpdateNotifier: profileUpdateNotifier,
    );
    debugPrint('[main] Profile service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing profile service: $e');
    // Create fallback profile service
    try {
      profileService = ProfileService(
        hiveService: hiveService,
        profileUpdateNotifier: profileUpdateNotifier,
      );
      debugPrint('[main] Fallback profile service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create profile service: $fallbackError',
      );
      rethrow;
    }
  }

  try {
    backgroundSyncService = BackgroundSyncService(hiveService: hiveService);
    await backgroundSyncService.initialize();
    debugPrint('[main] Background sync service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing background sync service: $e');
    // Create basic background sync service without full initialization
    try {
      backgroundSyncService = BackgroundSyncService(hiveService: hiveService);
      debugPrint('[main] Basic background sync service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create background sync service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize LUT filter service
  try {
    lutFilterService = LutFilterService.instance;
    await lutFilterService.initialize();
    debugPrint('[main] LUT filter service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing LUT filter service: $e');
    // LUT filter service is critical for camera functionality
    try {
      lutFilterService = LutFilterService.instance;
      debugPrint('[main] Basic LUT filter service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create LUT filter service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize account linking service
  try {
    accountLinkingService = AccountLinkingService(
      authService: authService,
      profileService: profileService,
    );
    debugPrint('[main] Account linking service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing account linking service: $e');
    debugPrint(
      '[main] Account linking will be limited without proper initialization.',
    );
    // We'll continue without account linking service - it's not critical for basic auth
    // Create a minimal fallback that won't cause late initialization errors
    try {
      accountLinkingService = AccountLinkingService(
        authService: authService,
        profileService: profileService,
      );
      debugPrint(
        '[main] Account linking service created despite initial error.',
      );
    } catch (finalError) {
      debugPrint(
        '[main] CRITICAL: Cannot initialize account linking service: $finalError',
      );
      rethrow;
    }
  }

  // Initialize messaging service
  try {
    messagingService = MessagingService(firebaseAuth: FirebaseAuth.instance);
    debugPrint('[main] Messaging service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing messaging service: $e');
    // Create basic messaging service
    try {
      messagingService = MessagingService(firebaseAuth: FirebaseAuth.instance);
      debugPrint('[main] Basic messaging service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create messaging service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize follow service
  try {
    followService = FollowService();
    debugPrint('[main] Follow service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing follow service: $e');
    // Create basic follow service
    try {
      followService = FollowService();
      debugPrint('[main] Basic follow service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create follow service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize push notification service
  try {
    pushNotificationService = PushNotificationService(
      navigatorKey: navigatorKey,
      profileService: profileService,
      followService: followService,
    );
    await pushNotificationService.initialize();
    debugPrint('[main] Push notification service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing push notification service: $e');
    // Create basic push notification service
    try {
      pushNotificationService = PushNotificationService(
        navigatorKey: navigatorKey,
        profileService: profileService,
        followService: followService,
      );
      debugPrint('[main] Basic push notification service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create push notification service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize feed service
  try {
    feedService = FeedService(profileUpdateNotifier: profileUpdateNotifier);
    debugPrint('[main] Feed service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing feed service: $e');
    // Create basic feed service
    try {
      feedService = FeedService(profileUpdateNotifier: profileUpdateNotifier);
      debugPrint('[main] Basic feed service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create feed service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize account deletion service
  try {
    accountDeletionService = AccountDeletionService(
      authService: authService,
      profileService: profileService,
      hiveService: hiveService,
    );
    debugPrint('[main] Account deletion service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing account deletion service: $e');
    // Create fallback account deletion service
    try {
      accountDeletionService = AccountDeletionService(
        authService: authService,
        profileService: profileService,
        hiveService: hiveService,
      );
      debugPrint('[main] Fallback account deletion service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create account deletion service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize broadcast service
  try {
    broadcastService = BroadcastService(
      hiveService: hiveService,
      profileService: profileService,
    );
    debugPrint('[main] Broadcast service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing broadcast service: $e');
    // Create fallback broadcast service
    try {
      broadcastService = BroadcastService(
        hiveService: hiveService,
        profileService: profileService,
      );
      debugPrint('[main] Fallback broadcast service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create broadcast service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize settings service for Phase 4.4 Save-to-Device functionality
  try {
    settingsService = SettingsService(hiveService: hiveService);
    debugPrint('[main] ✅ Settings service initialized for Phase 4.4');
  } catch (e) {
    debugPrint('[main] Error initializing settings service: $e');
    // Create fallback settings service
    try {
      settingsService = SettingsService(hiveService: hiveService);
      debugPrint('[main] Fallback settings service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create settings service: $fallbackError',
      );
      rethrow;
    }
  }

  // Initialize device gallery save service for Phase 4.4 Save-to-Device functionality
  try {
    deviceGallerySaveService = DeviceGallerySaveService(
      hiveService: hiveService,
      settingsService: settingsService,
    );
    debugPrint('[main] ✅ Device gallery save service initialized for Phase 4.4');
  } catch (e) {
    debugPrint('[main] Error initializing device gallery save service: $e');
    // Create fallback device gallery save service
    try {
      deviceGallerySaveService = DeviceGallerySaveService(
        hiveService: hiveService,
        settingsService: settingsService,
      );
      debugPrint('[main] Fallback device gallery save service created.');
    } catch (fallbackError) {
      debugPrint(
        '[main] CRITICAL: Cannot create device gallery save service: $fallbackError',
      );
      rethrow;
    }
  }

  // Add global connectivity monitoring for background sync
  try {
    // Monitor connectivity changes globally to trigger sync when coming back online
    bool wasOffline = false;

    // Check initial connectivity state
    final initialConnectivity = await Connectivity().checkConnectivity();
    wasOffline = initialConnectivity.contains(ConnectivityResult.none);
    debugPrint(
      '[main] Initial connectivity: ${wasOffline ? 'OFFLINE' : 'ONLINE'}',
    );

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );

      debugPrint(
        '[main] Connectivity changed: ${isOnline ? 'ONLINE' : 'OFFLINE'}',
      );

      // If we just came back online from being offline, trigger sync
      if (isOnline && wasOffline) {
        debugPrint(
          '[main] 🌐 Back online! Triggering background sync for queued items...',
        );

        try {
          await backgroundSyncService.triggerImmediateSync();
          debugPrint('[main] ✅ Background sync completed successfully');
        } catch (e) {
          debugPrint('[main] ❌ Background sync failed: $e');

          // Fallback: Schedule a one-time task for more reliable sync
          try {
            await backgroundSyncService.scheduleOneTimeSyncTask();
            debugPrint('[main] 📅 Scheduled one-time sync task as fallback');
          } catch (scheduleError) {
            debugPrint(
              '[main] ❌ Failed to schedule fallback sync: $scheduleError',
            );
          }
        }
      }

      // Update offline state
      wasOffline = !isOnline;
    });

    debugPrint('[main] Global connectivity monitoring initialized.');
  } catch (e) {
    debugPrint('[main] Error setting up global connectivity monitoring: $e');
    // Non-critical error - app can continue without global sync monitoring
  }

  debugPrint('[main] Firebase & App Check initialized.');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MarketSnap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Authentication wrapper that handles routing based on auth state and profile completion
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // ✅ FIX: Cache the post-auth future to prevent rebuild cycles
  Future<bool>? _postAuthFuture;
  String? _currentUserId;

  /// Handles post-authentication flow including account linking
  Future<bool> _handlePostAuthenticationFlow() async {
    debugPrint('[AuthWrapper] 🚀 Starting post-authentication flow');
    final currentUser = authService.currentUser;
    debugPrint('[AuthWrapper] 👤 Current user: ${currentUser?.uid}');
    debugPrint('[AuthWrapper] 📧 Current user email: ${currentUser?.email}');
    debugPrint(
      '[AuthWrapper] 📱 Current user phone: ${currentUser?.phoneNumber}',
    );

    try {
      debugPrint('[AuthWrapper] 🔗 Starting account linking process');

      // Handle account linking after sign-in
      final hasExistingProfile = await accountLinkingService
          .handleSignInAccountLinking();
      debugPrint(
        '[AuthWrapper] ✅ Account linking completed. Has existing profile: $hasExistingProfile',
      );

      debugPrint('[AuthWrapper] 🔔 Saving FCM token');
      // Save FCM token
      final token = await pushNotificationService.getFCMToken();
      if (token != null) {
        debugPrint(
          '[AuthWrapper] 📱 FCM token obtained: ${token.substring(0, 20)}...',
        );
        await profileService.saveFCMToken(token);
        debugPrint('[AuthWrapper] ✅ FCM token saved successfully');
      } else {
        debugPrint('[AuthWrapper] ⚠️ No FCM token available');
      }

      debugPrint(
        '[AuthWrapper] 🏁 Post-authentication flow completed successfully',
      );
      return hasExistingProfile;
    } catch (e, stackTrace) {
      debugPrint('[AuthWrapper] ❌ Account linking failed: $e');
      debugPrint('[AuthWrapper] 📚 Stack trace: $stackTrace');
      // Don't block the flow if account linking fails
      debugPrint('[AuthWrapper] 🔄 Continuing with default flow despite error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AuthWrapper] 🔄 Building AuthWrapper widget');

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        debugPrint('[AuthWrapper] 📡 StreamBuilder triggered');
        debugPrint(
          '[AuthWrapper] Auth state changed: ${snapshot.hasData ? 'authenticated' : 'not authenticated'}',
        );
        debugPrint(
          '[AuthWrapper] Connection state: ${snapshot.connectionState}',
        );
        debugPrint('[AuthWrapper] Has data: ${snapshot.hasData}');
        debugPrint('[AuthWrapper] Data: ${snapshot.data}');
        debugPrint('[AuthWrapper] User UID: ${snapshot.data?.uid}');
        debugPrint(
          '[AuthWrapper] Is offline mode: ${authService.isOfflineMode}',
        );

        // Skip loading state check - auth service always emits initial state
        // Handle authentication state directly based on data

        // User is authenticated - handle account linking and check profile completion
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          debugPrint('[AuthWrapper] ✅ User authenticated: ${user.uid}');
          debugPrint('[AuthWrapper] User email: ${user.email}');
          debugPrint('[AuthWrapper] User phone: ${user.phoneNumber}');

          // ✅ FIX: Check if user changed to reset cached future
          final newUserId = user.uid;
          if (_currentUserId != newUserId) {
            debugPrint(
              '[AuthWrapper] 🔄 User changed from $_currentUserId to $newUserId, resetting post-auth future',
            );
            _currentUserId = newUserId;
            _postAuthFuture = null; // Reset future for new user
          } else {
            debugPrint('[AuthWrapper] ✅ Same user, keeping cached future');
          }

          // OFFLINE OPTIMIZATION: Skip post-auth flow when offline to avoid loading screen
          if (authService.isOfflineMode) {
            debugPrint(
              '[AuthWrapper] 📱 Offline mode detected - skipping post-auth flow',
            );

            // Go directly to profile check without network operations
            if (profileService.hasCompleteProfile()) {
              debugPrint(
                '[AuthWrapper] 📱 Profile complete (offline) - navigating to MainShellScreen',
              );
              return MainShellScreen(
                profileService: profileService,
                hiveService: hiveService,
              );
            } else {
              debugPrint(
                '[AuthWrapper] 📱 Profile incomplete (offline) - navigating to VendorProfileScreen',
              );
              return VendorProfileScreen(
                profileService: profileService,
                onProfileComplete: () {
                  debugPrint(
                    '[AuthWrapper] Profile completed, triggering rebuild',
                  );
                  setState(() {});
                },
              );
            }
          }

          // ✅ FIX: Cache the future to prevent rebuild cycles
          if (_postAuthFuture == null) {
            debugPrint(
              '[AuthWrapper] 🚀 Creating new post-auth future for user: ${user.uid}',
            );
            _postAuthFuture = _handlePostAuthenticationFlow();
          } else {
            debugPrint('[AuthWrapper] ♻️ Using cached post-auth future');
          }

          // ONLINE MODE: Run full post-authentication flow
          debugPrint(
            '[AuthWrapper] 🔄 Building FutureBuilder for post-auth flow',
          );
          return FutureBuilder<bool>(
            future: _postAuthFuture, // ✅ Use cached future
            builder: (context, authFuture) {
              debugPrint(
                '[AuthWrapper] 📊 FutureBuilder state: ${authFuture.connectionState}',
              );
              debugPrint(
                '[AuthWrapper] 📊 FutureBuilder hasData: ${authFuture.hasData}',
              );
              debugPrint(
                '[AuthWrapper] 📊 FutureBuilder data: ${authFuture.data}',
              );
              debugPrint(
                '[AuthWrapper] 📊 FutureBuilder error: ${authFuture.error}',
              );

              if (authFuture.connectionState == ConnectionState.waiting) {
                debugPrint(
                  '[AuthWrapper] ⏳ Showing loading screen for post-auth flow',
                );
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Setting up your account...'),
                      ],
                    ),
                  ),
                );
              }

              if (authFuture.hasError) {
                debugPrint(
                  '[AuthWrapper] ❌ FutureBuilder error: ${authFuture.error}',
                );
                // Continue with default flow on error
              }

              // Account linking completed - check if existing profile was found
              final hasExistingProfile = authFuture.data ?? false;
              debugPrint(
                '[AuthWrapper] 📋 Has existing profile: $hasExistingProfile',
              );

              if (hasExistingProfile) {
                // User has an existing profile - go directly to main app
                debugPrint(
                  '[AuthWrapper] ✅ User has existing profile - going to main app',
                );
                return MainShellScreen(
                  profileService: profileService,
                  hiveService: hiveService,
                );
              } else {
                // No existing profile found - check if user has any profile (vendor or regular)
                final hasVendorProfile = profileService.hasCompleteProfile();
                final hasRegularProfile = profileService
                    .hasCompleteRegularUserProfile();

                debugPrint(
                  '[AuthWrapper] 📋 Has vendor profile: $hasVendorProfile',
                );
                debugPrint(
                  '[AuthWrapper] 📋 Has regular profile: $hasRegularProfile',
                );

                if (hasVendorProfile || hasRegularProfile) {
                  debugPrint(
                    '[AuthWrapper] ✅ User has complete profile, navigating to MainShellScreen',
                  );
                  return MainShellScreen(
                    profileService: profileService,
                    hiveService: hiveService,
                  );
                } else {
                  debugPrint(
                    '[AuthWrapper] ❌ No profile found, navigating to UserTypeSelectionScreen',
                  );

                  // Import the UserTypeSelectionScreen
                  return UserTypeSelectionScreen(
                    onUserTypeSelected: (userType) {
                      debugPrint(
                        '[AuthWrapper] User selected type: ${userType.displayName}',
                      );

                      // Navigate to appropriate profile screen
                      if (userType == UserType.vendor) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => VendorProfileScreen(
                              profileService: profileService,
                              onProfileComplete: () {
                                debugPrint(
                                  '[AuthWrapper] Vendor profile completed',
                                );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => MainShellScreen(
                                      profileService: profileService,
                                      hiveService: hiveService,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => RegularUserProfileScreen(
                              profileService: profileService,
                              onProfileComplete: () {
                                debugPrint(
                                  '[AuthWrapper] Regular user profile completed',
                                );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => MainShellScreen(
                                      profileService: profileService,
                                      hiveService: hiveService,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                  );
                }
              }
            },
          );
        }

        // ✅ FIX: Reset cached future when user signs out
        if (!snapshot.hasData && _postAuthFuture != null) {
          debugPrint(
            '[AuthWrapper] 🚪 User signed out, clearing post-auth future',
          );
          _postAuthFuture = null;
          _currentUserId = null;
        }

        // User is not authenticated - show auth screen with demo option in debug mode
        debugPrint(
          '[AuthWrapper] ❌ User not authenticated, navigating to AuthWelcomeScreen',
        );
        return const AuthWelcomeScreen();
      },
    );
  }
}

/// Development authentication screen with demo mode option
class DevelopmentAuthScreen extends StatelessWidget {
  const DevelopmentAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main auth screen
          const AuthWelcomeScreen(),

          // Development demo button overlay
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.developer_mode,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Development Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Skip authentication and test camera functionality directly',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        debugPrint(
                          '[DevelopmentAuthScreen] Demo mode selected - navigating to camera',
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) =>
                                const DevelopmentCameraWrapper(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt, color: Colors.orange),
                      label: const Text(
                        'Demo Camera',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Development wrapper for camera testing without authentication
class DevelopmentCameraWrapper extends StatelessWidget {
  const DevelopmentCameraWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview screen
          CameraPreviewScreen(hiveService: hiveService),

          // Development overlay banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.orange.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DEMO MODE - Authentication Bypassed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate back to auth screen
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const DevelopmentAuthScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Back to Auth',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Debug version info in bottom left corner
          const Positioned(bottom: 20, left: 20, child: DebugVersionDisplay()),
        ],
      ),
    );
  }
}

// Development/Testing page - keeping for potential future use but not the main flow
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BackgroundSyncService backgroundSyncService = BackgroundSyncService();
  Map<String, dynamic>? _lastExecutionInfo;

  @override
  void initState() {
    super.initState();
    _checkBackgroundExecution();
  }

  Future<void> _checkBackgroundExecution() async {
    final lastExecution = await backgroundSyncService.getLastExecutionTime();
    setState(() {
      _lastExecutionInfo = {
        'platform': Platform.operatingSystem,
        'executed': lastExecution != null ? 'Yes' : 'Never',
        'executionTime': lastExecution?.toString(),
        'note': null,
      };
    });
  }

  Future<void> _scheduleOneTimeTask() async {
    await backgroundSyncService.scheduleOneTimeSyncTask();
    setState(() {
      _lastExecutionInfo = {
        'executed': false,
        'note': 'Task scheduled! Check back in a moment.',
        'platform': Platform.operatingSystem,
      };
    });
    // Check again after a short delay to see if it ran
    Future.delayed(const Duration(seconds: 10), _checkBackgroundExecution);
  }

  /// Signs out the current user
  Future<void> _signOut() async {
    debugPrint('[MyHomePage] User sign out requested');

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Signing out...'),
            ],
          ),
        ),
      );
    }

    try {
      await authService.signOut();
      debugPrint('[MyHomePage] User signed out successfully');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Successfully signed out'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MyHomePage] Error signing out: $e');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error signing out: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // User info and sign out
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in as:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      user?.phoneNumber ?? user?.email ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UID: ${user?.uid.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.deepPurple.shade600,
                    child: Text(
                      (user?.phoneNumber?.isNotEmpty == true
                              ? user!.phoneNumber!.substring(
                                  user.phoneNumber!.length - 2,
                                )
                              : user?.email?.substring(0, 1).toUpperCase()) ??
                          'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Welcome message for authenticated user
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Authentication Successful!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone/Email OTP flow is working correctly',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // User Profile Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // User Avatar
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.deepPurple.shade600,
                      child: Text(
                        (user?.phoneNumber?.isNotEmpty == true
                                ? user!.phoneNumber!.substring(
                                    user.phoneNumber!.length - 2,
                                  )
                                : user?.email?.substring(0, 1).toUpperCase()) ??
                            'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Info
                    Text(
                      'Signed in as:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.phoneNumber ?? user?.email ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'UID: ${user?.uid.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test your authentication by signing out and back in',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                "Background Sync",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_lastExecutionInfo != null) ...[
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Last Execution Info",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Platform: ${_lastExecutionInfo!["platform"] ?? "N/A"}',
                        ),
                        Text(
                          'Executed: ${_lastExecutionInfo!["executed"] ?? "N/A"}',
                        ),
                        if (_lastExecutionInfo!['executionTime'] != null)
                          Text('Time: ${_lastExecutionInfo!['executionTime']}'),
                        if (_lastExecutionInfo!['note'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Note: ${_lastExecutionInfo!['note']}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              ElevatedButton(
                onPressed: _scheduleOneTimeTask,
                child: const Text("Schedule One-Time Task"),
              ),
              ElevatedButton(
                onPressed: _checkBackgroundExecution,
                child: const Text("Refresh Status"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the app content, ensuring user has a complete profile before proceeding
class ProfileCompletionWrapper extends StatefulWidget {
  const ProfileCompletionWrapper({
    super.key,
    required this.profileService,
    required this.hiveService,
  });

  final ProfileService profileService;
  final HiveService hiveService;

  @override
  State<ProfileCompletionWrapper> createState() =>
      _ProfileCompletionWrapperState();
}

class _ProfileCompletionWrapperState extends State<ProfileCompletionWrapper> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.profileService.getCurrentUserProfile();

    // If profile is null or incomplete, force user to complete it
    if (profile == null || !profile.isComplete) {
      return VendorProfileScreen(
        profileService: widget.profileService,
        onProfileComplete: () {
          // Rebuild the widget tree to proceed to the main app
          setState(() {
            // This will trigger a rebuild and re-evaluate the profile state
          });
        },
      );
    }

    // Profile is complete, show the main app shell
    return MainShellScreen(
      profileService: widget.profileService,
      hiveService: widget.hiveService,
    );
  }
}
