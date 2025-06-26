import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../lib/core/models/pending_media.dart';
import '../lib/core/services/hive_service.dart';
import '../lib/core/services/secure_storage_service.dart';
import '../lib/core/services/background_sync_service.dart';

void main() async {
  print('🔍 Debug: Testing Media Posting Flow');
  print('=====================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    // Initialize Hive
    await Hive.initFlutter();
    print('✅ Hive initialized');

    // Register adapters
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MediaTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PendingMediaItemAdapter());
    }
    print('✅ Hive adapters registered');

    // Initialize services
    final secureStorage = SecureStorageService();
    final hiveService = HiveService(secureStorage);
    await hiveService.init();
    print('✅ HiveService initialized');

    // Check current user
    final user = FirebaseAuth.instance.currentUser;
    print('👤 Current user: ${user?.uid ?? "Not authenticated"}');

    // Check pending media queue
    final pendingItems = hiveService.getAllPendingMedia();
    print('📦 Pending media items: ${pendingItems.length}');
    
    for (final item in pendingItems) {
      print('  - ${item.id}: ${item.mediaType} at ${item.filePath}');
      
      // Check if file exists
      final file = File(item.filePath);
      final exists = await file.exists();
      print('    File exists: $exists');
      if (exists) {
        final stat = await file.stat();
        print('    File size: ${stat.size} bytes');
      }
    }

    // Test creating a dummy pending item
    print('\n🧪 Testing pending media creation...');
    final testItem = PendingMediaItem(
      filePath: '/tmp/test_photo.jpg',
      mediaType: MediaType.photo,
      caption: 'Debug test photo',
    );
    
    await hiveService.addPendingMedia(testItem);
    print('✅ Test item added to queue: ${testItem.id}');

    // Check queue again
    final updatedPendingItems = hiveService.getAllPendingMedia();
    print('📦 Updated pending media items: ${updatedPendingItems.length}');

    // Test immediate sync
    if (user != null) {
      print('\n🚀 Testing immediate sync...');
      final backgroundSync = BackgroundSyncService();
      try {
        await backgroundSync.triggerImmediateSync();
        print('✅ Immediate sync completed');
      } catch (e) {
        print('❌ Immediate sync failed: $e');
      }

      // Check queue after sync
      final finalPendingItems = hiveService.getAllPendingMedia();
      print('📦 Final pending media items: ${finalPendingItems.length}');
    } else {
      print('⚠️  Skipping sync test - no authenticated user');
    }

    // Clean up
    await hiveService.close();
    print('✅ Cleanup complete');

  } catch (e, stackTrace) {
    print('❌ Error during debug: $e');
    print('Stack trace: $stackTrace');
  }
} 