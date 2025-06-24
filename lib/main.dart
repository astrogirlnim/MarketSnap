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

  // Initialize Hive service
  try {
    final secureStorageService = SecureStorageService();
    hiveService = HiveService(secureStorageService);
    await hiveService.init();
    debugPrint('[main] Hive service initialized successfully.');
  } catch (e) {
    debugPrint('[main] Error initializing Hive service: $e');
  }

  // Initialize and schedule background sync service
  try {
    backgroundSyncService = BackgroundSyncService();
    await backgroundSyncService.initialize();
    await backgroundSyncService.scheduleSyncTask();
    debugPrint('[main] BackgroundSyncService initialized and task scheduled.');
  } catch (e) {
    debugPrint('[main] Error initializing BackgroundSyncService: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp();
  debugPrint('[main] Firebase initialized successfully.');

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

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Map<String, dynamic>? _lastExecutionInfo;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _checkBackgroundExecution() async {
    debugPrint('[UI] Checking background execution status...');
    final info = await backgroundSyncService.getLastExecutionInfo();
    setState(() {
      _lastExecutionInfo = info;
    });
    debugPrint('[UI] Background execution info: $info');
  }

  void _scheduleOneTimeTask() async {
    debugPrint('[UI] Scheduling one-time background task...');
    try {
      await backgroundSyncService.scheduleOneTimeSyncTask();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('One-time background task scheduled!')),
      );
    } catch (e) {
      debugPrint('[UI] Error scheduling one-time task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

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
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkBackgroundExecution,
              child: const Text('Check Background Task Status'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _scheduleOneTimeTask,
              child: const Text('Schedule One-Time Task'),
            ),
            const SizedBox(height: 20),
            if (_lastExecutionInfo != null) ...[
              const Text('Background Task Info:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Executed: ${_lastExecutionInfo!['executed']}'),
              if (_lastExecutionInfo!['executed'] == true) ...[
                Text('Task: ${_lastExecutionInfo!['taskName']}'),
                Text('Time: ${_lastExecutionInfo!['executionTime']}'),
                Text('Minutes ago: ${_lastExecutionInfo!['minutesAgo']}'),
              ],
              if (_lastExecutionInfo!['error'] != null)
                Text('Error: ${_lastExecutionInfo!['error']}'),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
