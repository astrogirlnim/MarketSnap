import 'dart:io';
import 'package:flutter/material.dart';
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
    if (mounted) {
      setState(() {
        _lastExecutionInfo = info;
      });
    }
    debugPrint('[UI] Background execution info: $info');
  }

  void _scheduleOneTimeTask() async {
    debugPrint('[UI] Scheduling one-time background task...');
    try {
      await backgroundSyncService.scheduleOneTimeSyncTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('One-time background task scheduled!')),
        );
      }
    } catch (e) {
      debugPrint('[UI] Error scheduling one-time task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling task: $e')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to MarketSnap!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            
            // Platform Information
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform: ${Platform.operatingSystem.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      backgroundSyncService.getPlatformInfo(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            // Background Task Status
            if (_lastExecutionInfo != null) ...[
              Card(
                margin: const EdgeInsets.all(16),
                color: (_lastExecutionInfo!['executed'] == true) 
                    ? Colors.green.shade50 
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Task Status',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_lastExecutionInfo!['executed'] == true) ...[
                        Text('✅ Executed: ${_lastExecutionInfo!['executed']}'),
                        if (_lastExecutionInfo!['executionTime'] != null)
                          Text('⏰ Time: ${_lastExecutionInfo!['executionTime']}'),
                        if (_lastExecutionInfo!['taskName'] != null)
                          Text('📋 Task: ${_lastExecutionInfo!['taskName']}'),
                        if (_lastExecutionInfo!['platform'] != null)
                          Text('📱 Platform: ${_lastExecutionInfo!['platform']}'),
                        if (_lastExecutionInfo!['minutesAgo'] != null)
                          Text('⏱️ Minutes ago: ${_lastExecutionInfo!['minutesAgo']}'),
                      ] else ...[
                        Text('❌ Executed: ${_lastExecutionInfo!['executed']}'),
                        if (_lastExecutionInfo!['platform'] != null)
                          Text('📱 Platform: ${_lastExecutionInfo!['platform']}'),
                      ],
                      if (_lastExecutionInfo!['note'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ℹ️ ${_lastExecutionInfo!['note']}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      if (_lastExecutionInfo!['error'] != null)
                        Text('❌ Error: ${_lastExecutionInfo!['error']}', 
                             style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action Buttons
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
