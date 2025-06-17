#!/bin/bash

# Huly Platform Development Startup Script
# This script sets up and starts all required services for local development

set -e  # Exit on any error

echo "🚀 Starting Huly Platform Development Environment"
echo "================================================="

# Change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if a port is in use
check_port() {
    if lsof -i:$1 >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to kill process on port
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port)
    if [ ! -z "$pids" ]; then
        echo "Killing processes on port $port: $pids"
        kill -9 $pids 2>/dev/null || true
        sleep 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    echo "Waiting for $service_name on port $port..."
    while [ $attempt -lt $max_attempts ]; do
        if check_port $port; then
            print_status "$service_name is ready on port $port"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start on port $port"
    return 1
}

# Function to cleanup on exit
cleanup() {
    echo ""
    print_warning "Shutting down services..."
    
    # Kill background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Kill specific ports
    kill_port 3000  # Account service
    kill_port 3333  # Transactor service
    kill_port 8080  # Frontend dev server
    
    # Stop infrastructure containers
    docker stop huly-mongo huly-minio huly-kafka 2>/dev/null || true
    
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Step 1: Check prerequisites
echo ""
echo "📋 Checking prerequisites..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
print_status "Docker is running"

# Check if Node.js is available
if ! command -v node >/dev/null 2>&1; then
    print_error "Node.js is not installed. Please install Node.js and try again."
    exit 1
fi
print_status "Node.js is available: $(node --version)"

# Check if project is built
if [ ! -f "pods/account/bundle/bundle.js" ] || [ ! -f "pods/server/bundle/bundle.js" ]; then
    print_warning "Project bundles not found. Building project..."
    rush build
    rush bundle
fi
print_status "Project bundles are ready"

# Step 2: Start infrastructure services
echo ""
echo "🐳 Starting infrastructure services..."

# Stop and remove existing containers
docker stop huly-mongo huly-minio huly-kafka 2>/dev/null || true
docker rm huly-mongo huly-minio huly-kafka 2>/dev/null || true
# Also clean up any other containers that might conflict
docker stop minio 2>/dev/null || true
docker rm minio 2>/dev/null || true

# Start MongoDB
print_status "Starting MongoDB..."
docker run -d --name huly-mongo \
    -p 27017:27017 \
    mongo:7.0 >/dev/null

# Start MinIO
print_status "Starting MinIO..."
docker run -d --name huly-minio \
    -p 9000:9000 -p 9001:9001 \
    -e "MINIO_ACCESS_KEY=minioadmin" \
    -e "MINIO_SECRET_KEY=minioadmin" \
    minio/minio server /data --console-address ":9001" >/dev/null

# Start Kafka (required for workspace service)
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
        print_warning "Kafka failed to start, trying Confluent image..."
        docker rm -f huly-kafka 2>/dev/null || true
        docker run -d --name huly-kafka \
            -p 9092:9092 \
            -e KAFKA_BROKER_ID=1 \
            -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
            -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
            -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
            -e KAFKA_AUTO_CREATE_TOPICS_ENABLE=true \
            confluentinc/cp-kafka:latest >/dev/null 2>&1 || {
                print_error "Could not start Kafka. Workspace initialization will not work."
                exit 1
            }
    }

# Wait for infrastructure to be ready
wait_for_service 27017 "MongoDB"
wait_for_service 9000 "MinIO"
wait_for_service 9092 "Kafka"

# Step 3: Start backend services
echo ""
echo "⚙️ Starting backend services..."

# Environment variables for all services
export MONGO_URL="mongodb://localhost:27017"
export DB_URL="mongodb://localhost:27017" 
export SERVER_SECRET="secret"
export MINIO_ENDPOINT="localhost"
export MINIO_ACCESS_KEY="minioadmin"
export MINIO_SECRET_KEY="minioadmin"
export STORAGE_CONFIG="minio|localhost?accessKey=minioadmin&secretKey=minioadmin"
export ACCOUNTS_URL="http://localhost:3000"
export FRONT_URL="http://localhost:8080"
export TRANSACTOR_URL="ws://localhost:3333"
export MODEL_JSON="$(pwd)/models/all/bundle/model.json"
export QUEUE_CONFIG="localhost:9092"
export REGION_INFO="huly|Huly Platform"

# Create logs directory first
mkdir -p logs

# Kill any existing backend services
kill_port 3000
kill_port 3333

# Start Account Service
print_status "Starting Account Service on port 3000..."
cd pods/account
ACCOUNT_PORT=3000 node bundle/bundle.js > ../../logs/account.log 2>&1 &
ACCOUNT_PID=$!
cd ../..

# Start Transactor Service  
print_status "Starting Transactor Service on port 3333..."
cd pods/server
SERVER_PORT=3333 \
UPLOAD_URL="/files" \
FULLTEXT_URL="" \
ELASTIC_INDEX_NAME="local_storage_index" \
REKONI_URL="" \
node bundle/bundle.js > ../../logs/server.log 2>&1 &
SERVER_PID=$!
cd ../..

# Start Workspace Service (processes workspace creation)
print_status "Starting Workspace Service..."
cd pods/workspace
WS_OPERATION="all" \
node bundle/bundle.js > ../../logs/workspace.log 2>&1 &
WORKSPACE_PID=$!
cd ../..

# Wait for backend services to start
wait_for_service 3000 "Account Service"
wait_for_service 3333 "Transactor Service"
sleep 3  # Give workspace service time to initialize

# Step 4: Start frontend development server
echo ""
echo "🌐 Starting frontend development server..."

# Kill any existing frontend service
kill_port 8080

# Start frontend dev server
cd dev/prod
print_status "Starting Frontend Dev Server on port 8080..."
rushx dev-server > ../../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ../..

# Wait for frontend to be ready
wait_for_service 8080 "Frontend Dev Server"

# Step 5: Setup complete
echo ""
echo "🎉 Huly Platform Development Environment Ready!"
echo "=============================================="
echo ""
echo "📱 Frontend Application: http://localhost:8080"
echo "🔧 Account Service:      http://localhost:3000" 
echo "⚙️  Transactor Service:   ws://localhost:3333"
echo "🏗️  Workspace Service:   (background)"
echo "💾 MongoDB:              mongodb://localhost:27017"
echo "📦 MinIO Console:        http://localhost:9001 (minioadmin/minioadmin)"
echo "🚀 Kafka Broker:         localhost:9092"
echo ""
echo "📊 Service Status:"
echo "  Account Service PID:    $ACCOUNT_PID"
echo "  Transactor Service PID: $SERVER_PID" 
echo "  Workspace Service PID:  $WORKSPACE_PID"
echo "  Frontend Server PID:    $FRONTEND_PID"
echo ""
echo "📄 Logs are available in:"
echo "  Account:    logs/account.log"
echo "  Transactor: logs/server.log"
echo "  Workspace:  logs/workspace.log"
echo "  Frontend:   logs/frontend.log"
echo ""
echo "🛑 Press Ctrl+C to stop all services"
echo ""

# Create logs directory
mkdir -p logs

# Wait for user to stop services
wait 