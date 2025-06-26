import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;

// Import project files
import '../lib/core/models/pending_media.dart';
import '../lib/core/services/hive_service.dart';
import '../lib/core/services/background_sync_service.dart';
import '../lib/firebase_options.dart';

void main() async {
  print('🔍 MarketSnap Media Upload Debug Script');
  print('=====================================');
  
  try {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');
    
    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('✅ Firebase initialized');
    
    // Configure Firebase emulators
    if (kDebugMode) {
      try {
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        print('✅ Firebase emulators configured');
      } catch (e) {
        print('⚠️  Emulator configuration warning: $e');
      }
    }
    
    // Initialize Hive
    final String tempDir = Directory.systemTemp.path;
    final String hiveDir = path.join(tempDir, 'hive_debug');
    await Directory(hiveDir).create(recursive: true);
    Hive.init(hiveDir);
    
    // Register Hive adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingMediaItemAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MediaTypeAdapter());
    }
    print('✅ Hive initialized');
    
    // Start debugging
    await debugMediaUploadFlow();
    
  } catch (e, stackTrace) {
    print('❌ Fatal error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

Future<void> debugMediaUploadFlow() async {
  print('\n🔍 Step 1: Checking Firebase Authentication');
  print('==========================================');
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No authenticated user found');
    print('💡 Make sure you are logged in to the app first');
    return;
  }
  
  print('✅ Authenticated user found:');
  print('   - UID: ${user.uid}');
  print('   - Email: ${user.email ?? "No email"}');
  print('   - Providers: ${user.providerData.map((p) => p.providerId).toList()}');
  print('   - Email verified: ${user.emailVerified}');
  print('   - Anonymous: ${user.isAnonymous}');
  
  print('\n🔍 Step 2: Checking Hive Queue');
  print('=============================');
  
  Box<PendingMediaItem>? pendingBox;
  try {
    pendingBox = await Hive.openBox<PendingMediaItem>('pendingMediaQueue');
    final pendingItems = pendingBox.values.toList();
    
    print('✅ Hive box opened successfully');
    print('📊 Queue status:');
    print('   - Total pending items: ${pendingItems.length}');
    
    if (pendingItems.isEmpty) {
      print('💡 No pending media items in queue');
      print('   - This could mean:');
      print('     1. No media has been captured yet');
      print('     2. Media was captured but not queued');
      print('     3. Media was already uploaded');
      
      await _createTestMediaItem(pendingBox, user);
    } else {
      print('📋 Pending items:');
      for (int i = 0; i < pendingItems.length; i++) {
        final item = pendingItems[i];
        print('   ${i + 1}. ID: ${item.id}');
        print('      - File: ${item.filePath}');
        print('      - Type: ${item.mediaType}');
        print('      - Caption: ${item.caption ?? "No caption"}');
        print('      - File exists: ${await File(item.filePath).exists()}');
      }
    }
    
  } catch (e) {
    print('❌ Error accessing Hive queue: $e');
    return;
  }
  
  print('\n🔍 Step 3: Testing Firebase Storage Connection');
  print('=============================================');
  
  try {
    // Test Firebase Storage connection
    final storageRef = FirebaseStorage.instance.ref().child('test').child('connection_test.txt');
    final testData = 'MarketSnap debug test - ${DateTime.now().toIso8601String()}';
    
    print('📤 Testing Firebase Storage upload...');
    await storageRef.putString(testData);
    print('✅ Test upload successful');
    
    print('📥 Testing Firebase Storage download...');
    final downloadUrl = await storageRef.getDownloadURL();
    print('✅ Test download successful: $downloadUrl');
    
    // Clean up test file
    await storageRef.delete();
    print('🧹 Test file cleaned up');
    
  } catch (e) {
    print('❌ Firebase Storage test failed: $e');
    print('💡 This suggests a Storage emulator connectivity issue');
    return;
  }
  
  print('\n🔍 Step 4: Testing Firebase Firestore Connection');
  print('===============================================');
  
  try {
    // Test Firestore connection
    final testDoc = FirebaseFirestore.instance.collection('debug_test').doc('connection_test');
    await testDoc.set({
      'timestamp': FieldValue.serverTimestamp(),
      'message': 'MarketSnap debug test',
    });
    print('✅ Firestore write test successful');
    
    final docSnapshot = await testDoc.get();
    if (docSnapshot.exists) {
      print('✅ Firestore read test successful');
    }
    
    // Clean up test document
    await testDoc.delete();
    print('🧹 Test document cleaned up');
    
  } catch (e) {
    print('❌ Firebase Firestore test failed: $e');
    print('💡 This suggests a Firestore emulator connectivity issue');
    return;
  }
  
  print('\n🔍 Step 5: Testing Background Sync Service');
  print('=========================================');
  
  try {
    final syncService = BackgroundSyncService();
    await syncService.initialize();
    print('✅ BackgroundSyncService initialized');
    
    print('🚀 Triggering immediate sync...');
    await syncService.triggerImmediateSync();
    print('✅ Immediate sync completed');
    
    // Check queue again
    final pendingItems = pendingBox!.values.toList();
    print('📊 Queue after sync: ${pendingItems.length} items remaining');
    
  } catch (e) {
    print('❌ Background sync test failed: $e');
    print('💡 This is likely the root cause of the upload issue');
    print('Stack trace for debugging:');
    print(e.toString());
  }
  
  print('\n🔍 Step 6: Checking Storage Emulator Contents');
  print('===========================================');
  
  try {
    // List all objects in Firebase Storage
    final rootRef = FirebaseStorage.instance.ref();
    final result = await rootRef.listAll();
    
    print('📊 Storage emulator contents:');
    print('   - Total objects: ${result.items.length}');
    
    if (result.items.isEmpty) {
      print('❌ No objects found in Storage emulator');
      print('💡 This confirms the upload issue');
    } else {
      print('📋 Storage objects:');
      for (final item in result.items) {
        print('   - ${item.fullPath}');
      }
    }
    
    // Check vendors directory specifically
    try {
      final vendorsRef = FirebaseStorage.instance.ref().child('vendors');
      final vendorsResult = await vendorsRef.listAll();
      print('📊 Vendors directory: ${vendorsResult.items.length} objects');
      
      if (vendorsResult.prefixes.isNotEmpty) {
        print('📋 Vendor directories:');
        for (final prefix in vendorsResult.prefixes) {
          print('   - ${prefix.name}');
          try {
            final userResult = await prefix.listAll();
            print('     └─ Objects: ${userResult.items.length}');
          } catch (e) {
            print('     └─ Error listing: $e');
          }
        }
      }
    } catch (e) {
      print('💡 No vendors directory found yet: $e');
    }
    
  } catch (e) {
    print('❌ Error checking Storage contents: $e');
  }
  
  print('\n🔍 Step 7: Checking Firestore Contents');
  print('====================================');
  
  try {
    // Check snaps collection
    final snapsQuery = await FirebaseFirestore.instance.collection('snaps').get();
    print('📊 Snaps collection: ${snapsQuery.docs.length} documents');
    
    if (snapsQuery.docs.isEmpty) {
      print('❌ No snaps found in Firestore');
      print('💡 This confirms no successful uploads');
    } else {
      print('📋 Recent snaps:');
      for (final doc in snapsQuery.docs.take(5)) {
        final data = doc.data();
        print('   - ${doc.id}: ${data['vendorName']} (${data['mediaType']})');
      }
    }
    
    // Check vendors collection
    final vendorsQuery = await FirebaseFirestore.instance.collection('vendors').get();
    print('📊 Vendors collection: ${vendorsQuery.docs.length} documents');
    
  } catch (e) {
    print('❌ Error checking Firestore contents: $e');
  }
  
  // Clean up
  if (pendingBox != null) {
    await pendingBox.close();
  }
  
  print('\n🎯 Debug Summary');
  print('================');
  print('✅ If all tests passed, the issue might be in the UI flow');
  print('❌ If any tests failed, check the error messages above');
  print('💡 Common issues:');
  print('   1. File paths not persisting correctly');
  print('   2. Authentication not working in background isolate');
  print('   3. Firebase emulator connectivity issues');
  print('   4. Hive queue not being populated');
  print('\n🏁 Debug script completed');
}

Future<void> _createTestMediaItem(Box<PendingMediaItem> box, User user) async {
  print('\n🧪 Creating test media item...');
  
  try {
    // Create a test image file
    final tempDir = Directory.systemTemp;
    final testImagePath = path.join(tempDir.path, 'test_image.jpg');
    
    // Create a simple test image (1x1 JPEG)
    final testImageBytes = [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
      0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
      0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x80, 0xFF, 0xD9
    ];
    
    await File(testImagePath).writeAsBytes(testImageBytes);
    print('✅ Test image created: $testImagePath');
    
    // Create a pending media item
    final testItem = PendingMediaItem(
      id: 'debug_test_${DateTime.now().millisecondsSinceEpoch}',
      filePath: testImagePath,
      mediaType: MediaType.photo,
      caption: 'Debug test image - ${DateTime.now().toIso8601String()}',
      location: null,
      createdAt: DateTime.now(),
    );
    
    // Add to queue
    await box.put(testItem.id, testItem);
    print('✅ Test media item added to queue: ${testItem.id}');
    
  } catch (e) {
    print('❌ Error creating test media item: $e');
  }
} 