import 'package:flutter/material.dart';
import '../../application/auth_service.dart';
import 'otp_verification_screen.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

/// Phone Authentication Screen - Updated with MarketSnap design system
/// Handles phone number input and SMS verification
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phoneNumber = _phoneController.text.trim();

    // Clear any previous error messages
    setState(() {
      _errorMessage = null;
    });

    // Validate phone number
    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    if (!_authService.isValidPhoneNumber(phoneNumber)) {
      setState(() {
        _errorMessage =
            'Please enter a valid phone number with country code (e.g., +1 555 123 4567)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    debugPrint('[PhoneAuthScreen] Sending OTP to: $phoneNumber');

    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          debugPrint('[PhoneAuthScreen] Auto verification completed');
          // Auto-verification (usually on Android)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                verificationId: '', // Not needed for auto-verification
              ),
            ),
          );
        },
        verificationFailed: (error) {
          debugPrint('[PhoneAuthScreen] Verification failed: $error');
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });
        },
        codeSent: (verificationId, resendToken) {
          debugPrint(
            '[PhoneAuthScreen] Code sent with verification ID: $verificationId',
          );
          setState(() {
            _isLoading = false;
          });
          // Navigate to OTP screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          debugPrint(
            '[PhoneAuthScreen] Auto retrieval timeout for: $verificationId',
          );
        },
      );
    } catch (e) {
      debugPrint('[PhoneAuthScreen] Error sending OTP: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
    }
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
                  'Enter your phone number',
                  style: AppTypography.display.copyWith(
                    color: AppColors.soilCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'We\'ll send you a verification code to confirm your number',
                  style: AppTypography.brandSubtitle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Phone number input field
                MarketSnapTextField(
                  controller: _phoneController,
                  hintText: '+1 (555) 123-4567',
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  errorText: _errorMessage,
                  enabled: !_isLoading,
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _sendOTP();
                    }
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Send OTP button
                MarketSnapPrimaryButton(
                  text: 'Send Verification Code',
                  isLoading: _isLoading,
                  onPressed: _sendOTP,
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Help text about phone verification
                MarketSnapCard(
                  backgroundColor: AppColors.marketBlue.withValues(alpha: 0.05),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.message_outlined,
                        color: AppColors.marketBlue,
                        size: AppSpacing.iconLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'SMS Verification',
                        style: AppTypography.h2.copyWith(
                          fontSize: 18,
                          color: AppColors.marketBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'We\'ll send a 6-digit verification code to your phone. Message and data rates may apply.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Privacy notice
                MarketSnapCard(
                  backgroundColor: AppColors.leafGreen.withValues(alpha: 0.05),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.leafGreen,
                        size: AppSpacing.iconLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your Privacy Matters',
                        style: AppTypography.h2.copyWith(
                          fontSize: 18,
                          color: AppColors.leafGreen,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'We use your phone number only for authentication and will never share it with third parties.',
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
