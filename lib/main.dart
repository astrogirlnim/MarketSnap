import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/services/hive_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/background_sync_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'features/auth/application/auth_service.dart';
import 'features/auth/presentation/screens/auth_welcome_screen.dart';
import 'features/capture/presentation/screens/camera_preview_screen.dart';

// It's better to use a service locator like get_it, but for this stage,
// a global variable is simple and effective.
late final HiveService hiveService;
late final BackgroundSyncService backgroundSyncService;
late final AuthService authService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint('[main] Environment variables loaded.');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // In debug mode, point to the local emulators
  if (kDebugMode) {
    try {
      debugPrint('[main] Debug mode detected, using local emulators.');
      
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
          // Android configuration (working fine)
          await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
          debugPrint('[main] Auth emulator configured.');
        }
      } catch (e) {
        debugPrint('[main] Auth emulator configuration failed: $e');
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('[main] iOS emulator configuration failure is non-fatal, continuing...');
        }
      }
      
      try {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        debugPrint('[main] Firestore emulator configured.');
      } catch (e) {
        debugPrint('[main] Firestore emulator configuration failed: $e');
      }
      
      try {
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        debugPrint('[main] Storage emulator configured.');
      } catch (e) {
        debugPrint('[main] Storage emulator configuration failed: $e');
      }
      
      debugPrint('[main] Firebase emulators configured successfully.');
    } catch (e) {
      debugPrint('[main] Error configuring Firebase emulators: $e');
    }
  }

  // Initialize Firebase App Check with the debug provider
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Initialize authentication service
  try {
    authService = AuthService();
    debugPrint('[main] Auth service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing auth service: $e');
  }

  // Initialize and schedule background sync service
  try {
    hiveService = HiveService(SecureStorageService());
    await hiveService.init();
    debugPrint('[main] Hive service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing Hive service: $e');
  }

  try {
    backgroundSyncService = BackgroundSyncService();
    await backgroundSyncService.initialize();
    debugPrint('[main] Background sync service initialized.');
  } catch (e) {
    debugPrint('[main] Error initializing background sync service: $e');
  }

  debugPrint('[main] Firebase & App Check initialized.');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

/// Authentication wrapper that handles routing based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        debugPrint('[AuthWrapper] Auth state changed: ${snapshot.hasData ? 'authenticated' : 'not authenticated'}');
        
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // User is authenticated - redirect to camera preview
        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('[AuthWrapper] User authenticated: ${snapshot.data!.uid} - redirecting to camera');
          return const CameraPreviewScreen();
        }
        
        // User is not authenticated
        debugPrint('[AuthWrapper] User not authenticated, showing auth screen');
        return const AuthWelcomeScreen();
      },
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
    final info = await backgroundSyncService.getLastExecutionInfo();
    setState(() {
      _lastExecutionInfo = info;
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
    try {
      await authService.signOut();
      debugPrint('[MyHomePage] User signed out successfully');
    } catch (e) {
      debugPrint('[MyHomePage] Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
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
                          ? user!.phoneNumber!.substring(user.phoneNumber!.length - 2)
                          : user?.email?.substring(0, 1).toUpperCase()) ?? 'U',
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
              
              const SizedBox(height: 20),
              const Text("Background Sync", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_lastExecutionInfo != null) ...[
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Last Execution Info", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Platform: ${_lastExecutionInfo!["platform"] ?? "N/A"}'),
                        Text('Executed: ${_lastExecutionInfo!["executed"] ?? "N/A"}'),
                        if (_lastExecutionInfo!['executionTime'] != null)
                          Text('Time: ${_lastExecutionInfo!['executionTime']}'),
                        if (_lastExecutionInfo!['note'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Note: ${_lastExecutionInfo!['note']}', style: const TextStyle(fontStyle: FontStyle.italic)),
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
