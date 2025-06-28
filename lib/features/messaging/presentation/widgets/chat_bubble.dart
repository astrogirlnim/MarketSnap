import 'package:flutter/material.dart';
import 'package:marketsnap/core/models/message.dart';
import 'package:marketsnap/shared/presentation/theme/app_colors.dart';
import 'package:marketsnap/shared/presentation/theme/app_spacing.dart';
import 'package:marketsnap/shared/presentation/theme/app_typography.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Debug logging
    debugPrint(
      '[ChatBubble] Building bubble: isMe=$isMe, text="${message.text}"',
    );

    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = isMe ? AppColors.marketBlue : AppColors.surface;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topLeft: Radius.circular(16),
          );

    return Container(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.sm,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.7, // Limit bubble width
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message text
            Text(
              message.text,
              style: AppTypography.body.copyWith(color: textColor),
            ),
            
            const SizedBox(height: AppSpacing.xs),
            
            // Timestamp and ephemeral indicator row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ephemeral indicator icon
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: isMe 
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                
                // Timestamp
                Text(
                  _formatTimestamp(message.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: isMe 
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                
                const SizedBox(width: 6),
                
                // Ephemeral indicator text - time remaining
                Text(
                  _getExpiryText(message.expiresAt),
                  style: AppTypography.caption.copyWith(
                    color: isMe 
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.sunsetAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp for display in chat bubbles
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  /// Get expiry text for message based on expiration time
  String _getExpiryText(DateTime expiresAt) {
    final now = DateTime.now();
    final timeRemaining = expiresAt.difference(now);
    
    if (timeRemaining.isNegative) {
      return 'Expired';
    }
    
    if (timeRemaining.inHours >= 1) {
      return '${timeRemaining.inHours}h';
    } else if (timeRemaining.inMinutes >= 1) {
      return '${timeRemaining.inMinutes}m';
    } else {
      return '<1m';
    }
  }
}
