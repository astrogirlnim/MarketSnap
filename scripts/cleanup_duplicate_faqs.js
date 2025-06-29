#!/usr/bin/env node

// Set environment variables for emulator
process.env.GOOGLE_APPLICATION_CREDENTIALS = '';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

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

async function cleanupAndFix() {
  console.log('🧹 Starting cleanup and profile fix...');
  
  try {
    // === STEP 1: Clean up duplicate FAQs ===
    console.log('\n📋 Step 1: Cleaning up duplicate FAQs...');
    
    const faqsRef = db.collection('faqs');
    const snapshot = await faqsRef.get();
    
    console.log(`Found ${snapshot.size} total FAQs`);
    
    const questionGroups = {};
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const key = `${data.question}_${data.vendorId}`;
      
      if (!questionGroups[key]) {
        questionGroups[key] = [];
      }
      questionGroups[key].push({id: doc.id, data});
    });
    
    // Delete duplicates (keep first, delete rest)
    let deletedCount = 0;
    const batch = db.batch();
    
    for (const [key, docs] of Object.entries(questionGroups)) {
      if (docs.length > 1) {
        console.log(`  🗑️  Removing ${docs.length - 1} duplicates for: "${docs[0].data.question.substring(0, 50)}..."`);
        
        // Delete all but the first one
        for (let i = 1; i < docs.length; i++) {
          batch.delete(faqsRef.doc(docs[i].id));
          deletedCount++;
        }
      }
    }
    
    if (deletedCount > 0) {
      await batch.commit();
      console.log(`✅ Deleted ${deletedCount} duplicate FAQs`);
    } else {
      console.log('ℹ️  No duplicates found to delete');
    }
    
    // === STEP 2: Create Bob's vendor profile ===
    console.log('\n👤 Step 2: Creating Bob\'s vendor profile...');
    
    // Create Bob's user document
    const bobUserData = {
      uid: 'vendor-bob-bakery',
      displayName: 'Bob Martinez',
      email: 'bob@artisanbread.com',
      phoneNumber: '+15551234002',
      userType: 'vendor',
      emailVerified: true,
      createdAt: admin.firestore.Timestamp.now(),
      lastLoginAt: admin.firestore.Timestamp.now(),
      isActive: true
    };
    
    await db.collection('users').doc('vendor-bob-bakery').set(bobUserData);
    console.log('✅ Created Bob\'s user document');
    
    // Create Bob's vendor profile
    const bobVendorData = {
      vendorId: 'vendor-bob-bakery',
      businessName: 'Bob\'s Artisan Bakery',
      displayName: 'Bob Martinez',
      email: 'bob@artisanbread.com',
      phoneNumber: '+15551234002',
      bio: 'Master baker specializing in sourdough and artisan breads using traditional methods.',
      specialties: ['sourdough', 'artisan bread', 'pastries', 'custom orders'],
      marketDays: ['Saturday', 'Sunday'],
      location: 'Downtown Farmers Market',
      isVerified: true,
      rating: 4.8,
      totalReviews: 156,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      isActive: true,
      profilePictureUrl: null,
      coverImageUrl: null,
      socialMedia: {
        instagram: '@bobsartisanbakery',
        facebook: 'Bob\'s Artisan Bakery'
      },
      operatingHours: {
        saturday: '7:00 AM - 2:00 PM',
        sunday: '8:00 AM - 1:00 PM'
      }
    };
    
    await db.collection('vendorProfiles').doc('vendor-bob-bakery').set(bobVendorData);
    console.log('✅ Created Bob\'s vendor profile');
    
    // === STEP 3: Verify fixes ===
    console.log('\n🔍 Step 3: Verifying fixes...');
    
    // Check FAQ count
    const newSnapshot = await faqsRef.get();
    console.log(`📊 Total FAQs after cleanup: ${newSnapshot.size}`);
    
    // Check Bob's account
    const bobUser = await db.collection('users').doc('vendor-bob-bakery').get();
    const bobVendor = await db.collection('vendorProfiles').doc('vendor-bob-bakery').get();
    
    console.log(`👤 Bob's user document exists: ${bobUser.exists ? '✅ YES' : '❌ NO'}`);
    console.log(`🏪 Bob's vendor profile exists: ${bobVendor.exists ? '✅ YES' : '❌ NO'}`);
    
    console.log('\n🎉 All fixes applied successfully!');
    console.log('\n📝 Summary:');
    console.log(`   • Removed ${deletedCount} duplicate FAQs`);
    console.log(`   • Created Bob's user and vendor profiles`);
    console.log(`   • Total FAQs now: ${newSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

cleanupAndFix()
  .then(() => {
    console.log('\n🏁 Script completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Script failed:', error);
    process.exit(1);
  }); 