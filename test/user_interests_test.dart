import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marketsnap/core/models/user_interests.dart';

void main() {
  group('UserInterests Model Unit Tests', () {
    const testUserId = 'test_user_123';
    const testVendorId = 'test_vendor_456';

    test('should create empty UserInterests correctly', () {
      final interests = UserInterests.empty(testUserId);
      
      expect(interests.userId, equals(testUserId));
      expect(interests.preferredKeywords, isEmpty);
      expect(interests.preferredCategories, isEmpty);
      expect(interests.totalInteractions, equals(0));
      expect(interests.totalPositiveFeedback, equals(0));
      expect(interests.totalNegativeFeedback, equals(0));
      expect(interests.personalizationConfidence, equals(0.0));
      expect(interests.satisfactionScore, equals(0.0));
      expect(interests.engagementRate, equals(0.0));
      expect(interests.hasSignificantData, isFalse);
      expect(interests.recentSearchTerms, isEmpty);
      expect(interests.favoriteVendors, isEmpty);
      
      debugPrint('✅ UserInterests empty creation test passed');
    });

    test('should update interests with positive feedback correctly', () {
      final initialInterests = UserInterests.empty(testUserId);
      
      final updatedInterests = initialInterests.updateWithFeedback(
        keywords: ['tomato', 'fresh', 'organic'],
        category: 'vegetables',
        relevanceScore: 0.8,
        isPositive: true,
        vendorId: testVendorId,
        searchTerm: 'fresh tomatoes',
      );
      
      expect(updatedInterests.preferredKeywords, contains('tomato'));
      expect(updatedInterests.preferredKeywords, contains('fresh'));
      expect(updatedInterests.preferredKeywords, contains('organic'));
      expect(updatedInterests.preferredCategories, contains('vegetables'));
      expect(updatedInterests.totalPositiveFeedback, equals(1));
      expect(updatedInterests.totalNegativeFeedback, equals(0));
      expect(updatedInterests.totalInteractions, equals(1));
      expect(updatedInterests.satisfactionScore, greaterThan(0.5));
      expect(updatedInterests.recentSearchTerms, contains('fresh tomatoes'));
      expect(updatedInterests.favoriteVendors, contains(testVendorId));
      expect(updatedInterests.keywordRelevanceScores['tomato'], equals(0.8));
      expect(updatedInterests.categoryRelevanceScores['vegetables'], equals(0.8));
      
      debugPrint('✅ UserInterests positive feedback update test passed');
    });

    test('should update interests with negative feedback correctly', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add positive feedback first
      interests = interests.updateWithFeedback(
        keywords: ['apple'],
        category: 'fruit',
        relevanceScore: 0.7,
        isPositive: true,
      );
      
      // Then add negative feedback
      interests = interests.updateWithFeedback(
        keywords: ['banana'],
        category: 'fruit',
        relevanceScore: 0.3,
        isPositive: false,
      );
      
      expect(interests.totalPositiveFeedback, equals(1));
      expect(interests.totalNegativeFeedback, equals(1));
      expect(interests.totalInteractions, equals(2));
      expect(interests.satisfactionScore, lessThan(0.7));
      expect(interests.engagementRate, equals(1.0)); // 2/2 interactions
      
      debugPrint('✅ UserInterests negative feedback update test passed');
    });

    test('should calculate personalization confidence correctly', () {
      var interests = UserInterests.empty(testUserId);
      
      final keywords = ['tomato', 'carrot', 'onion', 'garlic', 'basil'];
      final categories = ['vegetables', 'herbs'];
      
      // Add multiple interactions
      for (int i = 0; i < 15; i++) {
        interests = interests.updateWithFeedback(
          keywords: [keywords[i % keywords.length]],
          category: categories[i % categories.length],
          relevanceScore: 0.7 + (i * 0.01), // Gradually increasing relevance
          isPositive: i < 12, // 12 positive, 3 negative
        );
      }
      
      expect(interests.totalInteractions, equals(15));
      expect(interests.totalPositiveFeedback, equals(12));
      expect(interests.totalNegativeFeedback, equals(3));
      expect(interests.personalizationConfidence, greaterThan(0.5));
      expect(interests.hasSignificantData, isTrue);
      expect(interests.satisfactionScore, greaterThan(0.6)); // Should be positive overall
      
      debugPrint('✅ Personalization confidence calculation test passed');
      debugPrint('   Confidence: ${interests.personalizationConfidence.toStringAsFixed(2)}');
      debugPrint('   Satisfaction: ${interests.satisfactionScore.toStringAsFixed(2)}');
    });

    test('should generate proper personalization context', () {
      var interests = UserInterests.empty(testUserId);
      
      // Build significant data
      for (int i = 0; i < 20; i++) {
        interests = interests.updateWithFeedback(
          keywords: ['tomato', 'fresh', 'organic'],
          category: 'vegetables',
          relevanceScore: 0.8,
          isPositive: true,
          vendorId: 'vendor_$i',
          searchTerm: 'search_$i',
        );
      }
      
      final context = interests.toPersonalizationContext();
      
      expect(context['preferredKeywords'], isNotEmpty);
      expect(context['preferredCategories'], isNotEmpty);
      expect(context['topKeywordScores'], isA<Map>());
      expect(context['topCategoryScores'], isA<Map>());
      expect(context['recentSearchTerms'], isNotEmpty);
      expect(context['favoriteVendors'], isNotEmpty);
      expect(context['satisfactionScore'], isA<double>());
      expect(context['engagementRate'], isA<double>());
      expect(context['preferredContentType'], equals('balanced'));
      
      debugPrint('✅ Personalization context generation test passed');
    });

    test('should maintain keyword limits', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add more than 10 different keywords
      final keywordsList = ['apple', 'banana', 'carrot', 'date', 'eggplant', 
                           'fig', 'grape', 'honey', 'ice', 'jam', 'kiwi', 'lemon'];
      
      for (final keyword in keywordsList) {
        interests = interests.updateWithFeedback(
          keywords: [keyword],
          category: 'fruit',
          relevanceScore: 0.7,
          isPositive: true,
        );
      }
      
      // Should be limited to 10 keywords
      expect(interests.preferredKeywords.length, lessThanOrEqualTo(10));
      
      debugPrint('✅ Keyword limits maintained: ${interests.preferredKeywords.length} keywords');
    });

    test('should maintain category limits', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add more than 5 different categories
      final categories = ['vegetables', 'fruits', 'herbs', 'spices', 'grains', 'dairy', 'meat'];
      
      for (final category in categories) {
        interests = interests.updateWithFeedback(
          keywords: ['test'],
          category: category,
          relevanceScore: 0.7,
          isPositive: true,
        );
      }
      
      // Should be limited to 5 categories
      expect(interests.preferredCategories.length, lessThanOrEqualTo(5));
      
      debugPrint('✅ Category limits maintained: ${interests.preferredCategories.length} categories');
    });

    test('should maintain search terms limits', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add more than 20 search terms
      for (int i = 0; i < 25; i++) {
        interests = interests.updateWithFeedback(
          keywords: ['test'],
          category: 'test',
          relevanceScore: 0.7,
          isPositive: true,
          searchTerm: 'search_term_$i',
        );
      }
      
      // Should be limited to 20 search terms
      expect(interests.recentSearchTerms.length, lessThanOrEqualTo(20));
      
      debugPrint('✅ Search terms limits maintained: ${interests.recentSearchTerms.length} terms');
    });

    test('should maintain vendor limits', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add more than 10 different vendors
      for (int i = 0; i < 15; i++) {
        interests = interests.updateWithFeedback(
          keywords: ['test'],
          category: 'test',
          relevanceScore: 0.7,
          isPositive: true,
          vendorId: 'vendor_$i',
        );
      }
      
      // Should be limited to 10 vendors
      expect(interests.favoriteVendors.length, lessThanOrEqualTo(10));
      
      debugPrint('✅ Vendor limits maintained: ${interests.favoriteVendors.length} vendors');
    });

    test('should handle mixed feedback patterns correctly', () {
      var interests = UserInterests.empty(testUserId);
      
      // Simulate realistic user behavior with mixed feedback
      final interactions = [
        {'keywords': ['tomato', 'fresh'], 'category': 'vegetables', 'positive': true, 'score': 0.9},
        {'keywords': ['old', 'spoiled'], 'category': 'vegetables', 'positive': false, 'score': 0.2},
        {'keywords': ['tomato', 'sauce'], 'category': 'processed', 'positive': true, 'score': 0.7},
        {'keywords': ['tomato', 'ripe'], 'category': 'vegetables', 'positive': true, 'score': 0.8},
        {'keywords': ['wilted', 'bad'], 'category': 'vegetables', 'positive': false, 'score': 0.1},
        {'keywords': ['fresh', 'organic'], 'category': 'vegetables', 'positive': true, 'score': 0.95},
        {'keywords': ['expensive', 'overpriced'], 'category': 'vegetables', 'positive': false, 'score': 0.3},
        {'keywords': ['fresh', 'local'], 'category': 'vegetables', 'positive': true, 'score': 0.85},
      ];
      
      for (final interaction in interactions) {
        interests = interests.updateWithFeedback(
          keywords: interaction['keywords'] as List<String>,
          category: interaction['category'] as String,
          relevanceScore: interaction['score'] as double,
          isPositive: interaction['positive'] as bool,
        );
      }
      
      expect(interests.totalInteractions, equals(8));
      expect(interests.totalPositiveFeedback, equals(5));
      expect(interests.totalNegativeFeedback, equals(3));
      expect(interests.satisfactionScore, greaterThan(0.5));
      expect(interests.preferredKeywords, contains('tomato'));
      expect(interests.preferredKeywords, contains('fresh'));
      
      debugPrint('✅ Mixed feedback patterns handled correctly');
      debugPrint('   Satisfaction: ${interests.satisfactionScore.toStringAsFixed(2)}');
      debugPrint('   Top keywords: ${interests.preferredKeywords.take(3).join(', ')}');
    });

    test('should handle performance with large datasets', () {
      var interests = UserInterests.empty(testUserId);
      
      final stopwatch = Stopwatch()..start();
      
      // Simulate 100 interactions
      for (int i = 0; i < 100; i++) {
        interests = interests.updateWithFeedback(
          keywords: ['keyword_${i % 20}', 'common_${i % 5}'],
          category: 'category_${i % 8}',
          relevanceScore: 0.5 + (i % 50) / 100, // Varying scores 0.5-1.0
          isPositive: i % 3 != 0, // ~67% positive feedback
          vendorId: 'vendor_${i % 15}',
          searchTerm: 'search_${i % 30}',
        );
      }
      
      stopwatch.stop();
      final processingTime = stopwatch.elapsed;
      
      expect(interests.totalInteractions, equals(100));
      expect(interests.hasSignificantData, isTrue);
      expect(interests.personalizationConfidence, greaterThan(0.8));
      
      debugPrint('✅ Performance test: 100 interactions in ${processingTime.inMilliseconds}ms');
      debugPrint('   Final confidence: ${interests.personalizationConfidence.toStringAsFixed(2)}');
    });

    test('should serialize to Firestore format correctly', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add some data
      interests = interests.updateWithFeedback(
        keywords: ['tomato', 'fresh'],
        category: 'vegetables',
        relevanceScore: 0.8,
        isPositive: true,
        vendorId: testVendorId,
        searchTerm: 'fresh tomatoes',
      );
      
      final firestoreData = interests.toFirestore();
      
      expect(firestoreData['userId'], equals(testUserId));
      expect(firestoreData['preferredKeywords'], isA<List>());
      expect(firestoreData['preferredCategories'], isA<List>());
      expect(firestoreData['totalInteractions'], isA<int>());
      expect(firestoreData['totalPositiveFeedback'], isA<int>());
      expect(firestoreData['totalNegativeFeedback'], isA<int>());
      expect(firestoreData['personalizationConfidence'], isA<double>());
      expect(firestoreData['satisfactionScore'], isA<double>());
      expect(firestoreData['engagementRate'], isA<double>());
      expect(firestoreData['lastUpdated'], isA<Timestamp>());
      expect(firestoreData['keywordRelevanceScores'], isA<Map>());
      expect(firestoreData['categoryRelevanceScores'], isA<Map>());
      expect(firestoreData['recentSearchTerms'], isA<List>());
      expect(firestoreData['favoriteVendors'], isA<List>());
      
      debugPrint('✅ Firestore serialization test passed');
    });
  });
} 