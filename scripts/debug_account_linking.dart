import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../lib/core/models/vendor_profile.dart';
import '../lib/core/services/account_linking_service.dart';
import '../lib/features/auth/application/auth_service.dart';
import '../lib/features/profile/application/profile_service.dart';
import '../lib/core/services/hive_service.dart';

void main() async {
  developer.log('🔍 Starting COMPREHENSIVE account linking debug test');
  
  // Initialize Firebase for emulator
  await Firebase.initializeApp();

  // Connect to Firebase emulator
  FirebaseFirestore.instance.settings = const Settings(
    host: '127.0.0.1:8080',
    sslEnabled: false,
    persistenceEnabled: false,
  );

  FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);

  await testAccountLinking();
}

Future<void> testAccountLinking() async {
  try {
    // Initialize services
    final authService = AuthService();
    final hiveService = HiveService();
    await hiveService.init();
    final profileService = ProfileService(hiveService: hiveService);
    final accountLinkingService = AccountLinkingService(
      authService: authService,
      profileService: profileService,
    );

    developer.log('📊 Testing account linking with comprehensive test cases');

    // Test Case 1: Check if vendor profiles exist in Firestore
    developer.log('1️⃣ Checking if test vendor profiles exist...');
    await checkVendorProfiles();

    // Test Case 2: Check Firebase Auth state
    developer.log('2️⃣ Checking Firebase Auth state...');
    await checkFirebaseAuthState();

    // Test Case 3: Test direct profile search by phone/email
    developer.log('3️⃣ Testing direct profile search methods...');
    await testDirectProfileSearch();

    // Test Case 4: Test AuthService contact info methods
    developer.log('4️⃣ Testing AuthService contact info methods...');
    await testAuthServiceMethods(authService);

    // Test Case 5: Test account linking service without authentication
    developer.log('5️⃣ Testing account linking service behavior without auth...');
    await testAccountLinkingWithoutAuth(accountLinkingService);

    // Test Case 6: Simulate account linking flow
    developer.log('6️⃣ Testing emulator phone sign-in and account linking...');
    await testEmulatorSignInFlow(authService, accountLinkingService);

    developer.log('✅ All debug tests completed successfully!');

  } catch (e) {
    developer.log('❌ Debug test failed: $e');
  }
}

Future<void> checkVendorProfiles() async {
  final vendorUIDs = [
    'vendor-alice-farm',
    'vendor-bob-bakery', 
    'vendor-carol-flowers',
    'vendor-dave-honey'
  ];

  for (final uid in vendorUIDs) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        developer.log('✅ Found vendor: ${data['stallName']} - Phone: ${data['phoneNumber']} - Email: ${data['email']}');
      } else {
        developer.log('❌ Vendor not found: $uid');
      }
    } catch (e) {
      developer.log('❌ Error checking vendor $uid: $e');
    }
  }
}

Future<void> checkFirebaseAuthState() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      developer.log('🔐 Current Firebase Auth user: ${currentUser.uid}');
      developer.log('📧 Email: ${currentUser.email}');
      developer.log('📞 Phone: ${currentUser.phoneNumber}');
      developer.log('🏷️ Providers: ${currentUser.providerData.map((p) => p.providerId).join(', ')}');
    } else {
      developer.log('🔓 No current Firebase Auth user');
    }
  } catch (e) {
    developer.log('❌ Error checking Firebase Auth state: $e');
  }
}

Future<void> testDirectProfileSearch() async {
  try {
    // Test profile search by phone number
    developer.log('📞 Searching for profile with phone +15551001002');
    
    final phoneQuery = await FirebaseFirestore.instance
        .collection('vendors')
        .where('phoneNumber', isEqualTo: '+15551001002')
        .limit(1)
        .get();

    if (phoneQuery.docs.isNotEmpty) {
      final doc = phoneQuery.docs.first;
      final data = doc.data();
      developer.log('✅ Found profile by phone: ${data['stallName']} (${doc.id})');
      developer.log('📧 Email: ${data['email']}');
      developer.log('🏪 Stall: ${data['stallName']}');
      developer.log('🌍 City: ${data['marketCity']}');
    } else {
      developer.log('❌ No profile found with phone +15551001002');
    }

    // Test profile search by email
    developer.log('📧 Searching for profile with email bob@artisanbakery.com');
    
    final emailQuery = await FirebaseFirestore.instance
        .collection('vendors')
        .where('email', isEqualTo: 'bob@artisanbakery.com')
        .limit(1)
        .get();

    if (emailQuery.docs.isNotEmpty) {
      final doc = emailQuery.docs.first;
      final data = doc.data();
      developer.log('✅ Found profile by email: ${data['stallName']} (${doc.id})');
    } else {
      developer.log('❌ No profile found with email bob@artisanbakery.com');
    }

  } catch (e) {
    developer.log('❌ Direct profile search failed: $e');
  }
}

Future<void> testAuthServiceMethods(AuthService authService) async {
  try {
    developer.log('🔍 Testing AuthService methods:');
    developer.log('👤 Current user: ${authService.currentUser?.uid ?? 'null'}');
    developer.log('🔐 Is authenticated: ${authService.isAuthenticated}');
    developer.log('📞 User phone: ${authService.getUserPhoneNumber() ?? 'null'}');
    developer.log('📧 User email: ${authService.getUserEmail() ?? 'null'}');
    developer.log('🏷️ User providers: ${authService.getUserProviders()}');
    developer.log('🔗 Has multiple providers: ${authService.hasMultipleProviders()}');
  } catch (e) {
    developer.log('❌ Error testing AuthService methods: $e');
  }
}

Future<void> testAccountLinkingWithoutAuth(AccountLinkingService accountLinkingService) async {
  try {
    developer.log('🔍 Testing account linking behavior without authentication...');
    
    final result = await accountLinkingService.findExistingProfileForCurrentUser();
    if (result == null) {
      developer.log('✅ Correctly returned null when no user is authenticated');
    } else {
      developer.log('❌ Unexpected: returned profile when no user authenticated: ${result.stallName}');
    }
    
    final linkingResult = await accountLinkingService.handleSignInAccountLinking();
    developer.log('🔗 Account linking result without auth: $linkingResult');
    
  } catch (e) {
    developer.log('❌ Error testing account linking without auth: $e');
  }
}

Future<void> testEmulatorSignInFlow(AuthService authService, AccountLinkingService accountLinkingService) async {
  try {
    developer.log('🔐 Testing Firebase emulator sign-in flow...');
    
    // In Firebase emulator, we can sign in with any email without password
    // Let's test with Bob's email
    final testEmail = 'bob@artisanbakery.com';
    
    developer.log('📧 Attempting to sign in with email: $testEmail');
    
    // For emulator testing, we'll use a simple email/password method
    // Note: This would need actual OTP flow in production
    try {
      // First, let's see if we can create a user in the emulator
      developer.log('👤 Creating test user in emulator...');
      
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail,
        password: 'testpassword123', // Emulator allows any password
      );
      
      developer.log('✅ Successfully created/signed in user: ${userCredential.user?.uid}');
      developer.log('📧 User email: ${userCredential.user?.email}');
      
      // Now test the account linking
      developer.log('🔗 Testing account linking with authenticated user...');
      
      final existingProfile = await accountLinkingService.findExistingProfileForCurrentUser();
      if (existingProfile != null) {
        developer.log('✅ Found existing profile: ${existingProfile.stallName}');
        developer.log('🏪 Profile details: ${existingProfile.displayName} - ${existingProfile.marketCity}');
      } else {
        developer.log('❌ No existing profile found for authenticated user');
      }
      
      final linkingResult = await accountLinkingService.handleSignInAccountLinking();
      developer.log('🔗 Account linking result: $linkingResult');
      
      // Clean up - sign out the test user
      await authService.signOut();
      developer.log('🔓 Signed out test user');
      
    } catch (authError) {
      developer.log('❌ Auth error during emulator sign-in: $authError');
      
      // If creation failed, maybe user already exists, try signing in
      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: 'testpassword123',
        );
        developer.log('✅ Signed in existing user: ${userCredential.user?.uid}');
        
        // Test account linking
        final existingProfile = await accountLinkingService.findExistingProfileForCurrentUser();
        if (existingProfile != null) {
          developer.log('✅ Found existing profile: ${existingProfile.stallName}');
        } else {
          developer.log('❌ No existing profile found');
        }
        
        await authService.signOut();
        developer.log('🔓 Signed out test user');
        
      } catch (signInError) {
        developer.log('❌ Sign-in also failed: $signInError');
      }
    }
    
  } catch (e) {
    developer.log('❌ Error testing emulator sign-in flow: $e');
  }
} 