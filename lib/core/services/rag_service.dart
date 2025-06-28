import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rag_feedback_service.dart';
import '../models/rag_feedback.dart';

/// Recipe snippet response model
class RecipeSnippet {
  final String recipeName;
  final String snippet;
  final List<String> ingredients;
  final String category;
  final double relevanceScore;
  final bool fromCache;

  RecipeSnippet({
    required this.recipeName,
    required this.snippet,
    required this.ingredients,
    required this.category,
    required this.relevanceScore,
    this.fromCache = false,
  });

  factory RecipeSnippet.fromJson(Map<String, dynamic> json) {
    return RecipeSnippet(
      recipeName: json['recipeName'] ?? '',
      snippet: json['snippet'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      category: json['category'] ?? 'general',
      relevanceScore: (json['relevanceScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipeName': recipeName,
      'snippet': snippet,
      'ingredients': ingredients,
      'category': category,
      'relevanceScore': relevanceScore,
    };
  }

  RecipeSnippet copyWithCache() {
    return RecipeSnippet(
      recipeName: recipeName,
      snippet: snippet,
      ingredients: ingredients,
      category: category,
      relevanceScore: relevanceScore,
      fromCache: true,
    );
  }
}

/// FAQ search result model
class FAQResult {
  final String question;
  final String answer;
  final double score;
  final String vendorId;
  final String category;

  FAQResult({
    required this.question,
    required this.answer,
    required this.score,
    required this.vendorId,
    required this.category,
  });

  factory FAQResult.fromJson(Map<String, dynamic> json) {
    return FAQResult(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      vendorId: json['vendorId'] ?? '',
      category: json['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'score': score,
      'vendorId': vendorId,
      'category': category,
    };
  }
}

/// Combined recipe and FAQ response
class SnapEnhancementData {
  final RecipeSnippet? recipe;
  final List<FAQResult> faqs;
  final String query;
  final bool fromCache;

  SnapEnhancementData({
    this.recipe,
    required this.faqs,
    required this.query,
    this.fromCache = false,
  });

  bool get hasData => hasValidRecipe || faqs.isNotEmpty;

  bool get hasValidRecipe =>
      recipe != null &&
      recipe!.recipeName.isNotEmpty &&
      recipe!.category != 'non_food' &&
      recipe!.relevanceScore >= 0.3;
}

/// RAG service for recipe snippets and FAQ search
class RAGService {
  static const String _cacheBoxName = 'ragCache';
  static const Duration _cacheExpiry = Duration(
    hours: 4,
  ); // Shorter than AI caption cache
  static const Duration _requestTimeout = Duration(seconds: 3);

  late Box<Map> _cacheBox;
  bool _isInitialized = false;
  final RAGFeedbackService _feedbackService = RAGFeedbackService();

  /// Initialize the RAG service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('[RAGService] Initializing cache box', name: 'RAGService');
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _isInitialized = true;
      developer.log(
        '[RAGService] Initialized successfully with ${_cacheBox.length} cached items',
        name: 'RAGService',
      );
    } catch (e) {
      developer.log(
        '[RAGService] Failed to initialize: $e',
        name: 'RAGService',
      );
      rethrow;
    }
  }

  /// Generate cache key for snap enhancement data
  String _generateCacheKey(String caption, String vendorId) {
    final key = '$vendorId:${caption.toLowerCase().trim()}';
    return key.hashCode.toString();
  }

  /// Cache the enhancement data
  Future<void> _cacheData(String key, SnapEnhancementData data) async {
    try {
      final cacheData = {
        'recipe': data.recipe?.toJson(),
        'faqs': data.faqs.map((faq) => faq.toJson()).toList(),
        'query': data.query,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _cacheBox.put(key, cacheData);
      developer.log(
        '[RAGService] Cached data for key: $key',
        name: 'RAGService',
      );
    } catch (e) {
      developer.log('[RAGService] Error caching data: $e', name: 'RAGService');
    }
  }

  /// Extract keywords from caption text
  List<String> _extractKeywords(String caption) {
    // Simple keyword extraction - can be enhanced with NLP
    final words = caption
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();

    // Common produce keywords for better matching
    final produceKeywords = [
      'tomato',
      'lettuce',
      'carrot',
      'onion',
      'potato',
      'pepper',
      'cucumber',
      'apple',
      'banana',
      'orange',
      'grape',
      'berry',
      'strawberry',
      'blueberry',
      'bread',
      'pastry',
      'pie',
      'cake',
      'cookie',
      'muffin',
      'scone',
      'herb',
      'basil',
      'rosemary',
      'thyme',
      'parsley',
      'cilantro',
      'cheese',
      'milk',
      'honey',
      'jam',
      'sauce',
      'pickle',
      'flower',
      'plant',
      'soap',
      'candle',
      'craft',
    ];

    // Add relevant produce keywords found in caption
    final relevantKeywords = produceKeywords
        .where((keyword) => caption.toLowerCase().contains(keyword))
        .toList();

    return {...words, ...relevantKeywords}.toList();
  }

  /// Get recipe snippet and FAQ data for a snap
  Future<SnapEnhancementData> getSnapEnhancements({
    required String caption,
    required String vendorId,
    required String mediaType,
    String? snapId,
  }) async {
    if (!_isInitialized) {
      throw Exception('RAGService not initialized. Call initialize() first.');
    }

    developer.log(
      '[RAGService] ========== STARTING ENHANCEMENT REQUEST ==========',
      name: 'RAGService',
    );
    developer.log('[RAGService] Caption: "$caption"', name: 'RAGService');
    developer.log('[RAGService] VendorId: $vendorId', name: 'RAGService');
    developer.log('[RAGService] MediaType: $mediaType', name: 'RAGService');

    // Generate cache key
    final cacheKey = _generateCacheKey(caption, vendorId);
    developer.log('[RAGService] Cache key: $cacheKey', name: 'RAGService');

    // Extract keywords for search
    final keywords = _extractKeywords(caption);
    developer.log(
      '[RAGService] Extracted keywords: ${keywords.join(", ")}',
      name: 'RAGService',
    );

    // Get user preferences from feedback history to improve suggestions
    Map<String, dynamic> userPreferences = {};
    String? currentUserId;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        currentUserId = currentUser.uid;
        userPreferences = await _feedbackService.getUserPreferences(
          userId: currentUserId,
        );

        if (userPreferences.isNotEmpty) {
          developer.log(
            '[RAGService] User preferences loaded: ${userPreferences['preferredContentType']} content, ${userPreferences['preferredKeywords']?.length ?? 0} preferred keywords',
            name: 'RAGService',
          );
        }
      }
    } catch (e) {
      developer.log(
        '[RAGService] Could not load user preferences: $e',
        name: 'RAGService',
      );
    }

    try {
      // Call Cloud Functions for recipe and FAQ data
      final functions = FirebaseFunctions.instance;

      // Get recipe snippet
      RecipeSnippet? recipe;
      try {
        developer.log(
          '[RAGService] Calling getRecipeSnippet Cloud Function',
          name: 'RAGService',
        );
        final recipeCallable = functions.httpsCallable('getRecipeSnippet');
        final recipeResult = await recipeCallable
            .call({
              'caption': caption,
              'keywords': keywords,
              'mediaType': mediaType,
              'vendorId': vendorId,
              'userPreferences': userPreferences,
            })
            .timeout(_requestTimeout);

        developer.log(
          '[RAGService] Raw recipe result: ${recipeResult.data}',
          name: 'RAGService',
        );

        if (recipeResult.data != null) {
          recipe = RecipeSnippet.fromJson(
            Map<String, dynamic>.from(recipeResult.data),
          );
          developer.log(
            '[RAGService] Parsed recipe: "${recipe.recipeName}" (relevance: ${recipe.relevanceScore})',
            name: 'RAGService',
          );
        } else {
          developer.log(
            '[RAGService] Recipe result data is null',
            name: 'RAGService',
          );
        }
      } catch (e) {
        developer.log(
          '[RAGService] Error getting recipe snippet: $e',
          name: 'RAGService',
        );
      }

      // Get FAQ results
      List<FAQResult> faqs = [];
      try {
        developer.log(
          '[RAGService] Calling vectorSearchFAQ Cloud Function',
          name: 'RAGService',
        );
        final faqCallable = functions.httpsCallable('vectorSearchFAQ');
        final faqResult = await faqCallable
            .call({
              'query': caption,
              'keywords': keywords,
              'vendorId': vendorId,
              'limit': 3, // Get top 3 relevant FAQs
              'userPreferences': userPreferences,
            })
            .timeout(_requestTimeout);

        developer.log(
          '[RAGService] Raw FAQ result: ${faqResult.data}',
          name: 'RAGService',
        );
        developer.log(
          '[RAGService] FAQ result type: ${faqResult.data.runtimeType}',
          name: 'RAGService',
        );

        if (faqResult.data != null) {
          developer.log(
            '[RAGService] FAQ result keys: ${faqResult.data.keys}',
            name: 'RAGService',
          );

          if (faqResult.data['results'] != null) {
            final results = faqResult.data['results'] as List;
            developer.log(
              '[RAGService] FAQ results array length: ${results.length}',
              name: 'RAGService',
            );
            developer.log(
              '[RAGService] FAQ results array: $results',
              name: 'RAGService',
            );

            faqs = results
                .map((result) {
                  developer.log(
                    '[RAGService] Processing FAQ result: $result',
                    name: 'RAGService',
                  );
                  developer.log(
                    '[RAGService] Result type: ${result.runtimeType}',
                    name: 'RAGService',
                  );
                  developer.log(
                    '[RAGService] Result keys: ${result.keys}',
                    name: 'RAGService',
                  );

                  try {
                    final faqResult = FAQResult.fromJson(
                      Map<String, dynamic>.from(result),
                    );
                    developer.log(
                      '[RAGService] ✅ Successfully parsed FAQ: Q="${faqResult.question}" A="${faqResult.answer}" Score=${faqResult.score}',
                      name: 'RAGService',
                    );
                    return faqResult;
                  } catch (e) {
                    developer.log(
                      '[RAGService] ❌ Error parsing FAQ result: $e',
                      name: 'RAGService',
                    );
                    developer.log(
                      '[RAGService] Raw result data: $result',
                      name: 'RAGService',
                    );
                    // Return null to filter out failed parsing attempts
                    return null;
                  }
                })
                .where((faq) => faq != null)
                .cast<FAQResult>()
                .toList();
            developer.log(
              '[RAGService] Final parsed FAQs count: ${faqs.length}',
              name: 'RAGService',
            );
          } else {
            developer.log(
              '[RAGService] FAQ result has no "results" key',
              name: 'RAGService',
            );
          }
        } else {
          developer.log(
            '[RAGService] FAQ result data is null',
            name: 'RAGService',
          );
        }
      } catch (e) {
        developer.log(
          '[RAGService] Error getting FAQ results: $e',
          name: 'RAGService',
        );
      }

      // Create enhancement data
      final enhancementData = SnapEnhancementData(
        recipe: recipe,
        faqs: faqs,
        query: caption,
      );

      developer.log(
        '[RAGService] Created enhancement data - Recipe: ${recipe != null}, FAQs: ${faqs.length}',
        name: 'RAGService',
      );
      developer.log(
        '[RAGService] Enhancement hasData: ${enhancementData.hasData}',
        name: 'RAGService',
      );

      // Cache the data
      await _cacheData(cacheKey, enhancementData);

      developer.log(
        '[RAGService] ========== ENHANCEMENT REQUEST COMPLETE ==========',
        name: 'RAGService',
      );

      return enhancementData;
    } catch (e) {
      developer.log(
        '[RAGService] Critical error getting enhancements: $e',
        name: 'RAGService',
      );

      // Return empty enhancement data on error
      return SnapEnhancementData(faqs: [], query: caption);
    }
  }

  /// Record view tracking for analytics (non-blocking)
  // ignore: unused_element
  void _recordViewTracking({
    required String snapId,
    required String vendorId,
    required SnapEnhancementData enhancementData,
  }) {
    try {
      // Record recipe view
      if (enhancementData.hasValidRecipe) {
        final recipe = enhancementData.recipe!;
        final recipeHash = _generateRecipeHash(recipe);

        _feedbackService.recordRecipeFeedback(
          snapId: snapId,
          vendorId: vendorId,
          action: RAGFeedbackAction.view,
          recipeHash: recipeHash,
          recipeName: recipe.recipeName,
          relevanceScore: recipe.relevanceScore,
          metadata: {
            'keywords': _extractKeywords(enhancementData.query),
            'category': recipe.category,
          },
        );
      }

      // Record FAQ views
      for (final faq in enhancementData.faqs) {
        _feedbackService.recordFAQFeedback(
          snapId: snapId,
          vendorId: vendorId,
          action: RAGFeedbackAction.view,
          faqId: faq.vendorId, // Using vendorId as FAQ ID for now
          faqQuestion: faq.question,
          relevanceScore: faq.score,
          metadata: {
            'keywords': _extractKeywords(enhancementData.query),
            'category': faq.category,
          },
        );
      }
    } catch (e) {
      developer.log(
        '[RAGService] Error recording view tracking: $e',
        name: 'RAGService',
      );
      // Non-blocking - continue execution
    }
  }

  /// Generate a hash for recipe content for consistent tracking
  String _generateRecipeHash(RecipeSnippet recipe) {
    final content = '${recipe.recipeName}:${recipe.ingredients.join(",")}';
    return content.hashCode.toString();
  }

  /// Record user feedback on RAG suggestions
  Future<void> recordFeedback({
    required String snapId,
    required String vendorId,
    required RAGFeedbackAction action,
    required RAGContentType contentType,
    required String contentId,
    required String contentTitle,
    required double relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (contentType == RAGContentType.recipe) {
        await _feedbackService.recordRecipeFeedback(
          snapId: snapId,
          vendorId: vendorId,
          action: action,
          recipeHash: contentId,
          recipeName: contentTitle,
          relevanceScore: relevanceScore,
          userComment: userComment,
          metadata: metadata,
        );
      } else {
        await _feedbackService.recordFAQFeedback(
          snapId: snapId,
          vendorId: vendorId,
          action: action,
          faqId: contentId,
          faqQuestion: contentTitle,
          relevanceScore: relevanceScore,
          userComment: userComment,
          metadata: metadata,
        );
      }

      developer.log(
        '[RAGService] Recorded $action feedback for $contentType: $contentTitle',
        name: 'RAGService',
      );
    } catch (e) {
      developer.log(
        '[RAGService] Error recording feedback: $e',
        name: 'RAGService',
      );
    }
  }

  /// Get feedback analytics for vendor
  Future<Map<String, dynamic>> getVendorAnalytics({
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _feedbackService.getVendorFeedbackAnalytics(
      vendorId: vendorId,
      startDate: startDate,
      endDate: endDate,
    );
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
            final data = Map<String, dynamic>.from(cachedData);
            final timestamp =
                DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now();
            final age = now.difference(timestamp);
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
        developer.log(
          '[RAGService] Cleared ${keysToDelete.length} expired cache entries',
          name: 'RAGService',
        );
      }
    } catch (e) {
      developer.log(
        '[RAGService] Error clearing expired cache: $e',
        name: 'RAGService',
      );
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized) return {'error': 'Not initialized'};

    return {
      'totalEntries': _cacheBox.length,
      'cacheExpiryHours': _cacheExpiry.inHours,
    };
  }
}
