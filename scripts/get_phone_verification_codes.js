#!/usr/bin/env node

const axios = require('axios');

async function getPhoneVerificationCodes() {
  console.log('📱 Getting phone verification codes for test vendors...\n');
  
  const testVendors = [
    { name: "Alice's Farm Stand", phone: "+15551001001" },
    { name: "Bob's Artisan Bakery", phone: "+15551001002" },
    { name: "Carol's Flower Garden", phone: "+15551001003" },
    { name: "Dave's Mountain Honey", phone: "+15551001004" },
  ];

  console.log('🔐 PHONE AUTHENTICATION CODES:\n');

  for (const vendor of testVendors) {
    try {
      // Send verification code request to Firebase Auth emulator
      const response = await axios.post(
        'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake-api-key',
        {
          phoneNumber: vendor.phone,
          recaptchaToken: 'fake-recaptcha-token' // Emulator accepts any value
        },
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );

      console.log(`📞 ${vendor.name}`);
      console.log(`   Phone: ${vendor.phone}`);
      console.log(`   Code: Will be shown in Firebase emulator logs`);
      console.log(`   Session: ${response.data.sessionInfo}\n`);
      
    } catch (error) {
      console.error(`❌ Error for ${vendor.name}:`, error.response?.data || error.message);
    }
  }

  console.log('💡 HOW TO USE:');
  console.log('1. In the MarketSnap app, tap "Phone" on the sign-in screen');
  console.log('2. Enter one of the phone numbers above');
  console.log('3. Check the Firebase emulator terminal logs for the verification code');
  console.log('4. Enter the code in the app to sign in');
  console.log('\n🔍 The verification codes will appear in your Firebase emulator terminal like:');
  console.log('   "i  To verify the phone number +15551001001, use the code 284134."');
}

// Check if axios is available
try {
  require('axios');
  getPhoneVerificationCodes();
} catch (error) {
  console.log('📱 PHONE AUTHENTICATION FOR TEST VENDORS\n');
  console.log('🔐 Test Vendor Phone Numbers:\n');
  console.log('📞 Alice\'s Farm Stand: +15551001001');
  console.log('📞 Bob\'s Artisan Bakery: +15551001002');
  console.log('📞 Carol\'s Flower Garden: +15551001003');
  console.log('📞 Dave\'s Mountain Honey: +15551001004');
  console.log('\n💡 HOW TO USE:');
  console.log('1. In the MarketSnap app, tap "Phone" on the sign-in screen');
  console.log('2. Enter one of the phone numbers above');
  console.log('3. Check the Firebase emulator terminal logs for the verification code');
  console.log('4. Enter the code in the app to sign in');
  console.log('\n🔍 The verification codes will appear in your Firebase emulator terminal like:');
  console.log('   "i  To verify the phone number +15551001001, use the code 284134."');
} 