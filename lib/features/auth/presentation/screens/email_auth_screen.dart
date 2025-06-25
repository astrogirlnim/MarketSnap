import 'package:flutter/material.dart';
import '../../application/auth_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

/// Email Authentication Screen - Updated with MarketSnap design system
/// Allows users to sign in with email magic links
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      debugPrint('[EmailAuthScreen] Sending magic link to: ${_emailController.text.trim()}');
      
      await _authService.sendEmailSignInLinkSimple(_emailController.text.trim());
      
      setState(() {
        _emailSent = true;
        _isLoading = false;
        _successMessage = 'Magic link sent successfully!';
      });
      
      debugPrint('[EmailAuthScreen] Magic link sent successfully');
    } catch (error) {
      debugPrint('[EmailAuthScreen] Error sending magic link: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send magic link. Please check your email and try again.';
      });
    }
  }

  Future<void> _resendMagicLink() async {
    setState(() {
      _emailSent = false;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: MarketSnapAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.soilCharcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSpacing.edgeInsetsScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Header
                Text(
                  _emailSent ? 'Check your email' : 'Enter your email',
                  style: AppTypography.display.copyWith(
                    color: AppColors.soilCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  _emailSent
                      ? 'We sent a magic link to your email. Click the link to sign in instantly.'
                      : 'We\'ll send you a magic link for instant sign-in',
                  style: AppTypography.brandSubtitle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxl),

                if (!_emailSent) ...[
                  // Email input field
                  MarketSnapTextField(
                    controller: _emailController,
                    hintText: 'your@email.com',
                    labelText: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    errorText: _errorMessage,
                    onSubmitted: (_) {
                      if (!_isLoading) {
                        _sendMagicLink();
                      }
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Send button
                  MarketSnapPrimaryButton(
                    text: 'Send Magic Link',
                    isLoading: _isLoading,
                    onPressed: _sendMagicLink,
                  ),
                ] else ...[
                  // Email sent success state
                  MarketSnapCard(
                    backgroundColor: AppColors.leafGreen.withValues(alpha: 0.1),
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: AppColors.leafGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 40,
                            color: AppColors.leafGreen,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        Text(
                          'Magic link sent!',
                          style: AppTypography.h2.copyWith(
                            color: AppColors.leafGreen,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: AppTypography.body.copyWith(
                              color: AppColors.soilTaupe,
                            ),
                            children: [
                              const TextSpan(text: 'We sent a magic link to '),
                              TextSpan(
                                text: _emailController.text.trim(),
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.soilCharcoal,
                                ),
                              ),
                              const TextSpan(
                                text: '. Click the link to sign in instantly.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Resend button
                  MarketSnapSecondaryButton(
                    text: 'Send to a different email',
                    onPressed: _resendMagicLink,
                  ),
                ],

                // Success message
                if (_successMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  MarketSnapStatusMessage(
                    message: _successMessage!,
                    type: StatusType.success,
                  ),
                ],

                // Error message
                if (_errorMessage != null && !_emailSent) ...[
                  const SizedBox(height: AppSpacing.md),
                  MarketSnapStatusMessage(
                    message: _errorMessage!,
                    type: StatusType.error,
                  ),
                ],

                const SizedBox(height: AppSpacing.xxxl),

                // Help text
                MarketSnapCard(
                  backgroundColor: AppColors.marketBlue.withValues(alpha: 0.05),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.security_outlined,
                        color: AppColors.marketBlue,
                        size: AppSpacing.iconLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _emailSent
                            ? 'Magic Link Security'
                            : 'Secure Authentication',
                        style: AppTypography.h2.copyWith(
                          fontSize: 18,
                          color: AppColors.marketBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _emailSent
                            ? 'The magic link will expire in 1 hour for security. If you don\'t see the email, check your spam folder.'
                            : 'Magic links are secure and expire after 1 hour. We\'ll never spam you or share your email.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
