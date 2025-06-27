import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// AI-generated caption response model
class AICaptionResponse {
  final String caption;
  final double confidence;
  final String model;
  final DateTime timestamp;
  final bool fromCache;

  AICaptionResponse({
    required this.caption,
    required this.confidence,
    required this.model,
    required this.timestamp,
    this.fromCache = false,
  });

  factory AICaptionResponse.fromJson(Map<String, dynamic> json) {
    return AICaptionResponse(
      caption: json['caption'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      model: json['model'] ?? 'unknown',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caption': caption,
      'confidence': confidence,
      'model': model,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create a cached version of this response
  AICaptionResponse copyWithCache() {
    return AICaptionResponse(
      caption: caption,
      confidence: confidence,
      model: model,
      timestamp: timestamp,
      fromCache: true,
    );
  }
}

/// Service for AI-powered caption generation with caching
class AICaptionService {
  static const String _cacheBoxName = 'aiCaptionCache';
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const Duration _requestTimeout = Duration(seconds: 2);
  
  late Box<Map> _cacheBox;
  bool _isInitialized = false;

  /// Initialize the AI caption service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('[AICaptionService] Initializing cache box', name: 'AICaptionService');
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _isInitialized = true;
      developer.log('[AICaptionService] Initialized successfully with ${_cacheBox.length} cached captions', name: 'AICaptionService');
    } catch (e) {
      developer.log('[AICaptionService] Failed to initialize: $e', name: 'AICaptionService');
      rethrow;
    }
  }

  /// Generate a media hash for caching
  String _generateMediaHash(String filePath, String? existingCaption, Map<String, dynamic>? vendorProfile) {
    try {
      final file = File(filePath);
      final fileSize = file.lengthSync();
      final lastModified = file.lastModifiedSync().millisecondsSinceEpoch;
      
      // Create a unique hash based on file properties and context
      final hashInput = '$filePath:$fileSize:$lastModified:${existingCaption ?? ''}:${jsonEncode(vendorProfile ?? {})}';
      final bytes = utf8.encode(hashInput);
      final digest = sha1.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      developer.log('[AICaptionService] Error generating hash: $e', name: 'AICaptionService');
      // Fallback to simple hash
      return filePath.hashCode.toString();
    }
  }

  /// Check if cached caption exists and is still valid
  AICaptionResponse? _getCachedCaption(String hash) {
    try {
      final cachedData = _cacheBox.get(hash);
      if (cachedData == null) return null;

      final response = AICaptionResponse.fromJson(Map<String, dynamic>.from(cachedData));
      
      // Check if cache is expired
      final age = DateTime.now().difference(response.timestamp);
      if (age > _cacheExpiry) {
        developer.log('[AICaptionService] Cache expired for hash: $hash', name: 'AICaptionService');
        _cacheBox.delete(hash);
        return null;
      }

      developer.log('[AICaptionService] Cache hit for hash: $hash', name: 'AICaptionService');
      return response.copyWithCache();
    } catch (e) {
      developer.log('[AICaptionService] Error reading cache: $e', name: 'AICaptionService');
      return null;
    }
  }

  /// Cache the AI caption response
  Future<void> _cacheCaption(String hash, AICaptionResponse response) async {
    try {
      await _cacheBox.put(hash, response.toJson());
      developer.log('[AICaptionService] Cached caption for hash: $hash', name: 'AICaptionService');
    } catch (e) {
      developer.log('[AICaptionService] Error caching caption: $e', name: 'AICaptionService');
    }
  }

  /// Generate caption using AI or return cached version
  Future<AICaptionResponse> generateCaption({
    required String mediaPath,
    String? mediaType,
    String? existingCaption,
    Map<String, dynamic>? vendorProfile,
  }) async {
    if (!_isInitialized) {
      throw Exception('AICaptionService not initialized. Call initialize() first.');
    }

    developer.log('[AICaptionService] Generating caption for media: $mediaPath', name: 'AICaptionService');
    
    // Generate cache key
    final hash = _generateMediaHash(mediaPath, existingCaption, vendorProfile);
    
    // Check cache first
    final cachedResponse = _getCachedCaption(hash);
    if (cachedResponse != null) {
      developer.log('[AICaptionService] Returning cached caption', name: 'AICaptionService');
      return cachedResponse;
    }

    // Call Cloud Function with timeout
    try {
      developer.log('[AICaptionService] Calling generateCaption Cloud Function', name: 'AICaptionService');
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generateCaption');
      
      final result = await callable.call({
        'mediaType': mediaType ?? 'photo',
        'existingCaption': existingCaption,
        'vendorProfile': vendorProfile,
      }).timeout(_requestTimeout);

      developer.log('[AICaptionService] Cloud Function response: ${result.data}', name: 'AICaptionService');

      // Parse response
      final data = result.data as Map<String, dynamic>;
      final response = AICaptionResponse.fromJson(data);

      // Cache the response
      await _cacheCaption(hash, response);

      developer.log('[AICaptionService] Generated caption: "${response.caption}" (confidence: ${response.confidence})', name: 'AICaptionService');
      return response;

    } catch (e) {
      developer.log('[AICaptionService] Error calling Cloud Function: $e', name: 'AICaptionService');
      
      // Return fallback response for better UX
      return AICaptionResponse(
        caption: _getFallbackCaption(mediaType),
        confidence: 0.5,
        model: 'fallback',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get fallback caption when AI service fails
  String _getFallbackCaption(String? mediaType) {
    final fallbacks = [
      'Fresh from the market! 🌿',
      'Quality produce at its finest 🍅',
      'Farm fresh goodness 🌽',
      'Local and delicious! 🥬',
      'Straight from our fields 🌱',
    ];
    
    final random = DateTime.now().millisecond % fallbacks.length;
    return fallbacks[random];
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final key in _cacheBox.keys) {
        try {
          final cachedData = _cacheBox.get(key);
          if (cachedData != null) {
            final response = AICaptionResponse.fromJson(Map<String, dynamic>.from(cachedData));
            final age = now.difference(response.timestamp);
            if (age > _cacheExpiry) {
              keysToDelete.add(key.toString());
            }
          }
        } catch (e) {
          // Delete corrupted entries
          keysToDelete.add(key.toString());
        }
      }

      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        developer.log('[AICaptionService] Cleared ${keysToDelete.length} expired cache entries', name: 'AICaptionService');
      }
    } catch (e) {
      developer.log('[AICaptionService] Error clearing expired cache: $e', name: 'AICaptionService');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized) return {'initialized': false};

    try {
      final totalEntries = _cacheBox.length;
      final now = DateTime.now();
      int validEntries = 0;
      int expiredEntries = 0;

      for (final value in _cacheBox.values) {
        try {
          final response = AICaptionResponse.fromJson(Map<String, dynamic>.from(value));
          final age = now.difference(response.timestamp);
          if (age <= _cacheExpiry) {
            validEntries++;
          } else {
            expiredEntries++;
          }
        } catch (e) {
          expiredEntries++;
        }
      }

      return {
        'initialized': true,
        'totalEntries': totalEntries,
        'validEntries': validEntries,
        'expiredEntries': expiredEntries,
        'cacheHitRate': totalEntries > 0 ? (validEntries / totalEntries * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      return {'initialized': true, 'error': e.toString()};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _cacheBox.close();
      _isInitialized = false;
      developer.log('[AICaptionService] Disposed', name: 'AICaptionService');
    }
  }
} 