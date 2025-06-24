import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/services/hive_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/background_sync_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// It's better to use a service locator like get_it, but for this stage,
// a global variable is simple and effective.
late final HiveService hiveService;
late final BackgroundSyncService backgroundSyncService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint('[main] Environment variables loaded.');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check with the debug provider
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

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
      home: const MyHomePage(title: 'MarketSnap'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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
                child: const Text("Schedule One-Time Task"),
                onPressed: _scheduleOneTimeTask,
              ),
              ElevatedButton(
                child: const Text("Refresh Status"),
                onPressed: _checkBackgroundExecution,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
