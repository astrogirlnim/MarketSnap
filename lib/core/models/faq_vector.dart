import 'package:cloud_firestore/cloud_firestore.dart';

/// FAQ Vector model for RAG functionality
/// Stores vendor FAQ chunks with their embeddings for semantic search
class FAQVector {
  final String id;
  final String vendorId;
  final String question;
  final String answer;
  final String chunkText; // Combined question + answer for embedding
  final List<double>? embedding; // OpenAI embedding vector (1536 dimensions)
  final List<String> keywords; // Extracted keywords for fallback search
  final String category; // Product category (produce, baked goods, etc.)
  final DateTime createdAt;
  final DateTime updatedAt;

  FAQVector({
    required this.id,
    required this.vendorId,
    required this.question,
    required this.answer,
    required this.chunkText,
    this.embedding,
    required this.keywords,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create FAQVector from Firestore document
  factory FAQVector.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FAQVector(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      chunkText: data['chunkText'] ?? '',
      embedding: data['embedding'] != null 
          ? List<double>.from(data['embedding'])
          : null,
      keywords: List<String>.from(data['keywords'] ?? []),
      category: data['category'] ?? 'general',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'question': question,
      'answer': answer,
      'chunkText': chunkText,
      'embedding': embedding,
      'keywords': keywords,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy with updated fields
  FAQVector copyWith({
    String? id,
    String? vendorId,
    String? question,
    String? answer,
    String? chunkText,
    List<double>? embedding,
    List<String>? keywords,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FAQVector(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      chunkText: chunkText ?? this.chunkText,
      embedding: embedding ?? this.embedding,
      keywords: keywords ?? this.keywords,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 