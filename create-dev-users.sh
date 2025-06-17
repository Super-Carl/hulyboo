#!/bin/bash

# Development User Creation Script using Huly Account API
# This ensures users are created with proper authentication flow

echo "👥 Creating development users via Huly Account API..."

ACCOUNT_URL="http://localhost:3000"

# Function to create a user via API
create_user() {
  local email=$1
  local password=$2
  local firstName=$3
  local lastName=$4
  
  echo "Creating user: $email"
  
  # Create signup request using RPC method
  curl -s -X POST "$ACCOUNT_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"signUp\",
      \"params\": {
        \"email\": \"$email\",
        \"password\": \"$password\",
        \"firstName\": \"$firstName\",
        \"lastName\": \"$lastName\"
      }
    }" > /dev/null
  
  if [ $? -eq 0 ]; then
    echo "  ✅ User $email created successfully"
  else
    echo "  ⚠️  User $email may already exist or API error"
  fi
}

# Wait for account service to be ready
echo "Waiting for account service..."
for i in {1..30}; do
  if curl -s "$ACCOUNT_URL/health" > /dev/null 2>&1 || curl -s "$ACCOUNT_URL" > /dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Create development users
create_user "admin@huly.local" "admin123" "Admin" "User"
create_user "dev@huly.local" "dev123" "Developer" "User"  
create_user "test@huly.local" "test123" "Test" "User"

echo ""
echo "🎉 Development users setup complete!"
echo ""
echo "📋 Available accounts:"
echo "👤 admin@huly.local / admin123"
echo "👤 dev@huly.local / dev123" 
echo "👤 test@huly.local / test123"
echo ""
echo "🌐 Login at: http://localhost:8080" 