import 'package:cloud_firestore/cloud_firestore.dart';

/// User interests and preferences for RAG personalization
/// Stores detailed user behavior patterns and preferences for better recipe/FAQ suggestions
class UserInterests {
  final String userId;
  final List<String> preferredKeywords;
  final List<String> preferredCategories;
  final String preferredContentType; // 'recipe', 'faq', 'balanced'
  final Map<String, int> keywordInteractions; // keyword -> interaction count
  final Map<String, int> categoryInteractions; // category -> interaction count
  final Map<String, double> keywordRelevanceScores; // keyword -> avg relevance
  final Map<String, double> categoryRelevanceScores; // category -> avg relevance
  final int totalPositiveFeedback;
  final int totalNegativeFeedback;
  final int totalInteractions;
  final double engagementRate;
  final double satisfactionScore;
  final List<String> recentSearchTerms;
  final List<String> favoriteVendors;
  final DateTime lastUpdated;
  final DateTime createdAt;

  UserInterests({
    required this.userId,
    required this.preferredKeywords,
    required this.preferredCategories,
    required this.preferredContentType,
    required this.keywordInteractions,
    required this.categoryInteractions,
    required this.keywordRelevanceScores,
    required this.categoryRelevanceScores,
    required this.totalPositiveFeedback,
    required this.totalNegativeFeedback,
    required this.totalInteractions,
    required this.engagementRate,
    required this.satisfactionScore,
    required this.recentSearchTerms,
    required this.favoriteVendors,
    required this.lastUpdated,
    required this.createdAt,
  });

  /// Create UserInterests from Firestore document
  factory UserInterests.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UserInterests(
      userId: doc.id,
      preferredKeywords: List<String>.from(data['preferredKeywords'] ?? []),
      preferredCategories: List<String>.from(data['preferredCategories'] ?? []),
      preferredContentType: data['preferredContentType'] ?? 'balanced',
      keywordInteractions: Map<String, int>.from(data['keywordInteractions'] ?? {}),
      categoryInteractions: Map<String, int>.from(data['categoryInteractions'] ?? {}),
      keywordRelevanceScores: Map<String, double>.from(data['keywordRelevanceScores'] ?? {}),
      categoryRelevanceScores: Map<String, double>.from(data['categoryRelevanceScores'] ?? {}),
      totalPositiveFeedback: data['totalPositiveFeedback'] ?? 0,
      totalNegativeFeedback: data['totalNegativeFeedback'] ?? 0,
      totalInteractions: data['totalInteractions'] ?? 0,
      engagementRate: (data['engagementRate'] ?? 0.0).toDouble(),
      satisfactionScore: (data['satisfactionScore'] ?? 0.0).toDouble(),
      recentSearchTerms: List<String>.from(data['recentSearchTerms'] ?? []),
      favoriteVendors: List<String>.from(data['favoriteVendors'] ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert UserInterests to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'preferredKeywords': preferredKeywords,
      'preferredCategories': preferredCategories,
      'preferredContentType': preferredContentType,
      'keywordInteractions': keywordInteractions,
      'categoryInteractions': categoryInteractions,
      'keywordRelevanceScores': keywordRelevanceScores,
      'categoryRelevanceScores': categoryRelevanceScores,
      'totalPositiveFeedback': totalPositiveFeedback,
      'totalNegativeFeedback': totalNegativeFeedback,
      'totalInteractions': totalInteractions,
      'engagementRate': engagementRate,
      'satisfactionScore': satisfactionScore,
      'recentSearchTerms': recentSearchTerms,
      'favoriteVendors': favoriteVendors,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create empty UserInterests for new user
  factory UserInterests.empty(String userId) {
    final now = DateTime.now();
    return UserInterests(
      userId: userId,
      preferredKeywords: [],
      preferredCategories: [],
      preferredContentType: 'balanced',
      keywordInteractions: {},
      categoryInteractions: {},
      keywordRelevanceScores: {},
      categoryRelevanceScores: {},
      totalPositiveFeedback: 0,
      totalNegativeFeedback: 0,
      totalInteractions: 0,
      engagementRate: 0.0,
      satisfactionScore: 0.0,
      recentSearchTerms: [],
      favoriteVendors: [],
      lastUpdated: now,
      createdAt: now,
    );
  }

  /// Update interests with new feedback data
  UserInterests updateWithFeedback({
    required List<String> keywords,
    required String category,
    required double relevanceScore,
    required bool isPositive,
    String? vendorId,
    String? searchTerm,
  }) {
    final now = DateTime.now();
    
    // Update keyword interactions and scores
    final newKeywordInteractions = Map<String, int>.from(keywordInteractions);
    final newKeywordRelevanceScores = Map<String, double>.from(keywordRelevanceScores);
    
    for (final keyword in keywords) {
      newKeywordInteractions[keyword] = (newKeywordInteractions[keyword] ?? 0) + 1;
      
      // Update relevance score (weighted average)
      final currentScore = newKeywordRelevanceScores[keyword] ?? relevanceScore;
      final currentCount = newKeywordInteractions[keyword]!;
      newKeywordRelevanceScores[keyword] = 
        ((currentScore * (currentCount - 1)) + relevanceScore) / currentCount;
    }

    // Update category interactions and scores
    final newCategoryInteractions = Map<String, int>.from(categoryInteractions);
    final newCategoryRelevanceScores = Map<String, double>.from(categoryRelevanceScores);
    
    newCategoryInteractions[category] = (newCategoryInteractions[category] ?? 0) + 1;
    final currentCategoryScore = newCategoryRelevanceScores[category] ?? relevanceScore;
    final currentCategoryCount = newCategoryInteractions[category]!;
    newCategoryRelevanceScores[category] = 
      ((currentCategoryScore * (currentCategoryCount - 1)) + relevanceScore) / currentCategoryCount;

    // Update totals and rates
    final newTotalPositive = totalPositiveFeedback + (isPositive ? 1 : 0);
    final newTotalNegative = totalNegativeFeedback + (!isPositive ? 1 : 0);
    final newTotalInteractions = totalInteractions + 1;
    final newEngagementRate = newTotalInteractions > 0 
      ? (newTotalPositive + newTotalNegative) / newTotalInteractions 
      : 0.0;
    final newSatisfactionScore = (newTotalPositive + newTotalNegative) > 0
      ? newTotalPositive / (newTotalPositive + newTotalNegative)
      : 0.0;

    // Update preferred keywords and categories (top 10 by interaction count)
    final topKeywords = newKeywordInteractions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = newCategoryInteractions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Update recent search terms (keep last 20)
    final newRecentSearchTerms = List<String>.from(recentSearchTerms);
    if (searchTerm != null && searchTerm.isNotEmpty) {
      newRecentSearchTerms.insert(0, searchTerm);
      if (newRecentSearchTerms.length > 20) {
        newRecentSearchTerms.removeRange(20, newRecentSearchTerms.length);
      }
    }

    // Update favorite vendors (keep last 10)
    final newFavoriteVendors = List<String>.from(favoriteVendors);
    if (vendorId != null && isPositive) {
      newFavoriteVendors.remove(vendorId); // Remove if exists
      newFavoriteVendors.insert(0, vendorId); // Add to front
      if (newFavoriteVendors.length > 10) {
        newFavoriteVendors.removeRange(10, newFavoriteVendors.length);
      }
    }

    return UserInterests(
      userId: userId,
      preferredKeywords: topKeywords.take(10).map((e) => e.key).toList(),
      preferredCategories: topCategories.take(5).map((e) => e.key).toList(),
      preferredContentType: preferredContentType, // Could be updated based on patterns
      keywordInteractions: newKeywordInteractions,
      categoryInteractions: newCategoryInteractions,
      keywordRelevanceScores: newKeywordRelevanceScores,
      categoryRelevanceScores: newCategoryRelevanceScores,
      totalPositiveFeedback: newTotalPositive,
      totalNegativeFeedback: newTotalNegative,
      totalInteractions: newTotalInteractions,
      engagementRate: newEngagementRate,
      satisfactionScore: newSatisfactionScore,
      recentSearchTerms: newRecentSearchTerms,
      favoriteVendors: newFavoriteVendors,
      lastUpdated: now,
      createdAt: createdAt,
    );
  }

  /// Get personalization context for RAG prompts
  Map<String, dynamic> toPersonalizationContext() {
    return {
      'preferredKeywords': preferredKeywords,
      'preferredCategories': preferredCategories,
      'preferredContentType': preferredContentType,
      'totalPositiveFeedback': totalPositiveFeedback,
      'engagementRate': engagementRate,
      'satisfactionScore': satisfactionScore,
      'recentSearchTerms': recentSearchTerms.take(5).toList(),
      'favoriteVendors': favoriteVendors.take(3).toList(),
      'topKeywordScores': keywordRelevanceScores.entries
        .where((e) => preferredKeywords.contains(e.key))
        .fold<Map<String, double>>({}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        }),
      'topCategoryScores': categoryRelevanceScores.entries
        .where((e) => preferredCategories.contains(e.key))
        .fold<Map<String, double>>({}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        }),
    };
  }

  /// Check if user has sufficient data for personalization
  bool get hasSignificantData => totalInteractions >= 5 && preferredKeywords.isNotEmpty;

  /// Get confidence score for personalization (0.0 to 1.0)
  double get personalizationConfidence {
    if (!hasSignificantData) return 0.0;
    
    // Base confidence on interaction count and satisfaction
    final interactionScore = (totalInteractions / 50.0).clamp(0.0, 1.0); // Max at 50 interactions
    final satisfactionWeight = satisfactionScore;
    final engagementWeight = engagementRate;
    
    return (interactionScore * 0.4 + satisfactionWeight * 0.4 + engagementWeight * 0.2).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'UserInterests(userId: $userId, keywords: ${preferredKeywords.length}, '
           'categories: ${preferredCategories.length}, contentType: $preferredContentType, '
           'interactions: $totalInteractions, satisfaction: ${satisfactionScore.toStringAsFixed(2)})';
  }
} 