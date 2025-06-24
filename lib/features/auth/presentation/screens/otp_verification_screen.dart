import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../application/auth_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';

/// OTP Verification Screen - Updated with MarketSnap design system
/// Handles 6-digit OTP verification for phone authentication
class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  final AuthService _authService = AuthService();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  
  // Resend functionality
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus on first OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOTPChanged(String value, int index) {
    setState(() {
      _errorMessage = null;
    });

    if (value.isNotEmpty) {
      // Move to next field if not the last field
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        // All fields filled, try verification
        _otpFocusNodes[index].unfocus();
        if (_otpCode.length == 6) {
          _verifyOTP();
        }
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field if empty
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    final otpCode = _otpCode;

    if (otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    debugPrint('[OTPVerificationScreen] Verifying OTP: $otpCode');

    try {
      await _authService.verifyOTP(
        verificationId: widget.verificationId,
        smsCode: otpCode,
      );

      debugPrint('[OTPVerificationScreen] OTP verified successfully');
      
      if (mounted) {
        // Show success and navigate back to main app
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phone verified successfully!',
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.leafGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );

        // Navigate back to auth wrapper (will redirect to main app)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[OTPVerificationScreen] OTP verification failed: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid verification code. Please try again.';
      });

      // Clear OTP fields for retry
      for (final controller in _otpControllers) {
        controller.clear();
      }
      _otpFocusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    debugPrint('[OTPVerificationScreen] Resending OTP to: ${widget.phoneNumber}');

    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (credential) {
          debugPrint('[OTPVerificationScreen] Auto verification completed on resend');
        },
        verificationFailed: (error) {
          debugPrint('[OTPVerificationScreen] Resend verification failed: $error');
          setState(() {
            _isResending = false;
            _errorMessage = 'Failed to resend code. Please try again.';
          });
        },
        codeSent: (verificationId, resendToken) {
          debugPrint('[OTPVerificationScreen] Code resent successfully');
          setState(() {
            _isResending = false;
          });
          _startResendTimer();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verification code sent!',
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
              backgroundColor: AppColors.leafGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          debugPrint('[OTPVerificationScreen] Auto retrieval timeout on resend');
        },
      );
    } catch (e) {
      debugPrint('[OTPVerificationScreen] Error resending OTP: $e');
      setState(() {
        _isResending = false;
        _errorMessage = 'Failed to resend verification code. Please try again.';
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
                  'Enter verification code',
                  style: AppTypography.display.copyWith(
                    color: AppColors.soilCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),

                // Phone number display
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.brandSubtitle,
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: AppTypography.brandSubtitle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.soilCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 55,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        enabled: !_isVerifying,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
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
                            borderSide: const BorderSide(
                              color: AppColors.appleRed,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.eggshell,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                        style: AppTypography.otpInput,
                        onChanged: (value) => _onOTPChanged(value, index),
                      ),
                    );
                  }),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  MarketSnapStatusMessage(
                    message: _errorMessage!,
                    type: StatusType.error,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Verify button
                MarketSnapPrimaryButton(
                  text: 'Verify Code',
                  isLoading: _isVerifying,
                  onPressed: _verifyOTP,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Resend section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Didn\'t receive the code? ',
                      style: AppTypography.body.copyWith(
                        color: AppColors.soilTaupe,
                      ),
                    ),
                    if (_canResend)
                      TextButton(
                        onPressed: _isResending ? null : _resendOTP,
                        child: _isResending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.marketBlue,
                                  ),
                                ),
                              )
                            : Text(
                                'Resend',
                                style: AppTypography.linkText.copyWith(
                                  decoration: TextDecoration.none,
                                ),
                              ),
                      )
                    else
                      Text(
                        'Resend in ${_resendCountdown}s',
                        style: AppTypography.body.copyWith(
                          color: AppColors.soilTaupe,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Help text
                MarketSnapCard(
                  backgroundColor: AppColors.marketBlue.withOpacity(0.05),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.message_outlined,
                        color: AppColors.marketBlue,
                        size: AppSpacing.iconLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Having Trouble?',
                        style: AppTypography.h2.copyWith(
                          fontSize: 18,
                          color: AppColors.marketBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Check your messages for the 6-digit verification code. It may take a few moments to arrive.',
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
