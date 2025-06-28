import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConversationListItem extends StatelessWidget {
  final VendorProfile otherParticipant;
  final Message lastMessage;
  final VoidCallback onTap;
  final bool isUnread;
  final String currentUserId;

  const ConversationListItem({
    super.key,
    required this.otherParticipant,
    required this.lastMessage,
    required this.onTap,
    required this.currentUserId,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool sentByMe = lastMessage.fromUid == currentUserId;

    final String messagePreview = sentByMe
        ? 'You: ${lastMessage.text}'
        : lastMessage.text;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: otherParticipant.avatarURL?.isNotEmpty == true
            ? NetworkImage(otherParticipant.avatarURL!)
            : null,
        backgroundColor: AppColors.marketBlue,
        child: otherParticipant.avatarURL?.isEmpty != false
            ? Text(
                otherParticipant.displayName.isNotEmpty
                    ? otherParticipant.displayName[0].toUpperCase()
                    : '?',
                style: AppTypography.bodyLG.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherParticipant.displayName,
              style: AppTypography.bodyLG.copyWith(
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                color: isUnread ? AppColors.textPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.marketBlue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            otherParticipant.marketCity,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            messagePreview,
            style: AppTypography.body.copyWith(
              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
              color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
              fontStyle: sentByMe ? FontStyle.normal : FontStyle.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(lastMessage.createdAt),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 10,
                color: AppColors.sunsetAmber,
              ),
              const SizedBox(width: 2),
              Text(
                _getExpiryText(lastMessage.expiresAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.sunsetAmber,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  /// Get expiry text for conversation based on last message expiration
  String _getExpiryText(DateTime expiresAt) {
    final now = DateTime.now();
    final timeRemaining = expiresAt.difference(now);
    
    if (timeRemaining.isNegative) {
      return 'Expired';
    }
    
    if (timeRemaining.inHours >= 1) {
      return '${timeRemaining.inHours}h left';
    } else if (timeRemaining.inMinutes >= 1) {
      return '${timeRemaining.inMinutes}m left';
    } else {
      return '<1m left';
    }
  }
}
