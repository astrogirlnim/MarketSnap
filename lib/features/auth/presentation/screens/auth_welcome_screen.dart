import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'phone_auth_screen.dart';
import 'email_auth_screen.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../shared/presentation/widgets/version_display_widget.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../main.dart' as main;

/// MarketSnap Welcome Screen - Redesigned to match login_page.png reference
/// Features the basket character icon and farmers-market aesthetic
/// Enhanced with offline authentication support
class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    // Monitor connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != isOffline) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[AuthWelcomeScreen] Building MarketSnap welcome screen (offline: $_isOffline)',
    );

    // Check if phone auth should be disabled on iOS emulator
    final bool isIOSEmulator = Platform.isIOS && kDebugMode;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: screenHeight - MediaQuery.of(context).padding.top,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: AppSpacing.edgeInsetsScreen,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spacer to push content down less (more compact)
                  const Spacer(flex: 2),

                  // Offline status indicator
                  if (_isOffline) ...[
                    MarketSnapStatusMessage(
                      message:
                          'You\'re offline - Sign in to access your account once connected',
                      type: StatusType.warning,
                      showIcon: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Wicker Mascot - Bigger and more prominent with welcome blink animation
                  const Center(
                    child: BasketIcon(
                      size: 240,
                      enableWelcomeAnimation: true,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Main CTA Button - "Sign Up"
                  MarketSnapPrimaryButton(
                    text: 'Sign Up',
                    icon: Icons.storefront_outlined,
                    onPressed: () {
                      debugPrint(
                        '[AuthWelcomeScreen] Sign Up tapped',
                      );
                      _navigateToAuth(context, isIOSEmulator, true);
                    },
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle for vendors
                  Text(
                    'Start sharing your fresh finds',
                    style: AppTypography.brandSubtitle,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Secondary Action - "Log In"
                  MarketSnapSecondaryButton(
                    text: 'Log In',
                    icon: Icons.login_outlined,
                    onPressed: () {
                      debugPrint('[AuthWelcomeScreen] Log In tapped');
                      _navigateToAuth(context, isIOSEmulator, false);
                    },
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle for existing users
                  Text(
                    'Already have an account?',
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // "What is MarketSnap?" link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        debugPrint(
                          '[AuthWelcomeScreen] What is MarketSnap tapped',
                        );
                        _showInfoDialog(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.marketBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'What is MarketSnap',
                            style: AppTypography.linkText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppColors.marketBlue,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // iOS emulator note (if applicable)
                  if (isIOSEmulator) ...[
                    const SizedBox(height: AppSpacing.lg),
                    MarketSnapStatusMessage(
                      message:
                          'Development Mode: Google and Email authentication work fully. Phone authentication is limited in iOS simulator.',
                      type: StatusType.info,
                      showIcon: true,
                    ),
                  ],

                  const Spacer(flex: 3),

                  // Terms and Privacy - Bottom of screen
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // App version display
                  const VersionDisplayWidget(
                    showBuildNumber: true,
                    alignment: Alignment.center,
                  ),

                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to authentication based on platform and signup/login mode
  void _navigateToAuth(
    BuildContext context,
    bool isIOSEmulator,
    bool isSignUp,
  ) {
    // Always show the authentication method dialog with all options
    // Google Auth is now properly configured for both iOS and Android
    _showAuthMethodDialog(context, isSignUp);
  }

  /// Show dialog to choose authentication method (phone or email)
  void _showAuthMethodDialog(BuildContext context, bool isSignUp) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.eggshell,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Padding(
            padding: AppSpacing.edgeInsetsCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSignUp ? 'Sign Up Method' : 'Log In Method',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Choose how you\'d like to ${isSignUp ? 'create your account' : 'sign in'}:',
                  style: AppTypography.body.copyWith(
                    color: AppColors.soilTaupe,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Phone option
                MarketSnapPrimaryButton(
                  text: 'Continue with Phone',
                  icon: Icons.phone_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneAuthScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Email option
                MarketSnapSecondaryButton(
                  text: 'Continue with Email',
                  icon: Icons.email_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailAuthScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Google option
                _GoogleSignInButton(),

                // Cancel
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilTaupe,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show information dialog about MarketSnap
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.eggshell,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Padding(
            padding: AppSpacing.edgeInsetsCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BasketIcon(size: 80),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'What is MarketSnap?',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'MarketSnap enables farmers-market vendors to share real-time "fresh-stock" photos and 5-second clips that work offline first, sync transparently when connectivity returns, and auto-expire after 24 hours—driving foot traffic before produce spoils.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.soilTaupe,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.lg),

                MarketSnapPrimaryButton(
                  text: 'Got it!',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Google Sign-In Button Widget
class _GoogleSignInButton extends StatefulWidget {
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await main.authService.signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MarketSnapPrimaryButton(
          text: 'Continue with Google',
          icon: Icons.account_circle_outlined,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleGoogleSignIn,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(color: AppColors.appleRed),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
