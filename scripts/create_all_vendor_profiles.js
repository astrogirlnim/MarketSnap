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

async function createAllVendorProfiles() {
  console.log('👥 Creating complete vendor profiles for all test vendors...');
  
  try {
    const vendors = [
      {
        vendorId: 'vendor-alice-organic',
        userData: {
          uid: 'vendor-alice-organic',
          displayName: 'Alice Chen',
          email: 'alice@organicfarms.com',
          phoneNumber: '+15551234001',
          userType: 'vendor',
          emailVerified: true,
        },
        vendorData: {
          businessName: 'Alice\'s Organic Farm',
          displayName: 'Alice Chen',
          email: 'alice@organicfarms.com',
          phoneNumber: '+15551234001',
          bio: 'Certified organic vegetable farmer focusing on heirloom varieties and sustainable growing practices.',
          specialties: ['organic vegetables', 'heirloom tomatoes', 'fresh herbs', 'seasonal produce'],
          marketDays: ['Wednesday', 'Saturday'],
          location: 'Central Valley Farmers Market',
          isVerified: true,
          rating: 4.9,
          totalReviews: 243,
          socialMedia: {
            instagram: '@alicesorganicfarm',
            facebook: 'Alices Organic Farm'
          },
          operatingHours: {
            wednesday: '8:00 AM - 2:00 PM',
            saturday: '7:00 AM - 3:00 PM'
          }
        }
      },
      {
        vendorId: 'vendor-carol-flowers',
        userData: {
          uid: 'vendor-carol-flowers',
          displayName: 'Carol Thompson',
          email: 'carol@seasonalblooms.com',
          phoneNumber: '+15551234003',
          userType: 'vendor',
          emailVerified: true,
        },
        vendorData: {
          businessName: 'Carol\'s Seasonal Blooms',
          displayName: 'Carol Thompson',
          email: 'carol@seasonalblooms.com',
          phoneNumber: '+15551234003',
          bio: 'Local flower farmer specializing in seasonal cut flowers and custom arrangements for special occasions.',
          specialties: ['cut flowers', 'seasonal arrangements', 'wedding bouquets', 'sunflowers'],
          marketDays: ['Friday', 'Saturday', 'Sunday'],
          location: 'Riverside Farmers Market',
          isVerified: true,
          rating: 4.7,
          totalReviews: 189,
          socialMedia: {
            instagram: '@carolsseasonalblooms',
            facebook: 'Carols Seasonal Blooms'
          },
          operatingHours: {
            friday: '9:00 AM - 1:00 PM',
            saturday: '8:00 AM - 4:00 PM',
            sunday: '9:00 AM - 2:00 PM'
          }
        }
      },
      {
        vendorId: 'vendor-dave-honey',
        userData: {
          uid: 'vendor-dave-honey',
          displayName: 'Dave Wilson',
          email: 'dave@mountainhoney.com',
          phoneNumber: '+15551234004',
          userType: 'vendor',
          emailVerified: true,
        },
        vendorData: {
          businessName: 'Dave\'s Mountain Honey',
          displayName: 'Dave Wilson',
          email: 'dave@mountainhoney.com',
          phoneNumber: '+15551234004',
          bio: 'Third-generation beekeeper producing raw, unfiltered honey from wildflower and clover sources in the mountains.',
          specialties: ['raw honey', 'wildflower honey', 'honeycomb', 'beeswax products'],
          marketDays: ['Saturday'],
          location: 'Mountain View Farmers Market',
          isVerified: true,
          rating: 4.8,
          totalReviews: 167,
          socialMedia: {
            instagram: '@davesmountainhoney',
            website: 'www.mountainhoney.com'
          },
          operatingHours: {
            saturday: '8:00 AM - 2:00 PM'
          }
        }
      },
      {
        vendorId: 'vendor-emma-cheese',
        userData: {
          uid: 'vendor-emma-cheese',
          displayName: 'Emma Rodriguez',
          email: 'emma@farmhousecheese.com',
          phoneNumber: '+15551234005',
          userType: 'vendor',
          emailVerified: true,
        },
        vendorData: {
          businessName: 'Emma\'s Farmhouse Cheese',
          displayName: 'Emma Rodriguez',
          email: 'emma@farmhousecheese.com',
          phoneNumber: '+15551234005',
          bio: 'Artisan cheesemaker crafting traditional and aged cheeses using milk from local grass-fed cows.',
          specialties: ['aged cheddar', 'fresh mozzarella', 'goat cheese', 'artisan cheese'],
          marketDays: ['Thursday', 'Saturday'],
          location: 'Heritage Farmers Market',
          isVerified: true,
          rating: 4.9,
          totalReviews: 201,
          socialMedia: {
            instagram: '@emmasfarmhousecheese',
            facebook: 'Emmas Farmhouse Cheese'
          },
          operatingHours: {
            thursday: '10:00 AM - 3:00 PM',
            saturday: '9:00 AM - 4:00 PM'
          }
        }
      },
      {
        vendorId: 'vendor-frank-coffee',
        userData: {
          uid: 'vendor-frank-coffee',
          displayName: 'Frank Davis',
          email: 'frank@mountainroast.com',
          phoneNumber: '+15551234006',
          userType: 'vendor',
          emailVerified: true,
        },
        vendorData: {
          businessName: 'Frank\'s Mountain Roast',
          displayName: 'Frank Davis',
          email: 'frank@mountainroast.com',
          phoneNumber: '+15551234006',
          bio: 'Small-batch coffee roaster specializing in single-origin beans and custom roast profiles.',
          specialties: ['single-origin coffee', 'custom roasts', 'espresso blends', 'cold brew'],
          marketDays: ['Saturday', 'Sunday'],
          location: 'Downtown Coffee Market',
          isVerified: true,
          rating: 4.6,
          totalReviews: 134,
          socialMedia: {
            instagram: '@franksmountainroast',
            website: 'www.mountainroast.com'
          },
          operatingHours: {
            saturday: '7:00 AM - 3:00 PM',
            sunday: '8:00 AM - 2:00 PM'
          }
        }
      }
    ];

    let createdCount = 0;
    let updatedCount = 0;

    for (const vendor of vendors) {
      console.log(`\n👤 Processing ${vendor.vendorData.businessName}...`);
      
      // Check if user document exists
      const userRef = db.collection('users').doc(vendor.vendorId);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        // Create user document
        const userData = {
          ...vendor.userData,
          createdAt: admin.firestore.Timestamp.now(),
          lastLoginAt: admin.firestore.Timestamp.now(),
          isActive: true
        };
        
        await userRef.set(userData);
        console.log(`  ✅ Created user document`);
        createdCount++;
      } else {
        console.log(`  ℹ️  User document already exists`);
      }
      
      // Check if vendor profile exists
      const vendorRef = db.collection('vendorProfiles').doc(vendor.vendorId);
      const vendorDoc = await vendorRef.get();
      
      if (!vendorDoc.exists) {
        // Create vendor profile
        const vendorData = {
          vendorId: vendor.vendorId,
          ...vendor.vendorData,
          createdAt: admin.firestore.Timestamp.now(),
          updatedAt: admin.firestore.Timestamp.now(),
          isActive: true,
          profilePictureUrl: null,
          coverImageUrl: null
        };
        
        await vendorRef.set(vendorData);
        console.log(`  ✅ Created vendor profile`);
        createdCount++;
      } else {
        // Update existing vendor profile
        const vendorData = {
          vendorId: vendor.vendorId,
          ...vendor.vendorData,
          updatedAt: admin.firestore.Timestamp.now(),
          isActive: true
        };
        
        await vendorRef.update(vendorData);
        console.log(`  🔄 Updated vendor profile`);
        updatedCount++;
      }
    }

    console.log('\n🔍 Verification:');
    for (const vendor of vendors) {
      const userExists = (await db.collection('users').doc(vendor.vendorId).get()).exists;
      const vendorExists = (await db.collection('vendorProfiles').doc(vendor.vendorId).get()).exists;
      
      console.log(`${vendor.vendorData.businessName}: User ${userExists ? '✅' : '❌'}, Profile ${vendorExists ? '✅' : '❌'}`);
    }

    console.log('\n🎉 All vendor profiles processed successfully!');
    console.log('\n📝 Summary:');
    console.log(`   • Created: ${createdCount} new documents`);
    console.log(`   • Updated: ${updatedCount} existing profiles`);
    console.log(`   • Total vendors: ${vendors.length}`);
    
  } catch (error) {
    console.error('❌ Error creating vendor profiles:', error);
    process.exit(1);
  }
}

createAllVendorProfiles()
  .then(() => {
    console.log('\n🏁 Script completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Script failed:', error);
    process.exit(1);
  }); 