import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../application/auth_service.dart';

/// OTP verification screen for entering SMS verification code
/// Handles OTP input, verification, and resend functionality
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

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String _currentVerificationId = '';

  // Countdown timer for resend functionality
  Timer? _timer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendTimer();

    // Auto-focus on first OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Starts the countdown timer for resend functionality
  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  /// Gets the complete OTP from all input fields
  String _getCompleteOTP() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  /// Checks if OTP is complete (all 6 digits entered)
  bool _isOTPComplete() {
    return _getCompleteOTP().length == 6;
  }

  /// Handles OTP input and auto-advances to next field
  void _onOTPChanged(String value, int index) {
    // Clear any previous errors when user starts typing
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    // Auto-advance to next field
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all digits are entered
    if (_isOTPComplete() && !_isLoading) {
      _verifyOTP();
    }
  }

  /// Handles backspace key press for better UX
  void _onOTPKeyDown(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_otpControllers[index].text.isEmpty && index > 0) {
        // Move to previous field if current is empty
        _otpFocusNodes[index - 1].requestFocus();
        _otpControllers[index - 1].clear();
      }
    }
  }

  /// Verifies the entered OTP code
  Future<void> _verifyOTP() async {
    final otp = _getCompleteOTP();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('[OTPVerificationScreen] Verifying OTP: $otp');

    try {
      await _authService.verifyOTPAndSignIn(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );

      debugPrint('[OTPVerificationScreen] OTP verification successful');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to main app (auth state listener will handle routing)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[OTPVerificationScreen] OTP verification failed: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });

        // Clear OTP fields on error
        _clearOTPFields();
      }
    }
  }

  /// Clears all OTP input fields
  void _clearOTPFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  /// Resends the OTP code
  Future<void> _resendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    debugPrint(
      '[OTPVerificationScreen] Resending OTP to: ${widget.phoneNumber}',
    );

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (String verificationId, int? resendToken) {
          debugPrint(
            '[OTPVerificationScreen] OTP resent, new verification ID: $verificationId',
          );

          setState(() {
            _currentVerificationId = verificationId;
            _isResending = false;
          });

          // Clear previous OTP and restart timer
          _clearOTPFields();
          _startResendTimer();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onVerificationFailed: (String error) {
          debugPrint('[OTPVerificationScreen] Resend failed: $error');

          setState(() {
            _isResending = false;
            _errorMessage = error;
          });
        },
      );
    } catch (e) {
      debugPrint('[OTPVerificationScreen] Error resending OTP: $e');

      setState(() {
        _isResending = false;
        _errorMessage = 'Failed to resend code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Header
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),

              const SizedBox(height: 16),

              RichText(
                text: TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 56,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) => _onOTPKeyDown(event, index),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        enabled: !_isLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.deepPurple.shade600,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        onChanged: (value) => _onOTPChanged(value, index),
                      ),
                    ),
                  );
                }),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_isOTPComplete())
                      ? null
                      : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Verify Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Resend code section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive the code? ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_canResend)
                    TextButton(
                      onPressed: _isResending ? null : _resendOTP,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Resend',
                              style: TextStyle(
                                color: Colors.deepPurple.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )
                  else
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your messages for the 6-digit verification code. It may take a few moments to arrive.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade800,
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
    );
  }
}
