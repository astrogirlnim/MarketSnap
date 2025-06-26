import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Authentication service handling Firebase Auth operations
/// Supports both phone number and email OTP authentication flows
class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Authentication state - true if user is signed in
  bool get isAuthenticated => currentUser != null;

  // ================================
  // PHONE NUMBER AUTHENTICATION
  // ================================

  /// Initiates phone number verification process
  /// Returns verification ID for OTP verification
  Future<String> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onVerificationFailed,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    debugPrint('[AuthService] Starting phone verification for: $phoneNumber');

    // iOS-specific handling to prevent crashes
    if (Platform.isIOS) {
      debugPrint(
        '[AuthService] iOS platform detected, applying iOS-specific phone auth handling',
      );

      // Check if we're running in emulator mode
      if (kDebugMode) {
        debugPrint(
          '[AuthService] Debug mode on iOS - checking emulator connectivity',
        );

        // For iOS emulator, we might need to handle phone auth differently
        try {
          // Add a small delay to ensure iOS Firebase Auth is ready
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('[AuthService] iOS preparation delay failed: $e');
        }
      }
    }

    String? verificationId;

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            '[AuthService] Phone verification completed automatically',
          );
          try {
            if (onVerificationCompleted != null) {
              onVerificationCompleted(credential);
            } else {
              // Auto-sign in if credential is complete
              await signInWithPhoneCredential(credential);
            }
          } catch (e) {
            debugPrint(
              '[AuthService] Error in verification completed callback: $e',
            );
            onVerificationFailed('Authentication failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
            '[AuthService] Phone verification failed: ${e.code} - ${e.message}',
          );
          String errorMessage = _getPhoneAuthErrorMessage(e);
          onVerificationFailed(errorMessage);
        },
        codeSent: (String verId, int? resendToken) {
          debugPrint('[AuthService] SMS code sent. Verification ID: $verId');
          verificationId = verId;
          onCodeSent(verId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verId) {
          debugPrint('[AuthService] Code auto-retrieval timeout for: $verId');
          if (onCodeAutoRetrievalTimeout != null) {
            onCodeAutoRetrievalTimeout(verId);
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('[AuthService] Phone verification exception: $e');

      // iOS-specific error handling
      if (Platform.isIOS && e.toString().contains('nil')) {
        onVerificationFailed(
          'iOS phone verification is not available in the current environment. Please try email authentication instead.',
        );
        return '';
      }

      // Handle any unexpected errors during phone verification setup
      if (e is FirebaseAuthException) {
        String errorMessage = _getPhoneAuthErrorMessage(e);
        onVerificationFailed(errorMessage);
      } else {
        onVerificationFailed('Phone verification failed: $e');
      }
    }

    return verificationId ?? '';
  }

  /// Signs in with phone credential using verification ID and SMS code
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    debugPrint('[AuthService] Signing in with phone credential');

    try {
      return await _signInWithCredentialWrapper(credential);
    } catch (e) {
      debugPrint('[AuthService] Phone sign-in failed: $e');
      rethrow;
    }
  }

  /// Verifies SMS code with verification ID and signs in
  Future<UserCredential> verifyOTPAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    debugPrint(
      '[AuthService] Verifying OTP: $smsCode with verification ID: $verificationId',
    );

    try {
      // Create credential from verification ID and SMS code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      debugPrint('[AuthService] Phone credential created successfully');

      // Sign in with the credential
      final result = await signInWithPhoneCredential(credential);
      debugPrint(
        '[AuthService] OTP verification successful for user: ${result.user?.uid}',
      );
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] OTP verification failed: ${e.code} - ${e.message}',
      );

      // Enhanced error handling for specific OTP verification errors
      switch (e.code) {
        case 'invalid-verification-code':
          debugPrint('[AuthService] Invalid verification code provided');
          throw Exception(
            'The verification code is invalid. Please check the code and try again.',
          );
        case 'invalid-verification-id':
          debugPrint('[AuthService] Invalid or expired verification ID');
          throw Exception(
            'The verification session has expired. Please request a new code.',
          );
        case 'session-expired':
          debugPrint('[AuthService] Verification session expired');
          throw Exception(
            'The verification session has expired. Please request a new code.',
          );
        default:
          throw Exception(_getPhoneAuthErrorMessage(e));
      }
    } catch (e) {
      debugPrint('[AuthService] OTP verification error: $e');
      throw Exception('Failed to verify OTP. Please try again.');
    }
  }

  // ================================
  // EMAIL AUTHENTICATION
  // ================================

  /// Sends email sign-in link to the provided email address (simplified version)
  Future<void> sendEmailSignInLinkSimple(String email) async {
    debugPrint('[AuthService] Sending email sign-in link to: $email');
    await sendEmailSignInLink(email: email);
  }

  /// Sends email sign-in link to the provided email address
  Future<void> sendEmailSignInLink({required String email}) async {
    debugPrint('[AuthService] Sending email sign-in link to: $email');

    try {
      // Configure action code settings for email link
      final ActionCodeSettings actionCodeSettings = ActionCodeSettings(
        url: 'https://marketsnap-app.firebaseapp.com', // Your app's domain
        handleCodeInApp: true,
        androidPackageName: 'com.example.marketsnap',
        androidInstallApp: true,
        androidMinimumVersion: '12',
        iOSBundleId: 'com.example.marketsnap',
      );

      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      debugPrint('[AuthService] Email sign-in link sent successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] Failed to send email link: ${e.code} - ${e.message}',
      );
      throw Exception(_getEmailAuthErrorMessage(e));
    } catch (e) {
      debugPrint('[AuthService] Email link send error: $e');
      throw Exception('Failed to send email link. Please try again.');
    }
  }

  /// Signs in with email link
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    debugPrint('[AuthService] Signing in with email link');

    try {
      final UserCredential result = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      debugPrint(
        '[AuthService] Email sign-in successful for user: ${result.user?.uid}',
      );
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Email sign-in failed: ${e.code}');
      await handleFirebaseAuthException(e);
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Email sign-in error: $e');
      throw Exception('Failed to sign in with email link.');
    }
  }

  /// Checks if a link is a valid sign-in email link
  bool isSignInWithEmailLink(String emailLink) {
    return _firebaseAuth.isSignInWithEmailLink(emailLink);
  }

  // ================================
  // ADDITIONAL PHONE AUTH HELPERS
  // ================================

  /// Simplified method to verify OTP (used by screens)
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    return await verifyOTPAndSignIn(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  /// Simplified method to sign in with phone number (used by screens)
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(String) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    debugPrint('[AuthService] Starting phone number sign-in for: $phoneNumber');

    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onVerificationCompleted: verificationCompleted,
      onVerificationFailed: verificationFailed,
      onCodeSent: codeSent,
      onCodeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // ================================
  // GENERAL AUTHENTICATION
  // ================================

  /// Signs out the current user
  Future<void> signOut() async {
    debugPrint('[AuthService] Signing out user...');
    try {
      // Also sign out from Google if that was the last sign-in method
      if (await GoogleSignIn().isSignedIn()) {
        await GoogleSignIn().signOut();
        debugPrint('[AuthService] Signed out from Google');
      }
      await _firebaseAuth.signOut();
      debugPrint('[AuthService] Signed out from Firebase');
    } catch (e) {
      debugPrint('[AuthService] Error during sign out: $e');
      // Even if there's an error, we should probably assume sign-out happened
      // or at least not block the user.
    }
  }

  /// Deletes the current user account
  Future<void> deleteAccount() async {
    debugPrint('[AuthService] Deleting user account: ${currentUser?.uid}');

    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      await currentUser!.delete();
      debugPrint('[AuthService] Account deletion successful');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] Account deletion failed: ${e.code} - ${e.message}',
      );

      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Recent authentication required. Please sign in again and try deleting your account.',
        );
      }

      throw Exception('Failed to delete account: ${e.message}');
    } catch (e) {
      debugPrint('[AuthService] Account deletion error: $e');
      throw Exception('Failed to delete account. Please try again.');
    }
  }

  /// Links the current user account with a phone number credential
  Future<UserCredential> linkWithPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    debugPrint('[AuthService] Linking current account with phone number');

    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      debugPrint('[AuthService] Attempting to link phone credential...');
      final result = await user.linkWithCredential(credential);

      debugPrint('[AuthService] Phone number linked successfully');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] Phone linking failed: ${e.code} - ${e.message}',
      );

      switch (e.code) {
        case 'provider-already-linked':
          throw Exception(
            'This account is already linked with a phone number.',
          );
        case 'invalid-verification-code':
          throw Exception(
            'The verification code is invalid. Please check and try again.',
          );
        case 'invalid-verification-id':
          throw Exception(
            'The verification session has expired. Please request a new code.',
          );
        case 'credential-already-in-use':
          throw Exception(
            'This phone number is already associated with another account.',
          );
        default:
          throw Exception('Failed to link phone number: ${e.message}');
      }
    } catch (e) {
      debugPrint('[AuthService] Phone linking error: $e');
      throw Exception('Failed to link phone number: $e');
    }
  }

  /// Links the current user account with Google credential
  Future<UserCredential> linkWithGoogle() async {
    debugPrint('[AuthService] Linking current account with Google');

    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: <String>['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('[AuthService] Attempting to link Google credential...');
      final result = await user.linkWithCredential(credential);

      debugPrint('[AuthService] Google account linked successfully');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] Google linking failed: ${e.code} - ${e.message}',
      );

      switch (e.code) {
        case 'provider-already-linked':
          throw Exception('This account is already linked with Google.');
        case 'credential-already-in-use':
          throw Exception(
            'This Google account is already associated with another user.',
          );
        case 'email-already-in-use':
          throw Exception(
            'The email address is already in use by another account.',
          );
        default:
          throw Exception('Failed to link Google account: ${e.message}');
      }
    } catch (e) {
      debugPrint('[AuthService] Google linking error: $e');
      throw Exception('Failed to link Google account: $e');
    }
  }

  /// Gets the user's phone number from their providers
  String? getUserPhoneNumber() {
    final user = currentUser;
    if (user == null) return null;

    // Check if user has phone provider
    for (final provider in user.providerData) {
      if (provider.providerId == 'phone' && provider.phoneNumber != null) {
        return provider.phoneNumber;
      }
    }
    return null;
  }

  /// Gets the user's email from their providers
  String? getUserEmail() {
    final user = currentUser;
    if (user == null) return null;

    // Primary email
    if (user.email != null) return user.email;

    // Check providers for email
    for (final provider in user.providerData) {
      if (provider.email != null) {
        return provider.email;
      }
    }
    return null;
  }

  /// Checks if the current user has multiple authentication providers linked
  bool hasMultipleProviders() {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.length > 1;
  }

  /// Gets list of authentication providers for the current user
  List<String> getUserProviders() {
    final user = currentUser;
    if (user == null) return [];
    return user.providerData.map((provider) => provider.providerId).toList();
  }

  // ================================
  // ERROR HANDLING HELPERS
  // ================================

  /// Maps Firebase Auth phone authentication errors to user-friendly messages
  String _getPhoneAuthErrorMessage(FirebaseAuthException e) {
    debugPrint(
      '[AuthService] Processing phone auth error: ${e.code} - ${e.message}',
    );

    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please check and try again.';
      case 'invalid-verification-id':
        return 'The verification session has expired. Please request a new code.';
      case 'session-expired':
        return 'The verification session has expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'missing-phone-number':
        return 'Please enter a valid phone number.';
      case 'missing-verification-code':
        return 'Please enter the verification code.';
      case 'credential-already-in-use':
        return 'This phone number is already associated with another account.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'app-check-token-invalid':
        return 'App verification failed. Please try again or contact support if the problem persists.';
      case 'network-request-failed':
        return 'Network error (such as timeout, interrupted connection or unreachable host) has occurred.';
      case 'internal-error':
        // Handle the specific "CONFIGURATION NOT FOUND" error
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return 'An internal error occurred. Please try again.';
      case 'unknown':
        // Handle various unknown errors
        if (e.message?.contains('Cleartext HTTP traffic') == true) {
          return 'Development mode: Firebase emulator connection issue. Please ensure emulators are running and network configuration is correct.';
        }
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return e.message ?? 'Phone authentication failed. Please try again.';
      default:
        // Check for configuration errors in any error code
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return e.message ?? 'Phone authentication failed. Please try again.';
    }
  }

  /// Maps Firebase Auth email authentication errors to user-friendly messages
  String _getEmailAuthErrorMessage(FirebaseAuthException e) {
    debugPrint(
      '[AuthService] Processing email auth error: ${e.code} - ${e.message}',
    );

    switch (e.code) {
      case 'invalid-email':
        return 'The email address format is invalid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'operation-not-allowed':
        return 'Email authentication is not enabled. Please contact support.';
      case 'invalid-action-code':
        return 'The email link is invalid or has expired.';
      case 'expired-action-code':
        return 'The email link has expired. Please request a new one.';
      case 'invalid-continue-uri':
        return 'The email link is malformed. Please request a new one.';
      case 'missing-continue-uri':
        return 'The email link is incomplete. Please request a new one.';
      case 'too-many-requests':
        return 'Too many email requests. Please wait before trying again.';
      case 'app-check-token-invalid':
        return 'App verification failed. Please try again or contact support if the problem persists.';
      case 'network-request-failed':
        return 'Network error (such as timeout, interrupted connection or unreachable host) has occurred.';
      case 'internal-error':
        // Handle the specific "CONFIGURATION NOT FOUND" error
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return 'An internal error occurred. Please try again.';
      case 'unknown':
        // Handle various unknown errors
        if (e.message?.contains('Cleartext HTTP traffic') == true) {
          return 'Development mode: Firebase emulator connection issue. Please ensure emulators are running and network configuration is correct.';
        }
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return e.message ?? 'Email authentication failed. Please try again.';
      default:
        // Check for configuration errors in any error code
        if (e.message?.contains('CONFIGURATION NOT FOUND') == true) {
          return 'App configuration error. Please ensure the app is properly set up and try again.';
        }
        return e.message ?? 'Email authentication failed. Please try again.';
    }
  }

  /// Private wrapper for signing in with any credential, with robust error handling
  Future<UserCredential> _signInWithCredentialWrapper(
      AuthCredential credential) async {
    try {
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      debugPrint(
          '[AuthService] Successfully signed in with credential. UID: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] _signInWithCredentialWrapper failed: ${e.code}');
      await handleFirebaseAuthException(e);
      rethrow;
    } catch (e) {
      debugPrint(
          '[AuthService] An unexpected error occurred during _signInWithCredentialWrapper: $e');
      throw Exception('An unexpected error occurred during sign-in.');
    }
  }

  /// Handles Firebase Authentication exceptions and signs out if necessary
  Future<void> handleFirebaseAuthException(FirebaseAuthException e) async {
    debugPrint('[AuthService] Handling FirebaseAuthException: ${e.code}');

    final isCriticalError = [
      'invalid-refresh-token',
      'user-disabled',
      'user-not-found',
      'invalid-credential',
    ].contains(e.code);

    if (isCriticalError) {
      debugPrint('[AuthService] Critical auth error detected. Signing out user.');
      await signOut();
      throw Exception(
          'Your session has expired or is invalid. Please sign in again.');
    } else {
      throw Exception(_getGeneralAuthErrorMessage(e));
    }
  }

  String _getGeneralAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification session has expired. Please request a new code.';
      case 'invalid-phone-number':
        return 'The phone number is not valid.';
      case 'invalid-credential':
        return 'Your credentials have expired or are invalid. Please sign in again.';
      case 'invalid-refresh-token':
        return 'Your session has expired. Please sign in again.';
      default:
        return 'An unknown authentication error occurred.';
    }
  }

  // ================================
  // UTILITY METHODS
  // ================================

  /// Formats phone number for international format
  String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add country code if not present (assuming US/Canada +1 for demo)
    if (!digitsOnly.startsWith('1') && digitsOnly.length == 10) {
      digitsOnly = '1$digitsOnly';
    }

    // Add + prefix for international format
    if (!digitsOnly.startsWith('+')) {
      digitsOnly = '+$digitsOnly';
    }

    return digitsOnly;
  }

  /// Validates phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Check if it looks like a valid international phone number
    // Should start with + and have at least 10 digits
    return digitsOnly.startsWith('+') && digitsOnly.length >= 11;
  }

  /// Validates email format
  bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Signs in with Google account
  Future<UserCredential> signInWithGoogle() async {
    debugPrint('[AuthService] Initiating Google Sign-In');
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('[AuthService] Google credential obtained, signing in...');
      return await _signInWithCredentialWrapper(credential);
    } on PlatformException catch (e) {
      debugPrint('[AuthService] Google Sign-In PlatformException: ${e.code}');
      if (e.code == 'network_error') {
        throw Exception(
            'A network error occurred. Please check your connection.');
      }
      throw Exception('Failed to sign in with Google. Please try again.');
    } catch (e) {
      debugPrint('[AuthService] Google sign-in failed: $e');
      throw Exception('An unknown error occurred during Google sign-in.');
    }
  }
}
