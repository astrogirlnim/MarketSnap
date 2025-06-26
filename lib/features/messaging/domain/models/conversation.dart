import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';

class Conversation {
  final VendorProfile otherParticipant;
  final Message lastMessage;
  final int unreadCount;

  const Conversation({
    required this.otherParticipant,
    required this.lastMessage,
    this.unreadCount = 0,
  });

  String get id => otherParticipant.uid;
}
