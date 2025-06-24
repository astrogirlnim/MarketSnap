import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// TTL Badge widget that shows time remaining until expiry
/// Changes color based on urgency level
class TTLBadge extends StatelessWidget {
  final Duration timeRemaining;
  final bool isSmall;

  const TTLBadge({
    super.key,
    required this.timeRemaining,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTimeRemaining();
    final color = _getBadgeColor();
    final size = isSmall ? AppSpacing.ttlBadgeSize * 0.8 : AppSpacing.ttlBadgeSize;
    final textStyle = isSmall 
        ? AppTypography.ttlBadge.copyWith(fontSize: 8)
        : AppTypography.ttlBadge;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          timeString,
          style: textStyle.copyWith(
            color: _getTextColor(color),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Format time remaining as string
  String _formatTimeRemaining() {
    if (timeRemaining.inHours > 0) {
      return '${timeRemaining.inHours}h';
    } else if (timeRemaining.inMinutes > 0) {
      return '${timeRemaining.inMinutes}m';
    } else if (timeRemaining.inSeconds > 0) {
      return '${timeRemaining.inSeconds}s';
    } else {
      return '0s';
    }
  }

  /// Get badge color based on time remaining
  Color _getBadgeColor() {
    if (timeRemaining.inHours <= 1) {
      return AppColors.ttlUrgent; // Red - less than 1 hour
    } else if (timeRemaining.inHours <= 6) {
      return AppColors.ttlWarning; // Amber - less than 6 hours
    } else {
      return AppColors.ttlNormal; // Green - more than 6 hours
    }
  }

  /// Get appropriate text color for the background
  Color _getTextColor(Color backgroundColor) {
    // Use white text for all TTL badges for better contrast
    return AppColors.white;
  }
}

/// Linear TTL indicator for story progress
class TTLProgressIndicator extends StatelessWidget {
  final Duration timeRemaining;
  final Duration totalDuration;
  final double width;

  const TTLProgressIndicator({
    super.key,
    required this.timeRemaining,
    required this.totalDuration,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (timeRemaining.inMilliseconds / totalDuration.inMilliseconds);
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    return Container(
      width: width,
      height: AppSpacing.storyProgressHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.storyProgressHeight / 2),
        color: AppColors.soilTaupe.withValues(alpha: 0.3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clampedProgress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.storyProgressHeight / 2),
            color: _getProgressColor(),
          ),
        ),
      ),
    );
  }

  /// Get progress color based on time remaining
  Color _getProgressColor() {
    if (timeRemaining.inHours <= 1) {
      return AppColors.ttlUrgent;
    } else if (timeRemaining.inHours <= 6) {
      return AppColors.ttlWarning;
    } else {
      return AppColors.ttlNormal;
    }
  }
}

/// TTL Badge with animated pulsing effect for urgent items
class AnimatedTTLBadge extends StatefulWidget {
  final Duration timeRemaining;
  final bool isSmall;

  const AnimatedTTLBadge({
    super.key,
    required this.timeRemaining,
    this.isSmall = false,
  });

  @override
  State<AnimatedTTLBadge> createState() => _AnimatedTTLBadgeState();
}

class _AnimatedTTLBadgeState extends State<AnimatedTTLBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Only animate if urgent (less than 1 hour)
    if (widget.timeRemaining.inHours <= 1) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedTTLBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation based on time remaining
    if (widget.timeRemaining.inHours <= 1 && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (widget.timeRemaining.inHours > 1 && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: TTLBadge(
            timeRemaining: widget.timeRemaining,
            isSmall: widget.isSmall,
          ),
        );
      },
    );
  }
}