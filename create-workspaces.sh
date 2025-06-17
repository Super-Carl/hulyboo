#!/bin/bash

# Development Workspace Creation Script using curl
# Creates workspaces for each development account

ACCOUNT_URL="http://localhost:3000"

echo "🚀 Creating workspaces for development accounts..."
echo "===================================================="

# Function to create workspace for an account
create_workspace() {
  local email=$1
  local password=$2
  local workspace_name=$3
  
  echo ""
  echo "👤 Processing account: $email"
  
  # Step 1: Login to get token
  echo "  🔐 Logging in..."
  login_response=$(curl -s -X POST "$ACCOUNT_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"login\",
      \"params\": {
        \"email\": \"$email\",
        \"password\": \"$password\"
      }
    }")
  
  # Extract token from response
  token=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$token" ]; then
    echo "  ❌ Login failed"
    return 1
  fi
  
  echo "  ✅ Login successful"
  
  # Step 2: Check existing workspaces
  echo "  📋 Checking existing workspaces..."
  workspaces_response=$(curl -s -X POST "$ACCOUNT_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "{
      \"method\": \"getUserWorkspaces\",
      \"params\": {}
    }")
  
  # Check if user has workspaces (simple check)
  if echo "$workspaces_response" | grep -q '"result":\[.*\]' && ! echo "$workspaces_response" | grep -q '"result":\[\]'; then
    echo "  ⚠️  Account already has workspace(s)"
    return 0
  fi
  
  # Step 3: Create workspace
  echo "  🏗️  Creating workspace: \"$workspace_name\"..."
  workspace_response=$(curl -s -X POST "$ACCOUNT_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "{
      \"method\": \"createWorkspace\",
      \"params\": {
        \"workspaceName\": \"$workspace_name\",
        \"region\": \"huly\"
      }
    }")
  
  if echo "$workspace_response" | grep -q '"result"'; then
    echo "  ✅ Workspace created successfully"
    # Extract workspace info if available
    workspace_id=$(echo "$workspace_response" | grep -o '"workspace":"[^"]*"' | cut -d'"' -f4)
    if [ ! -z "$workspace_id" ]; then
      echo "     Workspace ID: $workspace_id"
    fi
  else
    echo "  ❌ Failed to create workspace"
    echo "     Response: $workspace_response"
  fi
}

# Check if account service is available
if ! curl -s "$ACCOUNT_URL" > /dev/null 2>&1; then
  echo "❌ Account service is not available!"
  echo "💡 Please ensure the development environment is running: ./start-huly-simple.sh"
  exit 1
fi

# Create workspaces for each account
create_workspace "admin@huly.local" "admin123" "Admin Workspace"
sleep 2

create_workspace "dev@huly.local" "dev123" "Development Workspace"
sleep 2

create_workspace "test@huly.local" "test123" "Test Workspace"

echo ""
echo "🎉 Workspace creation process complete!"
echo ""
echo "📋 Summary:"
echo "=========="
echo "👤 admin@huly.local"
echo "   Workspace: \"Admin Workspace\""
echo "👤 dev@huly.local"
echo "   Workspace: \"Development Workspace\""
echo "👤 test@huly.local"
echo "   Workspace: \"Test Workspace\""
echo ""
echo "🌐 You can now access workspaces at: http://localhost:8080" 