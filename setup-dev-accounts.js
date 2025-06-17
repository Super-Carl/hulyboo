#!/usr/bin/env node

// Development Account Setup Script
// Creates pre-verified accounts for easy local development access

const MONGO_URL = 'mongodb://localhost:27017';
const DB_NAME = 'account';

// Development accounts to create
const DEV_ACCOUNTS = [
  {
    email: 'admin@huly.local',
    password: 'admin123',
    firstName: 'Admin',
    lastName: 'User',
    isAdmin: true
  },
  {
    email: 'dev@huly.local', 
    password: 'dev123',
    firstName: 'Developer',
    lastName: 'User',
    isAdmin: false
  },
  {
    email: 'test@huly.local',
    password: 'test123', 
    firstName: 'Test',
    lastName: 'User',
    isAdmin: false
  }
];

async function setupDevAccounts() {
  console.log('🚀 Setting up development accounts...');
  
  // Use Docker to run the setup commands
  console.log('📧 Creating pre-verified accounts using MongoDB...');
  
  for (const account of DEV_ACCOUNTS) {
    console.log(`\n👤 Creating account: ${account.email}`);
    
    // Generate UUIDs (simple version for development)
    const accountUuid = generateSimpleUuid();
    const personUuid = generateSimpleUuid();
    const socialIdUuid = generateSimpleUuid();
    
    // Hash password (simple version - in real implementation this would use proper bcrypt)
    const hashedPassword = Buffer.from(account.password).toString('base64');
    
    const mongoCommands = `
      // Create person record
      db.person.insertOne({
        _id: "${personUuid}",
        uuid: "${personUuid}",
        firstName: "${account.firstName}",
        lastName: "${account.lastName}",
        active: true,
        createdOn: ${Date.now()}
      });
      
      // Create social ID (email) record - PRE-VERIFIED
      db.socialId.insertOne({
        _id: "${socialIdUuid}",
        type: "EMAIL",
        key: "email:${account.email}",
        value: "${account.email}",
        personUuid: "${personUuid}",
        verifiedOn: ${Date.now()},
        createdOn: ${Date.now()}
      });
      
      // Create account record
      db.account.insertOne({
        _id: "${accountUuid}",
        uuid: "${accountUuid}",
        email: "${account.email}",
        hash: "${hashedPassword}",
        salt: "dev-salt",
        first: "${account.firstName}",
        last: "${account.lastName}",
        confirmed: true,
        createdOn: ${Date.now()}
      });
      
      print("✓ Created account: ${account.email}");
    `;
    
    // Execute the MongoDB commands
    try {
      const { execSync } = require('child_process');
      execSync(`docker exec huly-mongo mongosh ${DB_NAME} --eval '${mongoCommands.replace(/\n/g, ' ')}'`, 
        { stdio: 'pipe' });
      console.log(`  ✅ Account ${account.email} created successfully`);
    } catch (error) {
      console.log(`  ❌ Failed to create ${account.email}: ${error.message}`);
    }
  }
  
  console.log('\n🎉 Development accounts setup complete!');
  console.log('\n📋 Available accounts:');
  console.log('================================');
  
  DEV_ACCOUNTS.forEach(account => {
    console.log(`👤 ${account.email}`);
    console.log(`   Password: ${account.password}`);
    console.log(`   Name: ${account.firstName} ${account.lastName}`);
    console.log(`   Admin: ${account.isAdmin ? 'Yes' : 'No'}`);
    console.log('');
  });
  
  console.log('🌐 You can now login at: http://localhost:8080');
  console.log('💡 Use any of the above email/password combinations');
}

function generateSimpleUuid() {
  // Simple UUID generator for development (not cryptographically secure)
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Check if MongoDB container is running
function checkMongoDB() {
  try {
    const { execSync } = require('child_process');
    execSync('docker exec huly-mongo mongosh --eval "db.runCommand({ping: 1})" --quiet', { stdio: 'pipe' });
    return true;
  } catch (error) {
    return false;
  }
}

// Main execution
if (!checkMongoDB()) {
  console.error('❌ MongoDB container (huly-mongo) is not running!');
  console.error('💡 Please run: ./start-huly-simple.sh first');
  process.exit(1);
}

setupDevAccounts().catch(console.error); 