import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// MarketSnap Design System Components
/// Reusable widgets that implement the design system consistently

/// Primary CTA Button - Market Blue
class MarketSnapPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const MarketSnapPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: AppSpacing.preferredTouchTarget,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.marketBlue,
          foregroundColor: Colors.white,
          elevation: AppSpacing.elevationSm,
          shadowColor: AppColors.marketBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.preferredTouchTarget / 2), // More rounded
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSpacing.iconSm),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(text, style: AppTypography.buttonLarge),
                ],
              ),
      ),
    );
  }
}

/// Secondary CTA Button - Harvest Orange Outline
class MarketSnapSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const MarketSnapSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: AppSpacing.preferredTouchTarget,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.soilCharcoal,
          backgroundColor: AppColors.eggshell,
          side: const BorderSide(color: AppColors.seedBrown, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.preferredTouchTarget / 2), // More rounded
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.soilCharcoal,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppSpacing.iconSm,
                      color: AppColors.soilCharcoal,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    text,
                    style: AppTypography.bodyLG.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.soilCharcoal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// MarketSnap Input Field with consistent styling
class MarketSnapTextField extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? errorText;
  final bool enabled;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  const MarketSnapTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.errorText,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(labelText!, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: AppTypography.inputText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.inputHint,
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: AppColors.marketBlue,
                    size: AppSpacing.iconMd,
                  )
                : null,
            suffixIcon: suffixIcon != null
                ? GestureDetector(
                    onTap: onSuffixTap,
                    child: Icon(
                      suffixIcon,
                      color: AppColors.soilTaupe,
                      size: AppSpacing.iconMd,
                    ),
                  )
                : null,
            errorText: errorText,
            errorStyle: AppTypography.errorText.copyWith(fontSize: 12),
            filled: true,
            fillColor: AppColors.eggshell,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.seedBrown,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.seedBrown,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.marketBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.appleRed, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.appleRed, width: 2),
            ),
            contentPadding: AppSpacing.edgeInsetsInput,
          ),
        ),
      ],
    );
  }
}

/// MarketSnap Card with consistent styling
class MarketSnapCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const MarketSnapCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? AppSpacing.edgeInsetsCardMargin,
      child: Material(
        color: backgroundColor ?? AppColors.eggshell,
        elevation: AppSpacing.elevationSm,
        shadowColor: AppColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.seedBrown, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: padding ?? AppSpacing.edgeInsetsCard,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Status Message Widget (Success, Error, Warning, Info)
class MarketSnapStatusMessage extends StatelessWidget {
  final String message;
  final StatusType type;
  final bool showIcon;
  final VoidCallback? onDismiss;

  const MarketSnapStatusMessage({
    super.key,
    required this.message,
    required this.type,
    this.showIcon = true,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.edgeInsetsMd,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: _getBorderColor(), width: 1),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(_getIcon(), color: _getIconColor(), size: AppSpacing.iconSm),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: _getTextColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: _getIconColor(),
                size: AppSpacing.iconSm,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.leafGreen.withValues(alpha: 0.1);
      case StatusType.error:
        return AppColors.appleRed.withValues(alpha: 0.1);
      case StatusType.warning:
        return AppColors.sunsetAmber.withValues(alpha: 0.1);
      case StatusType.info:
        return AppColors.marketBlue.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.leafGreen.withValues(alpha: 0.3);
      case StatusType.error:
        return AppColors.appleRed.withValues(alpha: 0.3);
      case StatusType.warning:
        return AppColors.sunsetAmber.withValues(alpha: 0.3);
      case StatusType.info:
        return AppColors.marketBlue.withValues(alpha: 0.3);
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.leafGreen.withValues(alpha: 0.8);
      case StatusType.error:
        return AppColors.appleRed.withValues(alpha: 0.8);
      case StatusType.warning:
        return AppColors.harvestOrange.withValues(alpha: 0.8);
      case StatusType.info:
        return AppColors.marketBlue.withValues(alpha: 0.8);
    }
  }

  Color _getIconColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.leafGreen;
      case StatusType.error:
        return AppColors.appleRed;
      case StatusType.warning:
        return AppColors.harvestOrange;
      case StatusType.info:
        return AppColors.marketBlue;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case StatusType.success:
        return Icons.check_circle_outline;
      case StatusType.error:
        return Icons.error_outline;
      case StatusType.warning:
        return Icons.warning_amber_outlined;
      case StatusType.info:
        return Icons.info_outline;
    }
  }
}

enum StatusType { success, error, warning, info }

/// Loading Indicator with MarketSnap branding
class MarketSnapLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final String? message;

  const MarketSnapLoadingIndicator({
    super.key,
    this.size = 32,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.marketBlue,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Basket Icon Widget (using the wicker mascot)
class BasketIcon extends StatelessWidget {
  final double size;
  final Color? color; // For tinting if needed
  final bool enableWelcomeAnimation;

  const BasketIcon({
    super.key, 
    this.size = 48, 
    this.color,
    this.enableWelcomeAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    if (enableWelcomeAnimation) {
      return _AnimatedBasketIcon(size: size, color: color);
    }
    
    return Image.asset(
      'assets/images/icons/wicker_mascot.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color, // This will apply a color tint if provided
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.shopping_basket_outlined,
        size: size,
        color: color ?? AppColors.harvestOrange,
      ),
    );
  }
}

/// Animated version of BasketIcon that blinks once when shown
class _AnimatedBasketIcon extends StatefulWidget {
  final double size;
  final Color? color;

  const _AnimatedBasketIcon({
    required this.size,
    this.color,
  });

  @override
  State<_AnimatedBasketIcon> createState() => _AnimatedBasketIconState();
}

class _AnimatedBasketIconState extends State<_AnimatedBasketIcon> {
  bool _isBlinking = false;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _startWelcomeAnimation();
  }

  Future<void> _startWelcomeAnimation() async {
    try {
      // Start the blinking animation after a short delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted && !_hasAnimated) {
        await _performBlinkAnimation();
      }
    } catch (e) {
      debugPrint('[AnimatedBasketIcon] Error during welcome animation: $e');
    }
  }

  Future<void> _performBlinkAnimation() async {
    if (!mounted || _hasAnimated) return;
    
    setState(() {
      _hasAnimated = true;
    });

    debugPrint('[AnimatedBasketIcon] 👁️ Starting Wicker blink animation');

    // Single blink sequence: normal -> blink -> normal
    if (!mounted) return;
    
    // Switch to blinking
    setState(() {
      _isBlinking = true;
    });
    
    debugPrint('[AnimatedBasketIcon] 😉 Wicker is blinking');
    await Future.delayed(const Duration(milliseconds: 250));
    
    if (!mounted) return;
    
    // Switch back to normal
    setState(() {
      _isBlinking = false;
    });
    
    debugPrint('[AnimatedBasketIcon] 😊 Wicker blink complete');
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _isBlinking
        ? 'assets/images/icons/wicker_blinking.png'
        : 'assets/images/icons/wicker_mascot.png';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Image.asset(
        assetPath,
        key: ValueKey(assetPath),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        color: widget.color,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[AnimatedBasketIcon] ⚠️ Error loading image: $assetPath');
          return Icon(
            Icons.shopping_basket_outlined,
            size: widget.size,
            color: widget.color ?? AppColors.harvestOrange,
          );
        },
      ),
    );
  }
}

/// MarketSnap App Bar with consistent styling
class MarketSnapAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;

  const MarketSnapAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!, style: AppTypography.h2) : null,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(
        color: AppColors.soilCharcoal,
        size: AppSpacing.iconMd,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Animated Container for queue status (pulsing border)
class QueueStatusContainer extends StatefulWidget {
  final Widget child;
  final bool isQueued;
  final EdgeInsetsGeometry? padding;

  const QueueStatusContainer({
    super.key,
    required this.child,
    this.isQueued = false,
    this.padding,
  });

  @override
  State<QueueStatusContainer> createState() => _QueueStatusContainerState();
}

class _QueueStatusContainerState extends State<QueueStatusContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppSpacing.animationPulse,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.isQueued) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(QueueStatusContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isQueued && !oldWidget.isQueued) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isQueued && oldWidget.isQueued) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isQueued) {
      return Container(padding: widget.padding, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.queuedBorder.withValues(alpha: _animation.value),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: widget.child,
        );
      },
    );
  }
}
