import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marketsnap/core/models/pending_media.dart';
import 'package:marketsnap/core/services/hive_service.dart';
import 'package:marketsnap/core/services/secure_storage_service.dart';
import 'package:marketsnap/core/services/background_sync_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('🔍 Debug: Testing Media Posting Flow');
  debugPrint('=====================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    // Initialize Hive
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized');

    // Register adapters
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MediaTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PendingMediaItemAdapter());
    }
    debugPrint('✅ Hive adapters registered');

    // Initialize services
    final secureStorage = SecureStorageService();
    final hiveService = HiveService(secureStorage);
    await hiveService.init();
    debugPrint('✅ HiveService initialized');

    // Check current user
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('👤 Current user: ${user?.uid ?? "Not authenticated"}');

    // Check pending media queue
    final pendingItems = hiveService.getAllPendingMedia();
    debugPrint('📦 Pending media items: ${pendingItems.length}');

    for (final item in pendingItems) {
      debugPrint('  - ${item.id}: ${item.mediaType} at ${item.filePath}');

      // Check if file exists
      final file = File(item.filePath);
      final exists = await file.exists();
      debugPrint('    File exists: $exists');
      if (exists) {
        final stat = await file.stat();
        debugPrint('    File size: ${stat.size} bytes');
      }
    }

    // Test creating a dummy pending item
    debugPrint('\n🧪 Testing pending media creation...');
    final testItem = PendingMediaItem(
      filePath: '/tmp/test_photo.jpg',
      mediaType: MediaType.photo,
      caption: 'Debug test photo',
      vendorId: user?.uid ?? 'debug_vendor_id',
    );

    await hiveService.addPendingMedia(testItem);
    debugPrint('✅ Test item added to queue: ${testItem.id}');

    // Check queue again
    final updatedPendingItems = hiveService.getAllPendingMedia();
    debugPrint('📦 Updated pending media items: ${updatedPendingItems.length}');

    // Test immediate sync
    if (user != null) {
      debugPrint('\n🚀 Testing immediate sync...');
      final backgroundSync = BackgroundSyncService();
      try {
        await backgroundSync.triggerImmediateSync();
        debugPrint('✅ Immediate sync completed');
      } catch (e) {
        debugPrint('❌ Immediate sync failed: $e');
      }

      // Check queue after sync
      final finalPendingItems = hiveService.getAllPendingMedia();
      debugPrint('📦 Final pending media items: ${finalPendingItems.length}');
    } else {
      debugPrint('⚠️  Skipping sync test - no authenticated user');
    }

    // Clean up
    await hiveService.close();
    debugPrint('✅ Cleanup complete');
  } catch (e, stackTrace) {
    debugPrint('❌ Error during debug: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}
