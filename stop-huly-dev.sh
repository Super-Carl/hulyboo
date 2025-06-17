#!/bin/bash

# Huly Platform Development Stop Script
# This script stops all running Huly development services

echo "🛑 Stopping Huly Platform Development Environment"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to kill process on port
kill_port() {
    local port=$1
    local service_name=$2
    local pids=$(lsof -ti:$port 2>/dev/null)
    if [ ! -z "$pids" ]; then
        print_warning "Stopping $service_name on port $port (PIDs: $pids)"
        kill -15 $pids 2>/dev/null || true
        sleep 2
        # Force kill if still running
        pids=$(lsof -ti:$port 2>/dev/null)
        if [ ! -z "$pids" ]; then
            kill -9 $pids 2>/dev/null || true
            print_status "$service_name force stopped"
        else
            print_status "$service_name stopped gracefully"
        fi
    else
        print_status "$service_name was not running on port $port"
    fi
}

echo ""
echo "📱 Stopping Frontend Development Server..."
kill_port 8080 "Frontend Dev Server"

echo ""
echo "⚙️ Stopping Backend Services..."
kill_port 3000 "Account Service"
kill_port 3333 "Transactor Service"

echo ""
echo "🐳 Stopping Infrastructure Services..."

# Stop Docker containers
if docker ps -q --filter "name=huly-mongo" | grep -q .; then
    print_warning "Stopping MongoDB container..."
    docker stop huly-mongo >/dev/null 2>&1
    docker rm huly-mongo >/dev/null 2>&1
    print_status "MongoDB container stopped and removed"
else
    print_status "MongoDB container was not running"
fi

if docker ps -q --filter "name=huly-minio" | grep -q .; then
    print_warning "Stopping MinIO container..."
    docker stop huly-minio >/dev/null 2>&1
    docker rm huly-minio >/dev/null 2>&1
    print_status "MinIO container stopped and removed"
else
    print_status "MinIO container was not running"
fi

# Clean up any remaining Huly-related processes
echo ""
echo "🧹 Cleaning up remaining processes..."
pkill -f "bundle.js" 2>/dev/null || true
pkill -f "rushx dev-server" 2>/dev/null || true

echo ""
echo "✅ Huly Platform Development Environment Stopped"
echo "==============================================="
echo ""
echo "All services have been stopped and containers removed."
echo "You can restart the environment by running: ./start-huly-dev.sh"
echo "" 