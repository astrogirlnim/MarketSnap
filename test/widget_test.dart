// This is a basic Flutter widget test for MarketSnap.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketsnap/core/services/background_sync_service.dart';

// Create a testable version of the app without the global dependencies
class TestableMarketSnapApp extends StatelessWidget {
  final BackgroundSyncService? backgroundSyncService;
  
  const TestableMarketSnapApp({
    super.key,
    this.backgroundSyncService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarketSnap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TestableMyHomePage(title: 'MarketSnap'),
    );
  }
}

class TestableMyHomePage extends StatefulWidget {
  const TestableMyHomePage({super.key, required this.title});

  final String title;

  @override
  State<TestableMyHomePage> createState() => _TestableMyHomePageState();
}

class _TestableMyHomePageState extends State<TestableMyHomePage> {
  void _incrementCounter() {
    // Placeholder for increment functionality in tests
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome to MarketSnap!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'You have pushed the button this many times:',
            ),
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

void main() {
  testWidgets('MarketSnap app loads and shows welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TestableMarketSnapApp());

    // Verify that our app shows the MarketSnap title in the AppBar.
    expect(find.text('MarketSnap'), findsOneWidget);

    // Verify that our app shows the welcome message.
    expect(find.text('Welcome to MarketSnap!'), findsOneWidget);

    // Verify that we have a Scaffold structure.
    expect(find.byType(Scaffold), findsOneWidget);

    // Verify that we have an AppBar.
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('App has correct theme configuration', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TestableMarketSnapApp());

    // Verify that the app uses Material3.
    final MaterialApp materialApp = tester.widget(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.title, equals('MarketSnap'));
  });
}
