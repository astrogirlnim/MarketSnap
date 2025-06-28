import 'package:cloud_firestore/cloud_firestore.dart';

/// Feedback actions that users can take on RAG suggestions
enum RAGFeedbackAction { upvote, downvote, skip, edit, view, expand }

/// Type of RAG content being rated
enum RAGContentType { recipe, faq }

/// User feedback on RAG suggestions for analytics and personalization
/// Stores user interactions with recipe and FAQ suggestions to improve future recommendations
class RAGFeedback {
  final String id;
  final String userId;
  final String snapId;
  final String vendorId;
  final RAGContentType contentType;
  final RAGFeedbackAction action;
  final String contentId; // Recipe hash or FAQ ID
  final String? contentTitle; // Recipe name or FAQ question
  final double? relevanceScore; // Original AI relevance score
  final String? userComment; // Optional user comment for edit actions
  final Map<String, dynamic>?
  metadata; // Additional context (keywords, category, etc.)
  final DateTime createdAt;

  RAGFeedback({
    required this.id,
    required this.userId,
    required this.snapId,
    required this.vendorId,
    required this.contentType,
    required this.action,
    required this.contentId,
    this.contentTitle,
    this.relevanceScore,
    this.userComment,
    this.metadata,
    required this.createdAt,
  });

  /// Create feedback for recipe interaction
  factory RAGFeedback.recipe({
    required String userId,
    required String snapId,
    required String vendorId,
    required RAGFeedbackAction action,
    required String recipeHash,
    required String recipeName,
    required double relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
  }) {
    return RAGFeedback(
      id: '', // Will be set by Firestore
      userId: userId,
      snapId: snapId,
      vendorId: vendorId,
      contentType: RAGContentType.recipe,
      action: action,
      contentId: recipeHash,
      contentTitle: recipeName,
      relevanceScore: relevanceScore,
      userComment: userComment,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// Create feedback for FAQ interaction
  factory RAGFeedback.faq({
    required String userId,
    required String snapId,
    required String vendorId,
    required RAGFeedbackAction action,
    required String faqId,
    required String faqQuestion,
    required double relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
  }) {
    return RAGFeedback(
      id: '', // Will be set by Firestore
      userId: userId,
      snapId: snapId,
      vendorId: vendorId,
      contentType: RAGContentType.faq,
      action: action,
      contentId: faqId,
      contentTitle: faqQuestion,
      relevanceScore: relevanceScore,
      userComment: userComment,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// Create RAGFeedback from Firestore document
  factory RAGFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RAGFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      snapId: data['snapId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      contentType: RAGContentType.values.firstWhere(
        (type) => type.toString().split('.').last == data['contentType'],
        orElse: () => RAGContentType.recipe,
      ),
      action: RAGFeedbackAction.values.firstWhere(
        (action) => action.toString().split('.').last == data['action'],
        orElse: () => RAGFeedbackAction.view,
      ),
      contentId: data['contentId'] ?? '',
      contentTitle: data['contentTitle'],
      relevanceScore: data['relevanceScore']?.toDouble(),
      userComment: data['userComment'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'snapId': snapId,
      'vendorId': vendorId,
      'contentType': contentType.toString().split('.').last,
      'action': action.toString().split('.').last,
      'contentId': contentId,
      'contentTitle': contentTitle,
      'relevanceScore': relevanceScore,
      'userComment': userComment,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Copy with updated fields
  RAGFeedback copyWith({
    String? id,
    String? userId,
    String? snapId,
    String? vendorId,
    RAGContentType? contentType,
    RAGFeedbackAction? action,
    String? contentId,
    String? contentTitle,
    double? relevanceScore,
    String? userComment,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return RAGFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      snapId: snapId ?? this.snapId,
      vendorId: vendorId ?? this.vendorId,
      contentType: contentType ?? this.contentType,
      action: action ?? this.action,
      contentId: contentId ?? this.contentId,
      contentTitle: contentTitle ?? this.contentTitle,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      userComment: userComment ?? this.userComment,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if this feedback is positive (upvote, expand, edit)
  bool get isPositive => [
    RAGFeedbackAction.upvote,
    RAGFeedbackAction.expand,
    RAGFeedbackAction.edit,
  ].contains(action);

  /// Check if this feedback is negative (downvote, skip)
  bool get isNegative =>
      [RAGFeedbackAction.downvote, RAGFeedbackAction.skip].contains(action);

  /// Check if this feedback is engagement (view, expand)
  bool get isEngagement =>
      [RAGFeedbackAction.view, RAGFeedbackAction.expand].contains(action);
}
