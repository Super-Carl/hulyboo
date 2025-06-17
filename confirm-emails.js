#!/usr/bin/env node

// Utility script to manually confirm all unverified emails in development
// This bypasses the email verification requirement for local development

const { MongoClient } = require('mongodb');

const MONGO_URL = 'mongodb://localhost:27017';
const DB_NAME = 'global-account';

async function confirmAllEmails() {
  console.log('🔧 Confirming all unverified emails in development database...');
  
  const client = new MongoClient(MONGO_URL);
  
  try {
    await client.connect();
    console.log('✓ Connected to MongoDB');
    
    const db = client.db(DB_NAME);
    const socialIdCollection = db.collection('socialId');
    
    // Find all unverified email social IDs
    const unverifiedEmails = await socialIdCollection.find({
      type: 'EMAIL',
      verifiedOn: null
    }).toArray();
    
    console.log(`📧 Found ${unverifiedEmails.length} unverified email(s)`);
    
    if (unverifiedEmails.length === 0) {
      console.log('✅ No emails need confirmation');
      return;
    }
    
    // Confirm all unverified emails
    const result = await socialIdCollection.updateMany(
      {
        type: 'EMAIL',
        verifiedOn: null
      },
      {
        $set: {
          verifiedOn: Date.now()
        }
      }
    );
    
    console.log(`✅ Confirmed ${result.modifiedCount} email(s)`);
    
    // List the confirmed emails
    for (const email of unverifiedEmails) {
      console.log(`   - ${email.value}`);
    }
    
    console.log('');
    console.log('🎉 Email confirmation complete!');
    console.log('   You can now proceed with account creation/login.');
    
  } catch (error) {
    console.error('❌ Error confirming emails:', error.message);
  } finally {
    await client.close();
  }
}

// Run the script
confirmAllEmails().catch(console.error); 