import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rag_feedback.dart';

/// Service for handling RAG feedback and analytics
/// Tracks user interactions with recipe and FAQ suggestions for personalization
class RAGFeedbackService {
  static const String _collectionName = 'ragFeedback';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RAGFeedbackService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Record user feedback on a RAG suggestion
  Future<void> recordFeedback(RAGFeedback feedback) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        developer.log(
          '[RAGFeedbackService] No authenticated user - skipping feedback recording',
          name: 'RAGFeedbackService',
        );
        return;
      }

      // Ensure feedback is for the current user
      final userFeedback = feedback.copyWith(userId: currentUser.uid);

      developer.log(
        '[RAGFeedbackService] Recording ${userFeedback.action} feedback for ${userFeedback.contentType} content: ${userFeedback.contentTitle}',
        name: 'RAGFeedbackService',
      );

      await _firestore
          .collection(_collectionName)
          .add(userFeedback.toFirestore());

      developer.log(
        '[RAGFeedbackService] Feedback recorded successfully',
        name: 'RAGFeedbackService',
      );
    } catch (e) {
      developer.log(
        '[RAGFeedbackService] Error recording feedback: $e',
        name: 'RAGFeedbackService',
      );
      // Don't throw - feedback recording should be non-blocking
    }
  }

  /// Record recipe feedback
  Future<void> recordRecipeFeedback({
    required String snapId,
    required String vendorId,
    required RAGFeedbackAction action,
    required String recipeHash,
    required String recipeName,
    required double relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final feedback = RAGFeedback.recipe(
      userId: currentUser.uid,
      snapId: snapId,
      vendorId: vendorId,
      action: action,
      recipeHash: recipeHash,
      recipeName: recipeName,
      relevanceScore: relevanceScore,
      userComment: userComment,
      metadata: metadata,
    );

    await recordFeedback(feedback);
  }

  /// Record FAQ feedback
  Future<void> recordFAQFeedback({
    required String snapId,
    required String vendorId,
    required RAGFeedbackAction action,
    required String faqId,
    required String faqQuestion,
    required double relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final feedback = RAGFeedback.faq(
      userId: currentUser.uid,
      snapId: snapId,
      vendorId: vendorId,
      action: action,
      faqId: faqId,
      faqQuestion: faqQuestion,
      relevanceScore: relevanceScore,
      userComment: userComment,
      metadata: metadata,
    );

    await recordFeedback(feedback);
  }

  /// Get user's feedback history for a specific content type
  Future<List<RAGFeedback>> getUserFeedbackHistory({
    required String userId,
    RAGContentType? contentType,
    int limit = 50,
  }) async {
    try {
      developer.log(
        '[RAGFeedbackService] Getting feedback history for user: $userId${contentType != null ? ' (type: $contentType)' : ''}',
        name: 'RAGFeedbackService',
      );

      Query query = _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (contentType != null) {
        query = query.where(
          'contentType',
          isEqualTo: contentType.toString().split('.').last,
        );
      }

      final snapshot = await query.get();

      final feedback = snapshot.docs
          .map((doc) => RAGFeedback.fromFirestore(doc))
          .toList();

      developer.log(
        '[RAGFeedbackService] Retrieved ${feedback.length} feedback items',
        name: 'RAGFeedbackService',
      );

      return feedback;
    } catch (e) {
      developer.log(
        '[RAGFeedbackService] Error getting feedback history: $e',
        name: 'RAGFeedbackService',
      );
      return [];
    }
  }

  /// Get feedback analytics for a specific vendor
  Future<Map<String, dynamic>> getVendorFeedbackAnalytics({
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      developer.log(
        '[RAGFeedbackService] Getting analytics for vendor: $vendorId',
        name: 'RAGFeedbackService',
      );

      Query query = _firestore
          .collection(_collectionName)
          .where('vendorId', isEqualTo: vendorId);

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      final feedback = snapshot.docs
          .map((doc) => RAGFeedback.fromFirestore(doc))
          .toList();

      // Calculate analytics
      final analytics = _calculateAnalytics(feedback);

      developer.log(
        '[RAGFeedbackService] Calculated analytics for ${feedback.length} feedback items',
        name: 'RAGFeedbackService',
      );

      return analytics;
    } catch (e) {
      developer.log(
        '[RAGFeedbackService] Error getting vendor analytics: $e',
        name: 'RAGFeedbackService',
      );
      return {};
    }
  }

  /// Get user preferences based on feedback history
  Future<Map<String, dynamic>> getUserPreferences({
    required String userId,
  }) async {
    try {
      final feedback = await getUserFeedbackHistory(userId: userId, limit: 100);
      return _calculateUserPreferences(feedback);
    } catch (e) {
      developer.log(
        '[RAGFeedbackService] Error getting user preferences: $e',
        name: 'RAGFeedbackService',
      );
      return {};
    }
  }

  /// Calculate analytics from feedback data
  Map<String, dynamic> _calculateAnalytics(List<RAGFeedback> feedback) {
    if (feedback.isEmpty) {
      return {
        'totalFeedback': 0,
        'totalUpvotes': 0,
        'totalDownvotes': 0,
        'totalSkips': 0,
        'totalEdits': 0,
        'totalViews': 0,
        'totalExpands': 0,
        'engagementRate': 0.0,
        'satisfactionScore': 0.0,
        'recipeAnalytics': {},
        'faqAnalytics': {},
      };
    }

    final totalFeedback = feedback.length;
    final upvotes = feedback
        .where((f) => f.action == RAGFeedbackAction.upvote)
        .length;
    final downvotes = feedback
        .where((f) => f.action == RAGFeedbackAction.downvote)
        .length;
    final skips = feedback
        .where((f) => f.action == RAGFeedbackAction.skip)
        .length;
    final edits = feedback
        .where((f) => f.action == RAGFeedbackAction.edit)
        .length;
    final views = feedback
        .where((f) => f.action == RAGFeedbackAction.view)
        .length;
    final expands = feedback
        .where((f) => f.action == RAGFeedbackAction.expand)
        .length;

    final engagementActions = feedback
        .where((f) => f.isEngagement || f.isPositive)
        .length;
    final engagementRate = totalFeedback > 0
        ? engagementActions / totalFeedback
        : 0.0;

    final positiveActions = feedback.where((f) => f.isPositive).length;
    final negativeActions = feedback.where((f) => f.isNegative).length;
    final satisfactionScore = (positiveActions + negativeActions) > 0
        ? positiveActions / (positiveActions + negativeActions)
        : 0.0;

    // Content type analytics
    final recipeFeedback = feedback
        .where((f) => f.contentType == RAGContentType.recipe)
        .toList();
    final faqFeedback = feedback
        .where((f) => f.contentType == RAGContentType.faq)
        .toList();

    return {
      'totalFeedback': totalFeedback,
      'totalUpvotes': upvotes,
      'totalDownvotes': downvotes,
      'totalSkips': skips,
      'totalEdits': edits,
      'totalViews': views,
      'totalExpands': expands,
      'engagementRate': engagementRate,
      'satisfactionScore': satisfactionScore,
      'recipeAnalytics': _calculateContentAnalytics(recipeFeedback),
      'faqAnalytics': _calculateContentAnalytics(faqFeedback),
    };
  }

  /// Calculate analytics for specific content type
  Map<String, dynamic> _calculateContentAnalytics(List<RAGFeedback> feedback) {
    if (feedback.isEmpty) return {};

    final totalItems = feedback.length;
    final avgRelevanceScore =
        feedback
            .where((f) => f.relevanceScore != null)
            .map((f) => f.relevanceScore!)
            .fold(0.0, (total, score) => total + score) /
        feedback.where((f) => f.relevanceScore != null).length;

    return {
      'totalItems': totalItems,
      'averageRelevanceScore': avgRelevanceScore,
      'positiveRate': feedback.where((f) => f.isPositive).length / totalItems,
      'negativeRate': feedback.where((f) => f.isNegative).length / totalItems,
    };
  }

  /// Calculate user preferences from feedback history
  Map<String, dynamic> _calculateUserPreferences(List<RAGFeedback> feedback) {
    if (feedback.isEmpty) return {};

    // Analyze user's positive feedback patterns
    final positiveFeedback = feedback.where((f) => f.isPositive).toList();

    // Extract keywords from metadata of positively rated content
    final positiveKeywords = <String>[];
    final positiveCategories = <String>[];

    for (final item in positiveFeedback) {
      if (item.metadata != null) {
        final keywords = item.metadata!['keywords'] as List<dynamic>?;
        if (keywords != null) {
          positiveKeywords.addAll(keywords.cast<String>());
        }

        final category = item.metadata!['category'] as String?;
        if (category != null) {
          positiveCategories.add(category);
        }
      }
    }

    // Count keyword and category frequencies
    final keywordCounts = <String, int>{};
    final categoryCounts = <String, int>{};

    for (final keyword in positiveKeywords) {
      keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
    }

    for (final category in positiveCategories) {
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    // Sort by frequency
    final topKeywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'preferredKeywords': topKeywords.take(10).map((e) => e.key).toList(),
      'preferredCategories': topCategories.take(5).map((e) => e.key).toList(),
      'totalPositiveFeedback': positiveFeedback.length,
      'preferredContentType': _getPreferredContentType(positiveFeedback),
    };
  }

  /// Determine user's preferred content type based on positive feedback
  String _getPreferredContentType(List<RAGFeedback> positiveFeedback) {
    final recipeCount = positiveFeedback
        .where((f) => f.contentType == RAGContentType.recipe)
        .length;
    final faqCount = positiveFeedback
        .where((f) => f.contentType == RAGContentType.faq)
        .length;

    if (recipeCount > faqCount) return 'recipe';
    if (faqCount > recipeCount) return 'faq';
    return 'balanced';
  }
}
