import 'package:flutter/material.dart';
import 'phone_auth_screen.dart';
import 'email_auth_screen.dart';

/// Welcome screen for authentication
/// Allows users to choose between phone number and email authentication
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Brand section
              const Spacer(),
              
              // App logo/icon placeholder
              Container(
                height: 120,
                width: 120,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 60,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              
              // Welcome text
              Text(
                'Welcome to MarketSnap',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Share fresh produce updates with your customers in real-time',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Authentication options
              Text(
                'Choose how you\'d like to sign in:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Phone authentication button
              _AuthOptionButton(
                icon: Icons.phone_android,
                title: 'Continue with Phone',
                subtitle: 'We\'ll send you a verification code',
                onTap: () {
                  debugPrint('[AuthWelcomeScreen] Navigating to phone authentication');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PhoneAuthScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Email authentication button
              _AuthOptionButton(
                icon: Icons.email_outlined,
                title: 'Continue with Email',
                subtitle: 'We\'ll send you a magic link',
                onTap: () {
                  debugPrint('[AuthWelcomeScreen] Navigating to email authentication');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EmailAuthScreen(),
                    ),
                  );
                },
              ),
              
              const Spacer(),
              
              // Terms and privacy
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom authentication option button widget
class _AuthOptionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AuthOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.deepPurple.shade600,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 