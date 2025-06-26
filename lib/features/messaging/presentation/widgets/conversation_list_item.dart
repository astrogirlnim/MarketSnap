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

  const ConversationListItem({
    super.key,
    required this.otherParticipant,
    required this.lastMessage,
    required this.onTap,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: otherParticipant.avatarURL?.isNotEmpty == true
            ? NetworkImage(otherParticipant.avatarURL!)
            : null,
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
        backgroundColor: AppColors.marketBlue,
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
            lastMessage.text,
            style: AppTypography.body.copyWith(
              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
              color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Text(
        timeago.format(lastMessage.createdAt),
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }
}
