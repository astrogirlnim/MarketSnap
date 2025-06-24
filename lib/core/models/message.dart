import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an ephemeral message between vendor and shopper.
/// Messages auto-expire after 24 hours via Firestore TTL.
class Message {
  /// Unique identifier for the message
  final String messageId;

  /// UID of the message sender
  final String fromUid;

  /// UID of the message recipient
  final String toUid;

  /// The message text content (max ~100 chars for good UX)
  final String text;

  /// Conversation identifier (typically "fromUid_toUid" sorted)
  final String conversationId;

  /// When the message was created
  final DateTime createdAt;

  /// When the message expires (24h from creation)
  final DateTime expiresAt;

  /// Whether the message has been read by the recipient
  final bool isRead;

  const Message({
    required this.messageId,
    required this.fromUid,
    required this.toUid,
    required this.text,
    required this.conversationId,
    required this.createdAt,
    required this.expiresAt,
    this.isRead = false,
  });

  /// Creates a new message with auto-generated fields
  factory Message.create({
    required String fromUid,
    required String toUid,
    required String text,
  }) {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));
    
    // Create conversation ID by sorting UIDs for consistency
    final participants = [fromUid, toUid]..sort();
    final conversationId = '${participants[0]}_${participants[1]}';
    
    return Message(
      messageId: '', // Will be set by Firestore
      fromUid: fromUid,
      toUid: toUid,
      text: text,
      conversationId: conversationId,
      createdAt: now,
      expiresAt: expiresAt,
      isRead: false,
    );
  }

  /// Creates a Message from Firestore document data
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Message(
      messageId: doc.id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      text: data['text'] as String,
      conversationId: data['conversationId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  /// Converts Message to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'text': text,
      'conversationId': conversationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isRead': isRead,
    };
  }

  /// Creates a copy with updated fields
  Message copyWith({
    String? messageId,
    String? fromUid,
    String? toUid,
    String? text,
    String? conversationId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isRead,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      text: text ?? this.text,
      conversationId: conversationId ?? this.conversationId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Marks the message as read
  Message markAsRead() {
    return copyWith(isRead: true);
  }

  /// Checks if the message has expired
  bool get hasExpired => DateTime.now().isAfter(expiresAt);

  /// Gets the time remaining until expiration
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  /// Checks if the message is from the given user
  bool isFromUser(String userId) => fromUid == userId;

  /// Checks if the message is to the given user
  bool isToUser(String userId) => toUid == userId;

  /// Checks if the user is a participant in this message
  bool hasParticipant(String userId) => isFromUser(userId) || isToUser(userId);

  @override
  String toString() {
    return 'Message(id: $messageId, from: $fromUid, to: $toUid, text: "${text.length > 20 ? '${text.substring(0, 20)}...' : text}", read: $isRead, expires: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Message &&
        other.messageId == messageId &&
        other.fromUid == fromUid &&
        other.toUid == toUid &&
        other.text == text &&
        other.conversationId == conversationId &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt &&
        other.isRead == isRead;
  }

  @override
  int get hashCode {
    return messageId.hashCode ^
        fromUid.hashCode ^
        toUid.hashCode ^
        text.hashCode ^
        conversationId.hashCode ^
        createdAt.hashCode ^
        expiresAt.hashCode ^
        isRead.hashCode;
  }
} 