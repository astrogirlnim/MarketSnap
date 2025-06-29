import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_interests.dart';
import '../models/rag_feedback.dart';

/// Service for managing user interests and personalization for RAG suggestions
/// Stores detailed user behavior patterns and provides personalized recommendation context
class RAGPersonalizationService {
  static const String _collectionName = 'userInterests';
  static const Duration _cacheExpiry = Duration(hours: 2);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user interests to avoid repeated Firestore queries
  final Map<String, UserInterests> _interestsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Get or create user interests for current user
  Future<UserInterests> getUserInterests({String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User must be authenticated to get interests');
    }

    developer.log(
      '[RAGPersonalizationService] Getting user interests for UID: $uid',
      name: 'RAGPersonalizationService',
    );

    // Check cache first
    if (_interestsCache.containsKey(uid)) {
      final cacheTime = _cacheTimestamps[uid];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        developer.log(
          '[RAGPersonalizationService] Returning cached interests for: $uid',
          name: 'RAGPersonalizationService',
        );
        return _interestsCache[uid]!;
      }
    }

    try {
      // Try to load from Firestore
      final doc = await _firestore.collection(_collectionName).doc(uid).get();

      UserInterests interests;
      if (doc.exists) {
        interests = UserInterests.fromFirestore(doc);
        developer.log(
          '[RAGPersonalizationService] Loaded existing interests: ${interests.preferredKeywords.length} keywords, ${interests.totalInteractions} interactions',
          name: 'RAGPersonalizationService',
        );
      } else {
        // Create new empty interests
        interests = UserInterests.empty(uid);
        await _saveUserInterests(interests);
        developer.log(
          '[RAGPersonalizationService] Created new interests for user: $uid',
          name: 'RAGPersonalizationService',
        );
      }

      // Update cache
      _interestsCache[uid] = interests;
      _cacheTimestamps[uid] = DateTime.now();

      return interests;
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error getting user interests: $e',
        name: 'RAGPersonalizationService',
      );

      // Return empty interests on error
      final emptyInterests = UserInterests.empty(uid);
      _interestsCache[uid] = emptyInterests;
      _cacheTimestamps[uid] = DateTime.now();
      return emptyInterests;
    }
  }

  /// Update user interests based on feedback
  Future<void> updateUserInterests({
    required String userId,
    required List<String> keywords,
    required String category,
    required double relevanceScore,
    required bool isPositive,
    String? vendorId,
    String? searchTerm,
  }) async {
    developer.log(
      '[RAGPersonalizationService] Updating interests for user: $userId, keywords: ${keywords.join(", ")}, category: $category, positive: $isPositive',
      name: 'RAGPersonalizationService',
    );

    try {
      // Get current interests
      final currentInterests = await getUserInterests(userId: userId);

      // Update with new feedback
      final updatedInterests = currentInterests.updateWithFeedback(
        keywords: keywords,
        category: category,
        relevanceScore: relevanceScore,
        isPositive: isPositive,
        vendorId: vendorId,
        searchTerm: searchTerm,
      );

      // Save updated interests
      await _saveUserInterests(updatedInterests);

      // Update cache
      _interestsCache[userId] = updatedInterests;
      _cacheTimestamps[userId] = DateTime.now();

      developer.log(
        '[RAGPersonalizationService] Updated user interests: ${updatedInterests.preferredKeywords.length} keywords, satisfaction: ${updatedInterests.satisfactionScore.toStringAsFixed(2)}',
        name: 'RAGPersonalizationService',
      );
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error updating user interests: $e',
        name: 'RAGPersonalizationService',
      );
      // Don't throw - personalization is non-critical
    }
  }

  /// Save user interests to Firestore
  Future<void> _saveUserInterests(UserInterests interests) async {
    await _firestore
        .collection(_collectionName)
        .doc(interests.userId)
        .set(interests.toFirestore());
  }

  /// Get personalization context for RAG prompts
  Future<Map<String, dynamic>> getPersonalizationContext({
    String? userId,
  }) async {
    try {
      final interests = await getUserInterests(userId: userId);

      if (!interests.hasSignificantData) {
        developer.log(
          '[RAGPersonalizationService] Insufficient data for personalization (${interests.totalInteractions} interactions)',
          name: 'RAGPersonalizationService',
        );
        return {};
      }

      final context = interests.toPersonalizationContext();

      developer.log(
        '[RAGPersonalizationService] Generated personalization context: ${context['preferredKeywords']?.length ?? 0} keywords, confidence: ${interests.personalizationConfidence.toStringAsFixed(2)}',
        name: 'RAGPersonalizationService',
      );

      return context;
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error getting personalization context: $e',
        name: 'RAGPersonalizationService',
      );
      return {};
    }
  }

  /// Get enhanced user preferences combining feedback history and stored interests
  Future<Map<String, dynamic>> getEnhancedUserPreferences({
    String? userId,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return {};

    try {
      // Get detailed interests
      final interests = await getUserInterests(userId: uid);

      // Create enhanced preferences
      final enhancedPreferences = {
        'preferredKeywords': interests.preferredKeywords,
        'preferredCategories': interests.preferredCategories,
        'preferredContentType': interests.preferredContentType,
        'totalPositiveFeedback': interests.totalPositiveFeedback,
        'engagementRate': interests.engagementRate,
        'satisfactionScore': interests.satisfactionScore,
        'personalizationConfidence': interests.personalizationConfidence,
        'recentSearchTerms': interests.recentSearchTerms.take(5).toList(),
        'favoriteVendors': interests.favoriteVendors.take(3).toList(),
        'keywordRelevanceScores': interests.keywordRelevanceScores,
        'categoryRelevanceScores': interests.categoryRelevanceScores,
        'hasSignificantData': interests.hasSignificantData,
        'lastUpdated': interests.lastUpdated.toIso8601String(),
      };

      developer.log(
        '[RAGPersonalizationService] Enhanced preferences: ${(enhancedPreferences['preferredKeywords'] as List<dynamic>?)?.length ?? 0} keywords, confidence: ${enhancedPreferences['personalizationConfidence']}',
        name: 'RAGPersonalizationService',
      );

      return enhancedPreferences;
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error getting enhanced preferences: $e',
        name: 'RAGPersonalizationService',
      );
      return {};
    }
  }

  /// Process RAG feedback and update user interests
  Future<void> processFeedback(RAGFeedback feedback) async {
    try {
      // Extract keywords and category from metadata
      final keywords = <String>[];
      String category = 'general';

      if (feedback.metadata != null) {
        final metadataKeywords =
            feedback.metadata!['keywords'] as List<dynamic>?;
        if (metadataKeywords != null) {
          keywords.addAll(metadataKeywords.cast<String>());
        }

        final metadataCategory = feedback.metadata!['category'] as String?;
        if (metadataCategory != null) {
          category = metadataCategory;
        }
      }

      // Add content title as a keyword if available
      if (feedback.contentTitle != null && feedback.contentTitle!.isNotEmpty) {
        final titleWords = feedback.contentTitle!
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .split(' ')
            .where((word) => word.length > 2)
            .toList();
        keywords.addAll(titleWords);
      }

      // Update user interests
      await updateUserInterests(
        userId: feedback.userId,
        keywords: keywords,
        category: category,
        relevanceScore: feedback.relevanceScore ?? 0.5,
        isPositive: feedback.isPositive,
        vendorId: feedback.vendorId,
        searchTerm: feedback.metadata?['searchTerm'],
      );

      developer.log(
        '[RAGPersonalizationService] Processed feedback: ${feedback.action} for ${feedback.contentType} (${keywords.length} keywords)',
        name: 'RAGPersonalizationService',
      );
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error processing feedback: $e',
        name: 'RAGPersonalizationService',
      );
      // Don't throw - personalization is non-critical
    }
  }

  /// Clear user interests cache
  void clearCache({String? userId}) {
    if (userId != null) {
      _interestsCache.remove(userId);
      _cacheTimestamps.remove(userId);
      developer.log(
        '[RAGPersonalizationService] Cleared cache for user: $userId',
        name: 'RAGPersonalizationService',
      );
    } else {
      _interestsCache.clear();
      _cacheTimestamps.clear();
      developer.log(
        '[RAGPersonalizationService] Cleared all interests cache',
        name: 'RAGPersonalizationService',
      );
    }
  }

  /// Get user interest analytics
  Future<Map<String, dynamic>> getUserInterestAnalytics({
    String? userId,
  }) async {
    try {
      final interests = await getUserInterests(userId: userId);

      return {
        'totalInteractions': interests.totalInteractions,
        'totalPositiveFeedback': interests.totalPositiveFeedback,
        'totalNegativeFeedback': interests.totalNegativeFeedback,
        'engagementRate': interests.engagementRate,
        'satisfactionScore': interests.satisfactionScore,
        'personalizationConfidence': interests.personalizationConfidence,
        'preferredKeywordsCount': interests.preferredKeywords.length,
        'preferredCategoriesCount': interests.preferredCategories.length,
        'recentSearchTermsCount': interests.recentSearchTerms.length,
        'favoriteVendorsCount': interests.favoriteVendors.length,
        'topKeywords': interests.preferredKeywords.take(5).toList(),
        'topCategories': interests.preferredCategories.take(3).toList(),
        'hasSignificantData': interests.hasSignificantData,
        'createdAt': interests.createdAt.toIso8601String(),
        'lastUpdated': interests.lastUpdated.toIso8601String(),
      };
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error getting analytics: $e',
        name: 'RAGPersonalizationService',
      );
      return {};
    }
  }

  /// Calculate content ranking based on user preferences
  List<T> rankContentByPreferences<T>(
    List<T> content,
    UserInterests interests,
    double Function(T item) getRelevanceScore,
    List<String> Function(T item) getKeywords,
    String Function(T item) getCategory,
  ) {
    if (!interests.hasSignificantData || content.isEmpty) {
      return content;
    }

    // Score each item based on user preferences
    final scoredContent = content.map((item) {
      final baseScore = getRelevanceScore(item);
      final keywords = getKeywords(item);
      final category = getCategory(item);

      // Calculate preference bonus
      double preferenceBonus = 0.0;

      // Keyword preference bonus
      for (final keyword in keywords) {
        if (interests.preferredKeywords.contains(keyword)) {
          final keywordScore = interests.keywordRelevanceScores[keyword] ?? 0.5;
          preferenceBonus += keywordScore * 0.1; // Max 10% bonus per keyword
        }
      }

      // Category preference bonus
      if (interests.preferredCategories.contains(category)) {
        final categoryScore =
            interests.categoryRelevanceScores[category] ?? 0.5;
        preferenceBonus += categoryScore * 0.2; // Max 20% bonus for category
      }

      // Apply confidence weighting
      final confidenceWeight = interests.personalizationConfidence;
      final finalScore = baseScore + (preferenceBonus * confidenceWeight);

      return MapEntry(item, finalScore);
    }).toList();

    // Sort by final score (descending)
    scoredContent.sort((a, b) => b.value.compareTo(a.value));

    developer.log(
      '[RAGPersonalizationService] Ranked ${content.length} items by preferences (confidence: ${interests.personalizationConfidence.toStringAsFixed(2)})',
      name: 'RAGPersonalizationService',
    );

    return scoredContent.map((entry) => entry.key).toList();
  }

  /// Delete user interests (for account deletion)
  Future<void> deleteUserInterests(String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).delete();

      // Clear from cache
      _interestsCache.remove(userId);
      _cacheTimestamps.remove(userId);

      developer.log(
        '[RAGPersonalizationService] Deleted user interests for: $userId',
        name: 'RAGPersonalizationService',
      );
    } catch (e) {
      developer.log(
        '[RAGPersonalizationService] Error deleting user interests: $e',
        name: 'RAGPersonalizationService',
      );
      throw Exception('Failed to delete user interests: $e');
    }
  }
}
