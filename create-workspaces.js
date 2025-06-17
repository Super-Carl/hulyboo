#!/usr/bin/env node

// Development Workspace Creation Script
// Creates workspaces for each development account

const ACCOUNT_URL = 'http://localhost:3000';

// Development accounts and their workspace names
const DEV_ACCOUNTS = [
  {
    email: 'admin@huly.local',
    password: 'admin123',
    workspaceName: 'Admin Workspace'
  },
  {
    email: 'dev@huly.local', 
    password: 'dev123',
    workspaceName: 'Development Workspace'
  },
  {
    email: 'test@huly.local',
    password: 'test123',
    workspaceName: 'Test Workspace'
  }
];

// Function to make RPC calls to account service
async function rpcCall(method, params = {}) {
  try {
    const response = await fetch(ACCOUNT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        method,
        params
      })
    });

    const result = await response.json();
    
    if (result.error) {
      throw new Error(`RPC Error: ${result.error.message || result.error}`);
    }
    
    return result.result;
  } catch (error) {
    console.error(`Failed to call ${method}:`, error.message);
    throw error;
  }
}

// Function to make authenticated RPC calls
async function authenticatedRpcCall(token, method, params = {}) {
  try {
    const response = await fetch(ACCOUNT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        method,
        params
      })
    });

    const result = await response.json();
    
    if (result.error) {
      throw new Error(`RPC Error: ${result.error.message || result.error}`);
    }
    
    return result.result;
  } catch (error) {
    console.error(`Failed to call ${method}:`, error.message);
    throw error;
  }
}

async function createWorkspaceForAccount(account) {
  console.log(`\n👤 Processing account: ${account.email}`);
  
  try {
    // Step 1: Login to get token
    console.log('  🔐 Logging in...');
    const loginResult = await rpcCall('login', {
      email: account.email,
      password: account.password
    });
    
    if (!loginResult.token) {
      throw new Error('No token received from login');
    }
    
    console.log('  ✅ Login successful');
    
    // Step 2: Check if user already has workspaces
    console.log('  📋 Checking existing workspaces...');
    const workspaces = await authenticatedRpcCall(loginResult.token, 'getUserWorkspaces');
    
    if (workspaces && workspaces.length > 0) {
      console.log(`  ⚠️  Account already has ${workspaces.length} workspace(s)`);
      console.log(`     Workspaces: ${workspaces.map(w => w.workspaceName || w.workspace).join(', ')}`);
      return;
    }
    
    // Step 3: Create workspace
    console.log(`  🏗️  Creating workspace: "${account.workspaceName}"...`);
    const workspaceResult = await authenticatedRpcCall(loginResult.token, 'createWorkspace', {
      name: account.workspaceName
    });
    
    console.log('  ✅ Workspace created successfully');
    console.log(`     Workspace ID: ${workspaceResult.workspaceId || workspaceResult.workspace}`);
    
  } catch (error) {
    console.log(`  ❌ Failed to create workspace: ${error.message}`);
    
    // Try to get more details about the error
    if (error.message.includes('RPC Error')) {
      console.log(`     This might be due to service configuration issues.`);
    }
  }
}

async function main() {
  console.log('🚀 Creating workspaces for development accounts...');
  console.log('====================================================');
  
  // Check if account service is available
  try {
    await fetch(ACCOUNT_URL);
  } catch (error) {
    console.error('❌ Account service is not available!');
    console.error('💡 Please ensure the development environment is running: ./start-huly-simple.sh');
    process.exit(1);
  }
  
  for (const account of DEV_ACCOUNTS) {
    await createWorkspaceForAccount(account);
    
    // Small delay between accounts
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  console.log('\n🎉 Workspace creation process complete!');
  console.log('\n📋 Summary:');
  console.log('==========');
  DEV_ACCOUNTS.forEach(account => {
    console.log(`👤 ${account.email}`);
    console.log(`   Workspace: "${account.workspaceName}"`);
  });
  
  console.log('\n🌐 You can now access workspaces at: http://localhost:8080');
}

// Handle fetch for Node.js environments that don't have it built-in
if (typeof fetch === 'undefined') {
  console.log('Installing fetch for Node.js...');
  const { default: fetch } = await import('node-fetch');
  global.fetch = fetch;
}

main().catch(console.error); 