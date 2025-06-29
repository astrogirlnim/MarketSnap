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

async function addTestFAQData() {
  console.log('🧪 Adding test FAQ data to MarketSnap Firestore emulator...');
  console.log('💡 This creates FAQ entries for testing the vendor knowledge base');
  
  try {
    // Test FAQ data for different vendors
    const testFAQs = [
      // Alice's Organic Farm FAQs
      {
        vendorId: 'vendor-alice-organic',
        question: 'Are your vegetables certified organic?',
        answer: 'Yes! All our vegetables are USDA certified organic. We have been certified for over 5 years and follow strict organic farming practices.',
        category: 'produce',
        keywords: ['organic', 'certified', 'vegetables', 'usda', 'farming'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-alice-organic',
        question: 'What days are you at the farmers market?',
        answer: 'We are at the Portland Farmers Market every Saturday from 8am to 2pm. During peak season (June-September), we also attend the Wednesday evening market from 4pm to 8pm.',
        category: 'schedule',
        keywords: ['market', 'schedule', 'saturday', 'portland', 'hours', 'wednesday'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-alice-organic',
        question: 'Do you accept credit cards?',
        answer: 'Yes, we accept cash, credit cards, and SNAP/EBT benefits. We also accept Venmo and Apple Pay for your convenience.',
        category: 'payment',
        keywords: ['payment', 'credit', 'cash', 'snap', 'ebt', 'venmo', 'apple pay'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-alice-organic',
        question: 'How should I store fresh herbs?',
        answer: 'For best freshness, trim the stems and place herbs in a glass of water, cover with a plastic bag, and refrigerate. Most herbs will stay fresh for 5-7 days this way.',
        category: 'storage',
        keywords: ['herbs', 'storage', 'fresh', 'refrigerate', 'preserve'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // Bob's Artisan Bakery FAQs
      {
        vendorId: 'vendor-bob-bakery',
        question: 'What ingredients do you use in your sourdough?',
        answer: 'Our sourdough contains only four ingredients: organic flour, water, sea salt, and our 10-year-old sourdough starter. No preservatives or additives!',
        category: 'ingredients',
        keywords: ['sourdough', 'ingredients', 'organic', 'flour', 'starter', 'preservatives'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-bob-bakery',
        question: 'Can you make custom orders?',
        answer: 'Absolutely! We love making custom breads and pastries for special occasions. Please give us at least 48 hours notice for custom orders.',
        category: 'custom_orders',
        keywords: ['custom', 'orders', 'special', 'occasions', 'notice', 'pastries'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-bob-bakery',
        question: 'Do you have any gluten-free options?',
        answer: 'Yes! We make gluten-free almond flour muffins and cookies. These are made in a separate area to prevent cross-contamination.',
        category: 'dietary',
        keywords: ['gluten-free', 'almond', 'muffins', 'cookies', 'contamination', 'dietary'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // Carol's Seasonal Blooms FAQs
      {
        vendorId: 'vendor-carol-flowers',
        question: 'How long do your cut flowers typically last?',
        answer: 'With proper care, our cut flowers typically last 7-10 days. We include care instructions with every purchase to help you get the most from your flowers.',
        category: 'care',
        keywords: ['flowers', 'care', 'lasting', 'instructions', 'fresh', 'longevity'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-carol-flowers',
        question: 'Can you create wedding bouquets?',
        answer: 'Yes! Wedding florals are our specialty. We offer consultation, bouquets, boutonnieres, centerpieces, and ceremony arrangements. Book at least 4 weeks in advance.',
        category: 'weddings',
        keywords: ['wedding', 'bouquets', 'consultation', 'ceremony', 'centerpieces', 'boutonnieres'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // Dave's Mountain Honey FAQs
      {
        vendorId: 'vendor-dave-honey',
        question: 'Is your honey raw and unfiltered?',
        answer: 'Yes! Our honey is completely raw and unfiltered. We only strain out large debris but keep all the beneficial pollen, enzymes, and nutrients intact.',
        category: 'processing',
        keywords: ['raw', 'unfiltered', 'pollen', 'enzymes', 'nutrients', 'natural'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-dave-honey',
        question: 'What flowers do your bees visit?',
        answer: 'Our bees primarily visit wildflowers in the Cascade Mountains including blackberry, clover, fireweed, and various alpine flowers. This creates our unique wildflower honey flavor.',
        category: 'sourcing',
        keywords: ['wildflowers', 'cascade', 'blackberry', 'clover', 'fireweed', 'alpine', 'flavor'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // Emma's Farmhouse Cheese FAQs
      {
        vendorId: 'vendor-emma-cheese',
        question: 'How are your cheeses aged?',
        answer: 'We age our cheeses in our natural cave for 2-24 months depending on the variety. The cave maintains perfect temperature and humidity for developing complex flavors.',
        category: 'process',
        keywords: ['aging', 'cave', 'temperature', 'humidity', 'flavors', 'months'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-emma-cheese',
        question: 'Can I sample cheeses before buying?',
        answer: 'Absolutely! We encourage sampling to help you find your favorites. We have samples available for all our aged cheeses at the market.',
        category: 'service',
        keywords: ['sampling', 'taste', 'favorites', 'aged', 'market', 'try'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // Frank's Mountain Roast FAQs
      {
        vendorId: 'vendor-frank-coffee',
        question: 'How fresh is your coffee?',
        answer: 'We roast every Tuesday and only sell coffee that is less than 7 days old. Each bag has a roast date so you know exactly how fresh it is.',
        category: 'freshness',
        keywords: ['fresh', 'roast', 'tuesday', 'date', 'weekly', 'quality'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {
        vendorId: 'vendor-frank-coffee',
        question: 'Do you offer different roast levels?',
        answer: 'Yes! We offer light, medium, and dark roasts. Our medium roast is most popular, but we can custom roast to your preference with advance notice.',
        category: 'variety',
        keywords: ['roast', 'light', 'medium', 'dark', 'custom', 'preference'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },

      // General test vendor FAQs (for the current logged-in user)
      {
        vendorId: 'vendor-test-user',
        question: 'Test question',
        answer: 'Test answer',
        category: 'test category',
        keywords: ['tomatoes'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
    ];

    console.log('📝 Adding FAQ entries...');
    
    // Add FAQ entries to Firestore
    for (const faq of testFAQs) {
      const docRef = await db.collection('faqs').add(faq);
      console.log(`✅ Added FAQ: "${faq.question.substring(0, 50)}..." for ${faq.vendorId}`);
      
      // Create a corresponding faqVector entry (without embedding to simulate "pending vectorization")
      await db.collection('faqVectors').doc(docRef.id).set({
        faqId: docRef.id,
        vendorId: faq.vendorId,
        question: faq.question,
        answer: faq.answer,
        category: faq.category,
        keywords: faq.keywords,
        // embedding: null, // This will be null to simulate "pending vectorization"
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
      console.log(`✅ Added FAQ vector (pending): ${docRef.id}`);
    }

    // Add some analytics data for testing
    console.log('📊 Adding analytics test data...');
    
    const analyticsData = [
      {
        faqId: 'placeholder-will-be-replaced',
        userId: 'user-test-123',
        query: 'organic vegetables',
        helpful: true,
        timestamp: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)), // 2 days ago
      },
      {
        faqId: 'placeholder-will-be-replaced',
        userId: 'user-test-456',
        query: 'market hours',
        helpful: true,
        timestamp: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)), // 1 day ago
      },
      {
        faqId: 'placeholder-will-be-replaced',
        userId: 'user-test-789',
        query: 'payment methods',
        helpful: false,
        timestamp: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 12 * 60 * 60 * 1000)), // 12 hours ago
      },
    ];

    // Get the first FAQ ID to use for analytics
    const firstFAQSnapshot = await db.collection('faqs').limit(1).get();
    if (!firstFAQSnapshot.empty) {
      const firstFAQId = firstFAQSnapshot.docs[0].id;
      
      for (const analytics of analyticsData) {
        analytics.faqId = firstFAQId;
        await db.collection('ragFeedback').add(analytics);
        console.log(`✅ Added analytics entry: ${analytics.query}`);
      }
    }

    console.log('🎉 Successfully added test FAQ data!');
    console.log('');
    console.log('📋 Summary:');
    console.log(`   • ${testFAQs.length} FAQ entries created`);
    console.log(`   • ${testFAQs.length} FAQ vectors created (pending vectorization)`);
    console.log(`   • ${analyticsData.length} analytics entries created`);
    console.log('');
    console.log('🔍 Next steps:');
    console.log('   • Login as a test vendor to see the FAQ management interface');
    console.log('   • The FAQs will show "Pending vectorization" until embeddings are generated');
    console.log('   • Use the Add FAQ button to create new entries');
    console.log('   • Check the Analytics tab to see usage metrics');

  } catch (error) {
    console.error('❌ Error adding test FAQ data:', error);
    throw error;
  }
}

// Run the function
addTestFAQData()
  .then(() => {
    console.log('✅ Test FAQ data addition completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error running test FAQ data addition:', error);
    process.exit(1);
  }); 