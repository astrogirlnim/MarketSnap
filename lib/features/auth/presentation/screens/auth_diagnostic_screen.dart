// Diagnostic screen to debug authentication and profile lookup issues
// Add this to your auth screens to help debug the profile mismatch

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../main.dart' as main;

class AuthDiagnosticScreen extends StatefulWidget {
  @override
  _AuthDiagnosticScreenState createState() => _AuthDiagnosticScreenState();
}

class _AuthDiagnosticScreenState extends State<AuthDiagnosticScreen> {
  String diagnosticInfo = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    runDiagnostics();
  }

  Future<void> runDiagnostics() async {
    setState(() {
      isLoading = true;
      diagnosticInfo = 'Running authentication diagnostics...\n\n';
    });

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Check current authentication status
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        setState(() {
          diagnosticInfo += '❌ NO AUTHENTICATED USER FOUND\n';
          diagnosticInfo += 'Please log in first to run diagnostics.\n';
          isLoading = false;
        });
        return;
      }

      setState(() {
        diagnosticInfo += '✅ AUTHENTICATED USER FOUND\n';
        diagnosticInfo += 'Current User UID: ${currentUser.uid}\n';
        diagnosticInfo += 'Email: ${currentUser.email}\n';
        diagnosticInfo += 'Phone: ${currentUser.phoneNumber}\n';
        diagnosticInfo += 'Display Name: ${currentUser.displayName}\n';
        diagnosticInfo += 'Provider Data: ${currentUser.providerData.map((p) => p.providerId).join(', ')}\n\n';
      });

      // Check for vendor profile with current UID
      setState(() {
        diagnosticInfo += '🔍 CHECKING VENDOR PROFILE...\n';
      });
      
      final vendorDoc = await firestore.collection('vendors').doc(currentUser.uid).get();
      if (vendorDoc.exists) {
        setState(() {
          diagnosticInfo += '✅ VENDOR PROFILE FOUND for current UID\n';
          diagnosticInfo += 'Profile Data: ${vendorDoc.data()}\n\n';
        });
      } else {
        setState(() {
          diagnosticInfo += '❌ NO VENDOR PROFILE for current UID\n\n';
        });
      }

      // Check for regular user profile with current UID
      setState(() {
        diagnosticInfo += '🔍 CHECKING REGULAR USER PROFILE...\n';
      });
      
      final regularDoc = await firestore.collection('regularUsers').doc(currentUser.uid).get();
      if (regularDoc.exists) {
        setState(() {
          diagnosticInfo += '✅ REGULAR USER PROFILE FOUND for current UID\n';
          diagnosticInfo += 'Profile Data: ${regularDoc.data()}\n\n';
        });
      } else {
        setState(() {
          diagnosticInfo += '❌ NO REGULAR USER PROFILE for current UID\n\n';
        });
      }

      // Search for profiles by phone number
      if (currentUser.phoneNumber != null) {
        setState(() {
          diagnosticInfo += '🔍 SEARCHING PROFILES BY PHONE: ${currentUser.phoneNumber}\n';
        });

        final vendorPhoneQuery = await firestore
            .collection('vendors')
            .where('phoneNumber', isEqualTo: currentUser.phoneNumber)
            .get();

        if (vendorPhoneQuery.docs.isNotEmpty) {
          setState(() {
            diagnosticInfo += '✅ VENDOR PROFILE FOUND by phone number!\n';
            for (var doc in vendorPhoneQuery.docs) {
              diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
            }
            diagnosticInfo += '\n';
          });
        }

        final regularPhoneQuery = await firestore
            .collection('regularUsers')
            .where('phoneNumber', isEqualTo: currentUser.phoneNumber)
            .get();

        if (regularPhoneQuery.docs.isNotEmpty) {
          setState(() {
            diagnosticInfo += '✅ REGULAR USER PROFILE FOUND by phone number!\n';
            for (var doc in regularPhoneQuery.docs) {
              diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
            }
            diagnosticInfo += '\n';
          });
        }
      }

      // Search for profiles by email
      if (currentUser.email != null) {
        setState(() {
          diagnosticInfo += '🔍 SEARCHING PROFILES BY EMAIL: ${currentUser.email}\n';
        });

        final vendorEmailQuery = await firestore
            .collection('vendors')
            .where('email', isEqualTo: currentUser.email)
            .get();

        if (vendorEmailQuery.docs.isNotEmpty) {
          setState(() {
            diagnosticInfo += '✅ VENDOR PROFILE FOUND by email!\n';
            for (var doc in vendorEmailQuery.docs) {
              diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
            }
            diagnosticInfo += '\n';
          });
        }

        final regularEmailQuery = await firestore
            .collection('regularUsers')
            .where('email', isEqualTo: currentUser.email)
            .get();

        if (regularEmailQuery.docs.isNotEmpty) {
          setState(() {
            diagnosticInfo += '✅ REGULAR USER PROFILE FOUND by email!\n';
            for (var doc in regularEmailQuery.docs) {
              diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
            }
            diagnosticInfo += '\n';
          });
        }
      }

      // List ALL profiles to see what exists
      setState(() {
        diagnosticInfo += '📋 ALL VENDOR PROFILES IN DATABASE:\n';
      });
      
      final allVendors = await firestore.collection('vendors').get();
      if (allVendors.docs.isEmpty) {
        setState(() {
          diagnosticInfo += '❌ NO VENDOR PROFILES FOUND\n\n';
        });
      } else {
        for (var doc in allVendors.docs) {
          setState(() {
            diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
          });
        }
        setState(() {
          diagnosticInfo += '\n';
        });
      }

      setState(() {
        diagnosticInfo += '📋 ALL REGULAR USER PROFILES IN DATABASE:\n';
      });
      
      final allRegular = await firestore.collection('regularUsers').get();
      if (allRegular.docs.isEmpty) {
        setState(() {
          diagnosticInfo += '❌ NO REGULAR USER PROFILES FOUND\n\n';
        });
      } else {
        for (var doc in allRegular.docs) {
          setState(() {
            diagnosticInfo += 'UID: ${doc.id}, Data: ${doc.data()}\n';
          });
        }
        setState(() {
          diagnosticInfo += '\n';
        });
      }

      setState(() {
        diagnosticInfo += '🏁 DIAGNOSTICS COMPLETE\n';
        diagnosticInfo += '═══════════════════════════════════════\n';
        diagnosticInfo += 'RECOMMENDATION:\n';
        diagnosticInfo += 'If profiles exist with different UIDs but matching\n';
        diagnosticInfo += 'phone/email, the AccountLinkingService should copy\n';
        diagnosticInfo += 'the existing profile to your current UID.\n';
      });

    } catch (e) {
      setState(() {
        diagnosticInfo += '❌ DIAGNOSTIC ERROR: $e\n';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fixAuthIssue() async {
    setState(() {
      isLoading = true;
      diagnosticInfo += '\n\n🔧 ATTEMPTING TO FIX AUTHENTICATION ISSUE...\n';
    });

    try {
      final authIssueFixed = await main.authIssueFixService.fixAuthenticationProfileMismatch();
      
      setState(() {
        if (authIssueFixed) {
          diagnosticInfo += '✅ AUTHENTICATION ISSUE FIXED!\n';
          diagnosticInfo += 'Your existing profile has been found and linked to your current account.\n';
          diagnosticInfo += 'You should now be able to access your profile.\n';
          diagnosticInfo += '\nPlease restart the app to see the changes.\n';
        } else {
          diagnosticInfo += '❌ NO EXISTING PROFILE FOUND TO FIX\n';
          diagnosticInfo += 'This means you need to create a new profile.\n';
          diagnosticInfo += 'Close this screen and complete the profile creation process.\n';
        }
      });
    } catch (e) {
      setState(() {
        diagnosticInfo += '❌ ERROR FIXING AUTHENTICATION ISSUE: $e\n';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Auth Diagnostics'),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (isLoading)
              LinearProgressIndicator(
                backgroundColor: Colors.orange.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Text(
                    diagnosticInfo,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Colors.green,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : runDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(
                      isLoading ? 'Running...' : 'Refresh',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _fixAuthIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(
                      'Fix Auth Issue',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 