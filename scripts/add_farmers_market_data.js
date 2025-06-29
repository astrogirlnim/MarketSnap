#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for emulator
admin.initializeApp({
  projectId: 'marketsnap-app',
});

// Connect to Firestore emulator
const db = admin.firestore();
db.settings({
  host: '127.0.0.1:8080',
  ssl: false,
});

async function addFarmersMarketData() {
  console.log('🌾 Adding farmer\'s market test data to MarketSnap...');
  console.log('🥕 Focus: Real farm vendors with food content perfect for RAG testing');
  console.log('');
  
  try {
    // Farmer's Market Vendors - realistic and food-focused
    const marketVendors = [
      {
        uid: 'vendor-sunrise-organic',
        email: 'sarah@sunriseorganic.farm',
        phoneNumber: '+15551234001',
        displayName: 'Sarah Chen',
        stallName: 'Sunrise Organic Farm',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        bio: 'Certified organic vegetables, herbs, and microgreens. 3rd generation family farm committed to sustainable practices. 🌱🥕',
        isComplete: true,
        fcmToken: 'test-fcm-token-sunrise-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-golden-grain',
        email: 'mike@goldengrain.bakery',
        phoneNumber: '+15551234002',
        displayName: 'Mike Rodriguez',
        stallName: 'Golden Grain Bakery',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        bio: 'Artisan sourdough breads, pastries, and gluten-free options. Everything baked fresh daily using local wheat. 🍞🥐',
        isComplete: true,
        fcmToken: 'test-fcm-token-golden-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-mountain-dairy',
        email: 'anna@mountaindairy.farm',
        phoneNumber: '+15551234003',
        displayName: 'Anna Thompson',
        stallName: 'Mountain View Dairy',
        marketCity: 'Seattle, WA',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b790?w=150&h=150&fit=crop&crop=face',
        bio: 'Farmstead cheeses, fresh milk, and butter from grass-fed cows. Award-winning aged cheddars and seasonal varieties. 🧀🐄',
        isComplete: true,
        fcmToken: 'test-fcm-token-mountain-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-berry-patch',
        email: 'jenny@berrypatch.farm',
        phoneNumber: '+15551234004',
        displayName: 'Jenny Wilson',
        stallName: 'Berry Patch Farm',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        bio: 'Seasonal berries, stone fruits, and preserves. Pick-your-own berry farm with homemade jams and pies. 🍓🥧',
        isComplete: true,
        fcmToken: 'test-fcm-token-berry-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-heritage-herbs',
        email: 'david@heritageherbs.garden',
        phoneNumber: '+15551234005',
        displayName: 'David Park',
        stallName: 'Heritage Herb Garden',
        marketCity: 'Seattle, WA',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
        bio: 'Culinary herbs, medicinal plants, and heirloom varieties. Specializing in rare herbs and custom herb blends. 🌿🍃',
        isComplete: true,
        fcmToken: 'test-fcm-token-heritage-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      },
      {
        uid: 'vendor-coastal-coffee',
        email: 'lisa@coastalcoffee.roast',
        phoneNumber: '+15551234006',
        displayName: 'Lisa Johnson',
        stallName: 'Coastal Coffee Roasters',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=150&h=150&fit=crop&crop=face',
        bio: 'Small-batch coffee roasted weekly. Direct-trade beans from Central & South America. Free tastings every Saturday! ☕️📦',
        isComplete: true,
        fcmToken: 'test-fcm-token-coastal-' + Date.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      }
    ];

    console.log('🔐 Creating vendor authentication accounts...');
    
    // Create authentication accounts for farmers market vendors
    for (const vendor of marketVendors) {
      try {
        await admin.auth().createUser({
          uid: vendor.uid,
          email: vendor.email,
          phoneNumber: vendor.phoneNumber,
          displayName: vendor.displayName,
          emailVerified: true,
        });
        console.log(`✅ Created auth: ${vendor.stallName}`);
      } catch (error) {
        if (error.code === 'auth/uid-already-exists') {
          console.log(`⚠️  Auth exists: ${vendor.stallName}`);
        } else {
          console.error(`❌ Auth error for ${vendor.stallName}:`, error.message);
        }
      }
    }

    console.log('👥 Adding vendor profiles...');
    
    // Add vendor profiles to Firestore
    for (const vendor of marketVendors) {
      await db.collection('vendors').doc(vendor.uid).set(vendor);
      console.log(`✅ Added vendor: ${vendor.stallName}`);
    }

    // Farmer's Market Snaps - food-focused content perfect for RAG
    console.log('📸 Adding farmer\'s market snaps...');
    
    const marketSnaps = [
      // 📸 STORIES (appear in carousel) - 4 items
      
      // Sunrise Organic Farm - Story
      {
        vendorId: 'vendor-sunrise-organic',
        vendorName: 'Sunrise Organic Farm',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Fresh heirloom tomatoes just harvested! 🍅 Perfect for caprese salad or fresh pasta sauce. Still warm from the sun!',
        isStory: true, // ✅ STORY - appears in carousel
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 60 * 1000)), // 1 hour ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23 * 60 * 60 * 1000)) // 23 hours from now
      },
      
      // Golden Grain Bakery - Story
      {
        vendorId: 'vendor-golden-grain',
        vendorName: 'Golden Grain Bakery',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Warm sourdough loaves just out of the oven! 🍞 Made with our 100-year-old starter. Only 8 loaves left for today.',
        isStory: true, // ✅ STORY - appears in carousel
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000)), // 30 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.5 * 60 * 60 * 1000))
      },

      // Berry Patch Farm - Story  
      {
        vendorId: 'vendor-berry-patch',
        vendorName: 'Berry Patch Farm',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Peak-season strawberries picked this morning! 🍓 Sweet, juicy, and perfect for pies, jams, or eating fresh.',
        isStory: true, // ✅ STORY - appears in carousel
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 45 * 60 * 1000)), // 45 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 23.25 * 60 * 60 * 1000))
      },

      // Heritage Herb Garden - Story
      {
        vendorId: 'vendor-heritage-herbs',
        vendorName: 'Heritage Herb Garden',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1585254020021-35e2ea0a3e6a?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Fresh basil, rosemary, and thyme bundles! 🌿 Perfect for Mediterranean cooking. Harvested just before sunrise.',
        isStory: true, // ✅ STORY - appears in carousel
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 90 * 60 * 1000)), // 1.5 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 22.5 * 60 * 60 * 1000))
      },

      // 📰 FEED POSTS (appear in main feed) - 5 items
      
      {
        vendorId: 'vendor-sunrise-organic',
        vendorName: 'Sunrise Organic Farm',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Rainbow carrots and fresh beets ready for your kitchen! 🥕 Great for roasting or fresh juice. Limited quantities today.',
        isStory: false, // ✅ FEED POST - appears in main feed
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 60 * 60 * 1000)), // 3 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 21 * 60 * 60 * 1000))
      },
      
      {
        vendorId: 'vendor-golden-grain',
        vendorName: 'Golden Grain Bakery',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1478369402113-1fd53f17e8b4?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Fresh croissants and Danish pastries! 🥐 Buttery, flaky, and perfect with morning coffee. Best served warm.',
        isStory: false, // ✅ FEED POST - appears in main feed
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)), // 2 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 22 * 60 * 60 * 1000))
      },

      {
        vendorId: 'vendor-mountain-dairy',
        vendorName: 'Mountain View Dairy',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b790?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Aged cheddar and gouda wheels ready for tasting! 🧀 Pair with local honey and fresh bread for the perfect snack.',
        isStory: false, // ✅ FEED POST - appears in main feed
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 60 * 60 * 1000)), // 4 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 20 * 60 * 60 * 1000))
      },

      {
        vendorId: 'vendor-berry-patch',
        vendorName: 'Berry Patch Farm',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Fresh peaches and apricots - so ripe they\'re almost melting! 🍑 Great for cobblers, smoothies, or grilling.',
        isStory: false, // ✅ FEED POST - appears in main feed
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 60 * 1000)), // 5 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 19 * 60 * 60 * 1000))
      },

      {
        vendorId: 'vendor-coastal-coffee',
        vendorName: 'Coastal Coffee Roasters',
        vendorAvatarUrl: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=150&h=150&fit=crop&crop=face',
        mediaUrl: 'https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=400&h=600&fit=crop',
        mediaType: 'photo',
        caption: 'Single-origin Colombian beans roasted yesterday! ☕️ Rich, chocolatey notes perfect for pour-over or espresso.',
        isStory: false, // ✅ FEED POST - appears in main feed
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 6 * 60 * 60 * 1000)), // 6 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 18 * 60 * 60 * 1000))
      }
    ];

    for (const snap of marketSnaps) {
      await db.collection('snaps').add(snap);
      console.log(`✅ Added snap: ${snap.caption.substring(0, 40)}...`);
    }

    // Add some vendor-to-vendor messages for testing messaging
    console.log('💬 Adding sample vendor conversations...');
    
    const vendorMessages = [
      {
        fromUid: 'vendor-sunrise-organic',
        toUid: 'vendor-golden-grain',
        conversationId: 'vendor-sunrise-organic_vendor-golden-grain',
        participants: ['vendor-sunrise-organic', 'vendor-golden-grain'],
        text: 'Hi Mike! Do you need any fresh herbs for your bread this week? I have amazing basil and rosemary.',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 22 * 60 * 60 * 1000))
      },
      {
        fromUid: 'vendor-golden-grain',
        toUid: 'vendor-sunrise-organic',
        conversationId: 'vendor-sunrise-organic_vendor-golden-grain',
        participants: ['vendor-sunrise-organic', 'vendor-golden-grain'],
        text: 'That would be perfect! I\'m making herb focaccia tomorrow. Can I get 3 bundles of each?',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 90 * 60 * 1000)),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 22.5 * 60 * 60 * 1000))
      }
    ];

    for (const message of vendorMessages) {
      await db.collection('messages').add(message);
      console.log(`✅ Added message: "${message.text.substring(0, 30)}..."`);
    }

    console.log('');
    console.log('🎉 Farmer\'s market test data setup complete!');
    console.log('');
    console.log('📋 What was created:');
    console.log('   • 6 authentic farmer\'s market vendor profiles');
    console.log('   • 9 food-focused snaps with realistic images');
    console.log('   • Vendor authentication accounts');
    console.log('   • Sample vendor-to-vendor messages');
    console.log('');
    console.log('🔐 TEST VENDOR LOGIN CREDENTIALS:');
    console.log('');
    console.log('   🌱 Sunrise Organic Farm');
    console.log('      Email: sarah@sunriseorganic.farm');
    console.log('      Phone: +15551234001');
    console.log('');
    console.log('   🍞 Golden Grain Bakery');
    console.log('      Email: mike@goldengrain.bakery');
    console.log('      Phone: +15551234002');
    console.log('');
    console.log('   🧀 Mountain View Dairy');
    console.log('      Email: anna@mountaindairy.farm');
    console.log('      Phone: +15551234003');
    console.log('');
    console.log('   🍓 Berry Patch Farm');
    console.log('      Email: jenny@berrypatch.farm');
    console.log('      Phone: +15551234004');
    console.log('');
    console.log('   🌿 Heritage Herb Garden');
    console.log('      Email: david@heritageherbs.garden');
    console.log('      Phone: +15551234005');
    console.log('');
    console.log('   ☕️ Coastal Coffee Roasters');
    console.log('      Email: lisa@coastalcoffee.roast');
    console.log('      Phone: +15551234006');
    console.log('');
    console.log('🧪 Perfect for testing:');
    console.log('   • RAG recipe suggestions (tomatoes, bread, cheese, etc.)');
    console.log('   • RAG FAQ searches (farming, cooking, storage tips)');
    console.log('   • Feedback buttons on food-related content');
    console.log('   • Messaging between farmers');
    console.log('   • Follow functionality with real vendors');
    console.log('');
    console.log('🔍 Verify at: http://127.0.0.1:4000/firestore');
    console.log('✅ Ready for RAG feedback testing!');

  } catch (error) {
    console.error('❌ Error adding farmer\'s market data:', error);
    process.exit(1);
  }
}

// Run the function
addFarmersMarketData()
  .then(() => {
    console.log('✅ Farmer\'s market data script completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Farmer\'s market data script failed:', error);
    process.exit(1);
  }); 