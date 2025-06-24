import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Service for securely managing the Hive encryption key.
/// It uses flutter_secure_storage to store the key, which is more secure
/// than storing it in shared preferences.
class SecureStorageService {
  final _secureStorage = const FlutterSecureStorage();
  final _hiveEncryptionKey = '_hiveEncryptionKey';

  /// Retrieves the Hive encryption key from secure storage.
  /// If a key does not exist, it generates a new one, stores it,
  /// and then returns it.
  Future<List<int>> getHiveEncryptionKey() async {
    // For logging purposes, let's see when we are accessing the key.
    debugPrint('[SecureStorageService] Getting Hive encryption key...');

    String? base64Key = await _secureStorage.read(key: _hiveEncryptionKey);
    if (base64Key == null) {
      debugPrint('[SecureStorageService] No key found. Generating a new one.');
      final key = Hive.generateSecureKey();
      await _secureStorage.write(
        key: _hiveEncryptionKey,
        value: base64Encode(key),
      );
      debugPrint('[SecureStorageService] New key generated and stored.');
      return key;
    } else {
      debugPrint('[SecureStorageService] Existing key found.');
      return base64Decode(base64Key);
    }
  }

  /// Deletes the encryption key. Useful for testing or account resets.
  Future<void> deleteHiveEncryptionKey() async {
    debugPrint('[SecureStorageService] Deleting Hive encryption key.');
    await _secureStorage.delete(key: _hiveEncryptionKey);
    debugPrint('[SecureStorageService] Key deleted.');
  }
}
