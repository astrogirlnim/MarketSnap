import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'phone_auth_screen.dart';
import 'email_auth_screen.dart';

/// Welcome screen for authentication
/// Allows users to choose between phone and email authentication
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if phone auth should be disabled on iOS emulator
    final bool isIOSEmulator = Platform.isIOS && kDebugMode;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/title
              const Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              const Text(
                'MarketSnap',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Snap, Share, Sell',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Phone authentication button
              if (!isIOSEmulator) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    debugPrint(
                      '[AuthWelcomeScreen] Navigating to phone authentication',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneAuthScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Continue with Phone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email authentication button
              ElevatedButton.icon(
                onPressed: () {
                  debugPrint(
                    '[AuthWelcomeScreen] Navigating to email authentication',
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmailAuthScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.email),
                label: const Text('Continue with Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIOSEmulator
                      ? Colors.deepPurple
                      : Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // iOS emulator warning
              if (isIOSEmulator) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 24),
                      SizedBox(height: 8),
                      Text(
                        'Development Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Phone authentication is disabled in iOS simulator. Please use email authentication for testing.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Terms and privacy
              const Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
