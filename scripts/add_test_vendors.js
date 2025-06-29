#!/usr/bin/env node

// Set environment variable for emulator testing
process.env.GOOGLE_APPLICATION_CREDENTIALS = '';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for emulator
admin.initializeApp({
  projectId: 'marketsnap-app',
  // Use application default credentials for emulator
});

// Connect to Firestore emulator
const db = admin.firestore();
db.settings({
  host: '127.0.0.1:8080',
  ssl: false,
});

async function addTestVendors() {
  console.log('🧪 Adding test vendors to MarketSnap Firestore emulator...');
  console.log('💡 This creates vendor profiles for testing messaging and follow functionality');
  
  try {
    // Test vendor profiles for messaging and following
    const testVendors = [
      {
        uid: 'vendor-alice-organic',
        email: 'alice@organicfarms.com',
        phoneNumber: '+15551234001',
        displayName: 'Alice Johnson',
        stallName: 'Alice\'s Organic Farm',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alice&backgroundColor=c0aede',
        bio: 'Certified organic vegetables and herbs grown with sustainable practices. Visit us at the Portland Farmers Market every Saturday! 🌱🥕',
        isComplete: true,
        fcmToken: 'test-fcm-token-alice-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-bob-bakery',
        email: 'bob@artisanbread.com',
        phoneNumber: '+15551234002',
        displayName: 'Bob Martinez',
        stallName: 'Bob\'s Artisan Bakery',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Bob&backgroundColor=ffdfbf',
        bio: 'Handcrafted sourdough bread and pastries made with locally sourced ingredients. Fresh baked daily! 🍞🥐',
        isComplete: true,
        fcmToken: 'test-fcm-token-bob-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-carol-flowers',
        email: 'carol@seasonalblooms.com',
        phoneNumber: '+15551234003',
        displayName: 'Carol Williams',
        stallName: 'Carol\'s Seasonal Blooms',
        marketCity: 'Seattle, WA',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Carol&backgroundColor=ffd5dc',
        bio: 'Beautiful seasonal flowers and custom arrangements. Specializing in wedding bouquets and event florals 🌸🌺',
        isComplete: true,
        fcmToken: 'test-fcm-token-carol-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-dave-honey',
        email: 'dave@mountainhoney.com',
        phoneNumber: '+15551234004',
        displayName: 'Dave Thompson',
        stallName: 'Dave\'s Mountain Honey',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Dave&backgroundColor=ffffcc',
        bio: 'Pure wildflower honey from the Cascade Mountains. Raw, unfiltered, and delicious! Also selling beeswax candles 🍯🐝',
        isComplete: true,
        fcmToken: 'test-fcm-token-dave-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-emma-cheese',
        email: 'emma@farmhousecheese.com',
        phoneNumber: '+15551234005',
        displayName: 'Emma Davis',
        stallName: 'Emma\'s Farmhouse Cheese',
        marketCity: 'Seattle, WA',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emma&backgroundColor=e6f3ff',
        bio: 'Artisanal cheeses made from grass-fed cow and goat milk. Try our award-winning aged cheddar! 🧀🐄',
        isComplete: true,
        fcmToken: 'test-fcm-token-emma-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-frank-coffee',
        email: 'frank@mountainroast.com',
        phoneNumber: '+15551234006',
        displayName: 'Frank Rodriguez',
        stallName: 'Frank\'s Mountain Roast',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Frank&backgroundColor=d4c5b9',
        bio: 'Small-batch coffee roasted to perfection. Direct trade beans from Central America. Fresh roasted every Tuesday! ☕️📦',
        isComplete: true,
        fcmToken: 'test-fcm-token-frank-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      }
    ];

    console.log('🔐 Creating authentication accounts...');
    
    // Create authentication accounts for test vendors
    for (const vendor of testVendors) {
      try {
        await admin.auth().createUser({
          uid: vendor.uid,
          email: vendor.email,
          phoneNumber: vendor.phoneNumber,
          displayName: vendor.displayName,
          emailVerified: true,
        });
        console.log(`✅ Created auth account: ${vendor.displayName} (${vendor.email})`);
      } catch (error) {
        if (error.code === 'auth/uid-already-exists') {
          console.log(`⚠️  Auth account already exists: ${vendor.displayName}`);
        } else {
          console.error(`❌ Error creating auth account for ${vendor.displayName}:`, error.message);
        }
      }
    }

    console.log('👥 Adding test vendor profiles...');
    
    // Add vendor profiles to Firestore
    for (const vendor of testVendors) {
      await db.collection('vendors').doc(vendor.uid).set(vendor);
      console.log(`✅ Added vendor profile: ${vendor.stallName}`);
    }

    // Add some sample snaps for the vendors
    console.log('📸 Adding sample snaps...');
    
    const sampleSnaps = [
      {
        vendorId: 'vendor-alice-organic',
        vendorName: 'Alice\'s Organic Farm',
        vendorAvatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alice&backgroundColor=c0aede',
        mediaUrl: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Fresh organic tomatoes just harvested! 🍅 Perfect for your weekend cooking',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)), // 2 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 22 * 60 * 60 * 1000)) // 22 hours from now
      },
      {
        vendorId: 'vendor-bob-bakery',
        vendorName: 'Bob\'s Artisan Bakery',
        vendorAvatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Bob&backgroundColor=ffdfbf',
        mediaUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Warm sourdough just out of the oven! 🍞 Still have 6 loaves available',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 60 * 1000)), // 1 hour ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23 * 60 * 60 * 1000)) // 23 hours from now
      },
      {
        vendorId: 'vendor-carol-flowers',
        vendorName: 'Carol\'s Seasonal Blooms',
        vendorAvatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Carol&backgroundColor=ffd5dc',
        mediaUrl: 'https://images.unsplash.com/photo-1487070183336-b980b9be8e17?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Beautiful sunflowers in full bloom! 🌻 Perfect for brightening your home',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000)), // 30 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.5 * 60 * 60 * 1000)) // 23.5 hours from now
      }
    ];

    for (const snap of sampleSnaps) {
      await db.collection('snaps').add(snap);
      console.log(`✅ Added snap: ${snap.caption.substring(0, 30)}...`);
    }

    // Add some sample messages
    console.log('💬 Adding sample messages...');
    
    const sampleMessages = [
      {
        fromUid: 'vendor-alice-organic',
        toUid: 'vendor-bob-bakery',
        conversationId: 'vendor-alice-organic_vendor-bob-bakery',
        participants: ['vendor-alice-organic', 'vendor-bob-bakery'],
        text: 'Hi Bob! Do you need any fresh herbs for your artisan breads?',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 45 * 60 * 1000)), // 45 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.25 * 60 * 60 * 1000))
      },
      {
        fromUid: 'vendor-bob-bakery',
        toUid: 'vendor-alice-organic',
        conversationId: 'vendor-alice-organic_vendor-bob-bakery',
        participants: ['vendor-alice-organic', 'vendor-bob-bakery'],
        text: 'That would be perfect! I could use some rosemary and thyme for my weekend batch.',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 40 * 60 * 1000)), // 40 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.33 * 60 * 60 * 1000))
      },
      {
        fromUid: 'vendor-carol-flowers',
        toUid: 'vendor-dave-honey',
        conversationId: 'vendor-carol-flowers_vendor-dave-honey',
        participants: ['vendor-carol-flowers', 'vendor-dave-honey'],
        text: 'Hey Dave! Would you be interested in trading honey for some fresh sunflowers?',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 20 * 60 * 1000)), // 20 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.67 * 60 * 60 * 1000))
      }
    ];

    for (const message of sampleMessages) {
      await db.collection('messages').add(message);
      console.log(`✅ Added message: "${message.text.substring(0, 40)}..."`);
    }

    console.log('');
    console.log('🎉 Test vendors setup complete!');
    console.log('');
    console.log('📋 What was created:');
    console.log('   • 6 test vendor authentication accounts');
    console.log('   • 6 test vendor profiles with complete information');
    console.log('   • 3 sample snaps with real food photos');
    console.log('   • 3 sample messages between vendors');
    console.log('');
    console.log('🔐 TEST VENDOR LOGIN CREDENTIALS:');
    console.log('');
    console.log('   🌱 Alice\'s Organic Farm');
    console.log('      Email: alice@organicfarms.com');
    console.log('      Phone: +15551234001');
    console.log('');
    console.log('   🍞 Bob\'s Artisan Bakery');
    console.log('      Email: bob@artisanbread.com');
    console.log('      Phone: +15551234002');
    console.log('');
    console.log('   🌸 Carol\'s Seasonal Blooms');
    console.log('      Email: carol@seasonalblooms.com');
    console.log('      Phone: +15551234003');
    console.log('');
    console.log('   🍯 Dave\'s Mountain Honey');
    console.log('      Email: dave@mountainhoney.com');
    console.log('      Phone: +15551234004');
    console.log('');
    console.log('   🧀 Emma\'s Farmhouse Cheese');
    console.log('      Email: emma@farmhousecheese.com');
    console.log('      Phone: +15551234005');
    console.log('');
    console.log('   ☕️ Frank\'s Mountain Roast');
    console.log('      Email: frank@mountainroast.com');
    console.log('      Phone: +15551234006');
    console.log('');
    console.log('🧪 How to test:');
    console.log('   1. Sign out of your current account');
    console.log('   2. Sign in using any of the above email addresses');
    console.log('   3. Go to the Messages tab - you should see conversations');
    console.log('   4. Go to the Feed tab - you should see snaps');
    console.log('   5. Tap the + button in Messages to discover other vendors');
    console.log('   6. Test the follow functionality on vendor profiles');
    console.log('');
    console.log('🔍 Verify in Firestore UI: http://127.0.0.1:4000/firestore');
    
  } catch (error) {
    console.error('❌ Error setting up test vendors:', error);
    process.exit(1);
  }
}

// Run the script
addTestVendors()
  .then(() => {
    console.log('✅ Script completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  }); 