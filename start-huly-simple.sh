#!/bin/bash

# Simplified Huly Platform Development Startup Script
# This script starts just the essential services for development

set -e

echo "🚀 Starting Huly Platform Development Environment (Simplified)"
echo "=============================================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to wait for service
wait_for_port() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    echo "Waiting for $service_name on port $port..."
    while [ $attempt -lt $max_attempts ]; do
        if lsof -i:$port >/dev/null 2>&1; then
            print_status "$service_name is ready on port $port"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start on port $port"
    return 1
}

# Cleanup function
cleanup() {
    echo ""
    print_warning "Shutting down services..."
    jobs -p | xargs -r kill 2>/dev/null || true
    docker stop huly-mongo huly-minio huly-kafka 2>/dev/null || true
    docker rm huly-mongo huly-minio huly-kafka 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Create logs directory
mkdir -p logs

echo ""
echo "🐳 Starting infrastructure services..."

# Clean up existing containers
docker stop huly-mongo huly-minio huly-kafka 2>/dev/null || true
docker rm huly-mongo huly-minio huly-kafka 2>/dev/null || true

# Start MongoDB
print_status "Starting MongoDB..."
docker run -d --name huly-mongo -p 27017:27017 mongo:7.0 >/dev/null

# Start MinIO
print_status "Starting MinIO..."
docker run -d --name huly-minio \
    -p 9000:9000 -p 9001:9001 \
    -e "MINIO_ACCESS_KEY=minioadmin" \
    -e "MINIO_SECRET_KEY=minioadmin" \
    minio/minio server /data --console-address ":9001" >/dev/null

# Start Kafka (KRaft mode - no Zookeeper needed)
print_status "Starting Kafka..."
docker run -d --name huly-kafka \
    -p 9092:9092 \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
    -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
    apache/kafka:latest >/dev/null 2>&1 || {
        echo "⚠️  Kafka failed to start, trying Confluent image..."
        docker rm -f huly-kafka 2>/dev/null || true
        docker run -d --name huly-kafka \
            -p 9092:9092 \
            -e KAFKA_BROKER_ID=1 \
            -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
            -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
            -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
            -e KAFKA_AUTO_CREATE_TOPICS_ENABLE=true \
            confluentinc/cp-kafka:latest >/dev/null 2>&1 || {
                echo "❌ Could not start Kafka, continuing without it..."
                # Continue without Kafka for now
            }
    }

# Wait for infrastructure
wait_for_port 27017 "MongoDB"
wait_for_port 9000 "MinIO"

# Try to wait for Kafka, but don't fail if it's not available
if docker ps | grep -q huly-kafka; then
    wait_for_port 9092 "Kafka" || echo "⚠️  Kafka not ready, continuing anyway..."
fi

echo ""
echo "⚙️ Starting backend services..."

# Start Account Service (simplified, no MAIL_URL = auto-confirm emails)
print_status "Starting Account Service..."
cd pods/account
ACCOUNT_PORT=3000 \
DB_URL="mongodb://localhost:27017" \
MONGO_URL="mongodb://localhost:27017" \
SERVER_SECRET="secret" \
TRANSACTOR_URL="ws://localhost:3333" \
FRONT_URL="http://localhost:8080" \
ACCOUNTS_URL="http://localhost:3000" \
MINIO_ENDPOINT="localhost" \
MINIO_ACCESS_KEY="minioadmin" \
MINIO_SECRET_KEY="minioadmin" \
DISABLE_SIGNUP="false" \
node bundle/bundle.js > ../../logs/account.log 2>&1 &

ACCOUNT_PID=$!
cd ../..

# Wait a bit for account service
sleep 5
wait_for_port 3000 "Account Service"

# Start Server Service (minimal config)
print_status "Starting Transactor Service..."
cd pods/server
SERVER_PORT=3333 \
DB_URL="mongodb://localhost:27017" \
MONGO_URL="mongodb://localhost:27017" \
SERVER_SECRET="secret" \
ACCOUNTS_URL="http://localhost:3000" \
FRONT_URL="http://localhost:8080" \
STORAGE_CONFIG="minio|localhost?accessKey=minioadmin&secretKey=minioadmin" \
MODEL_JSON="../../models/all/bundle/model.json" \
QUEUE_CONFIG="localhost:9092" \
FULLTEXT_URL="http://localhost:9200" \
ELASTIC_INDEX_NAME="huly_storage_index" \
REKONI_URL="http://localhost:4004" \
UPLOAD_URL="/files" \
node bundle/bundle.js > ../../logs/server.log 2>&1 &

SERVER_PID=$!
cd ../..

# Wait for server service
sleep 5
wait_for_port 3333 "Transactor Service"

echo ""
echo "🌐 Starting frontend development server..."

# Start Frontend
cd dev/prod
print_status "Starting Frontend Dev Server..."
rushx dev-server > ../../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ../..

# Wait for frontend
wait_for_port 8080 "Frontend Dev Server"

echo ""
echo "👥 Setting up development accounts..."
./create-dev-users.sh 2>/dev/null || echo "⚠️  Could not create dev accounts (may already exist)"

echo ""
echo "🎉 Huly Platform Development Environment Ready!"
echo "=============================================="
echo ""
echo "📱 Frontend Application: http://localhost:8080"
echo "🔧 Account Service:      http://localhost:3000"
echo "⚙️  Transactor Service:   ws://localhost:3333"
echo "💾 MongoDB:              mongodb://localhost:27017"
echo "📦 MinIO Console:        http://localhost:9001 (minioadmin/minioadmin)"
echo "🚀 Kafka Broker:         localhost:9092"
echo ""
echo "👤 Development Accounts:"
echo "   admin@huly.local / admin123 (Admin)"
echo "   dev@huly.local / dev123"
echo "   test@huly.local / test123"
echo ""
echo "📊 Service PIDs:"
echo "  Account:    $ACCOUNT_PID"
echo "  Transactor: $SERVER_PID"
echo "  Frontend:   $FRONTEND_PID"
echo ""
echo "📄 View logs:"
echo "  tail -f logs/account.log"
echo "  tail -f logs/server.log"
echo "  tail -f logs/frontend.log"
echo ""
echo "🛑 Press Ctrl+C to stop all services"

# Wait for user to stop
wait 