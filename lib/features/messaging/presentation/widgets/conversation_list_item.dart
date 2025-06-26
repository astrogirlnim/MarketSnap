import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/vendor_profile.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConversationListItem extends StatelessWidget {
  final VendorProfile otherParticipant;
  final Message lastMessage;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.otherParticipant,
    required this.lastMessage,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !lastMessage.isRead && lastMessage.toUid == currentUserId;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.cornsilk,
        backgroundImage: otherParticipant.avatarURL != null
            ? NetworkImage(otherParticipant.avatarURL!)
            : null,
        child: otherParticipant.avatarURL == null
            ? const Icon(Icons.person, color: AppColors.soilTaupe)
            : null,
      ),
      title: Text(
        otherParticipant.displayName,
        style: AppTypography.bodyLG.copyWith(
          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
          color: isUnread ? AppColors.textPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        lastMessage.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            timeago.format(lastMessage.createdAt),
            style: AppTypography.caption.copyWith(
              color: isUnread ? AppColors.marketBlue : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (isUnread)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.marketBlue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
