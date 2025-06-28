import 'package:flutter_test/flutter_test.dart';
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
      
      print('✅ UserInterests empty creation test passed');
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
      
      print('✅ UserInterests positive feedback update test passed');
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
      
      print('✅ UserInterests negative feedback update test passed');
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
      
      print('✅ Personalization confidence calculation test passed');
      print('   Confidence: ${interests.personalizationConfidence.toStringAsFixed(2)}');
      print('   Satisfaction: ${interests.satisfactionScore.toStringAsFixed(2)}');
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
      
      print('✅ Personalization context generation test passed');
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
      
      print('✅ Keyword limits maintained: ${interests.preferredKeywords.length} keywords');
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
      
      print('✅ Category limits maintained: ${interests.preferredCategories.length} categories');
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
      
      print('✅ Search terms limits maintained: ${interests.recentSearchTerms.length} terms');
    });

    test('should maintain vendor limits', () {
      var interests = UserInterests.empty(testUserId);
      
      // Add more than 10 vendors
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
      
      print('✅ Vendor limits maintained: ${interests.favoriteVendors.length} vendors');
    });

    test('should handle mixed feedback patterns correctly', () {
      var interests = UserInterests.empty(testUserId);
      
      final mixedFeedback = [
        // Strong positive pattern for tomatoes
        {'keywords': ['tomato', 'fresh'], 'category': 'vegetables', 'positive': true, 'score': 0.9},
        {'keywords': ['tomato', 'sauce'], 'category': 'condiment', 'positive': true, 'score': 0.8},
        {'keywords': ['tomato', 'salad'], 'category': 'vegetables', 'positive': true, 'score': 0.85},
        
        // Some negative feedback
        {'keywords': ['mushroom'], 'category': 'vegetables', 'positive': false, 'score': 0.2},
        {'keywords': ['brussels_sprouts'], 'category': 'vegetables', 'positive': false, 'score': 0.1},
        
        // Mixed results for fruits
        {'keywords': ['apple'], 'category': 'fruit', 'positive': true, 'score': 0.7},
        {'keywords': ['banana'], 'category': 'fruit', 'positive': false, 'score': 0.4},
        {'keywords': ['orange'], 'category': 'fruit', 'positive': true, 'score': 0.6},
      ];
      
      for (final feedback in mixedFeedback) {
        interests = interests.updateWithFeedback(
          keywords: feedback['keywords'] as List<String>,
          category: feedback['category'] as String,
          relevanceScore: feedback['score'] as double,
          isPositive: feedback['positive'] as bool,
        );
      }
      
      expect(interests.totalInteractions, equals(8));
      expect(interests.totalPositiveFeedback, equals(5));
      expect(interests.totalNegativeFeedback, equals(3));
      expect(interests.satisfactionScore, greaterThan(0.4)); // Still positive overall
      expect(interests.preferredKeywords, contains('tomato')); // Strong positive pattern
      
      print('✅ Mixed feedback patterns handled correctly');
      print('   Satisfaction: ${interests.satisfactionScore.toStringAsFixed(2)}');
      print('   Top keywords: ${interests.preferredKeywords.take(3).join(', ')}');
    });

    test('should handle performance with large datasets', () {
      final startTime = DateTime.now();
      
      var interests = UserInterests.empty(testUserId);
      
      // Simulate heavy usage
      for (int i = 0; i < 100; i++) {
        interests = interests.updateWithFeedback(
          keywords: ['keyword_$i', 'common_keyword'],
          category: 'category_${i % 10}',
          relevanceScore: 0.5 + (i % 50) / 100.0,
          isPositive: i % 3 != 0, // 2/3 positive
          vendorId: 'vendor_${i % 20}',
          searchTerm: 'search_$i',
        );
      }
      
      final processingTime = DateTime.now().difference(startTime);
      
      // Should complete within reasonable time
      expect(processingTime.inSeconds, lessThan(3));
      expect(interests.totalInteractions, equals(100));
      expect(interests.preferredKeywords.length, lessThanOrEqualTo(10));
      expect(interests.preferredCategories.length, lessThanOrEqualTo(5));
      expect(interests.recentSearchTerms.length, lessThanOrEqualTo(20));
      expect(interests.favoriteVendors.length, lessThanOrEqualTo(10));
      
      print('✅ Performance test: 100 interactions in ${processingTime.inMilliseconds}ms');
      print('   Final confidence: ${interests.personalizationConfidence.toStringAsFixed(2)}');
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
      
      // Serialize to Firestore format
      final firestoreData = interests.toFirestore();
      
      // Note: userId is not stored in Firestore data - it's the document ID
      expect(firestoreData['preferredKeywords'], isA<List>());
      expect(firestoreData['preferredCategories'], isA<List>());
      expect(firestoreData['totalInteractions'], equals(1));
      expect(firestoreData['totalPositiveFeedback'], equals(1));
      expect(firestoreData['satisfactionScore'], isA<double>());
      expect(firestoreData['recentSearchTerms'], isA<List>());
      expect(firestoreData['favoriteVendors'], isA<List>());
      expect(firestoreData['engagementRate'], isA<double>());
      expect(firestoreData['preferredContentType'], equals('balanced'));
      
      print('✅ Firestore serialization test passed');
    });
  });
} 