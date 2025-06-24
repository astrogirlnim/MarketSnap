import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/hive_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/background_sync_service.dart';

// It's better to use a service locator like get_it, but for this stage,
// a global variable is simple and effective.
late final HiveService hiveService;
late final BackgroundSyncService backgroundSyncService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint('[main] Environment variables loaded.');

  // Initialize local storage
  try {
    final secureStorageService = SecureStorageService();
    hiveService = HiveService(secureStorageService);
    await hiveService.init();
    debugPrint('[main] Hive service initialized successfully.');
  } catch (e) {
    debugPrint('[main] CRITICAL: Failed to initialize Hive. Error: $e');
    // We could show an error screen here or prevent the app from starting.
    // For now, we'll just log the error.
  }

  // Initialize Background Sync Service
  try {
    backgroundSyncService = BackgroundSyncService();
    await backgroundSyncService.initialize();
    await backgroundSyncService.scheduleSyncTask();
    debugPrint('[main] BackgroundSyncService initialized and task scheduled.');
  } catch (e) {
    debugPrint('[main] CRITICAL: Failed to initialize BackgroundSyncService. Error: $e');
  }

  FirebaseOptions firebaseOptions;

  if (defaultTargetPlatform == TargetPlatform.android) {
    firebaseOptions = FirebaseOptions(
      apiKey: dotenv.env['ANDROID_API_KEY']!,
      appId: dotenv.env['ANDROID_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
    );
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    firebaseOptions = FirebaseOptions(
      apiKey: dotenv.env['IOS_API_KEY']!,
      appId: dotenv.env['IOS_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
      iosBundleId: dotenv.env['APP_BUNDLE_ID']!,
    );
  } else {
    throw UnsupportedError(
      'Platform ${defaultTargetPlatform.toString()} is not supported for Firebase.',
    );
  }

  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    debugPrint('[main] Firebase initialized successfully.');
  } catch (e) {
    debugPrint('[main] CRITICAL: Failed to initialize Firebase. Error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarketSnap',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text('MarketSnap'),
      ),
      body: const Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Text('Welcome to MarketSnap!'),
      ),
    );
  }
}
