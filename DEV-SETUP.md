# Huly Platform - Development Setup

## Quick Start

🚀 **One-command setup**: Just run the startup script to get everything running:

```bash
./start-huly-dev.sh
```

🛑 **Stop all services**:

```bash
./stop-huly-dev.sh
```

## What the Scripts Do

### `start-huly-dev.sh`

This script automatically:

1. **Checks Prerequisites**

   - Verifies Docker is running
   - Verifies Node.js is installed
   - Ensures project bundles are built

2. **Starts Infrastructure Services**

   - MongoDB (port 27017)
   - MinIO object storage (ports 9000, 9001)

3. **Starts Backend Services**

   - Account Service (port 3000) - handles user authentication
   - Transactor Service (port 3333) - main business logic server

4. **Starts Frontend Development Server**
   - Webpack dev server (port 8080) - with hot reloading

### `stop-huly-dev.sh`

This script cleanly stops:

- All Node.js services
- Docker containers (MongoDB, MinIO)
- Cleans up any remaining processes

## Access Your Development Environment

Once the startup script completes, you can access:

- **🌐 Main Application**: http://localhost:8080
- **🔧 Account API**: http://localhost:3000
- **⚙️ Transactor WebSocket**: ws://localhost:3333
- **💾 MongoDB**: mongodb://localhost:27017
- **📦 MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)

## Development Workflow

1. **Start Development**:

   ```bash
   ./start-huly-dev.sh
   ```

2. **Develop**:

   - Frontend changes will auto-reload at http://localhost:8080
   - Backend changes require restart of specific services

3. **View Logs**:

   ```bash
   tail -f logs/frontend.log   # Frontend logs
   tail -f logs/account.log    # Account service logs
   tail -f logs/server.log     # Transactor service logs
   ```

4. **Stop Development**:
   ```bash
   ./stop-huly-dev.sh
   ```

## Troubleshooting

### Port Already in Use

The script automatically kills existing processes on required ports.

### Docker Issues

- Ensure Docker Desktop is running
- The script will restart containers if they exist

### Build Issues

If bundles are missing, the script will automatically run:

```bash
rush build
rush bundle
```

### Service Not Starting

Check the logs in the `logs/` directory:

```bash
ls -la logs/
tail -f logs/account.log    # Check for account service errors
tail -f logs/server.log     # Check for transactor errors
tail -f logs/frontend.log   # Check for frontend errors
```

### Database Issues

MongoDB runs in a Docker container. To reset the database:

```bash
./stop-huly-dev.sh
docker volume rm huly-mongo-data 2>/dev/null || true
./start-huly-dev.sh
```

## Manual Setup (Alternative)

If you prefer manual control:

```bash
# Start infrastructure
docker run -d --name huly-mongo -p 27017:27017 mongo:7.0
docker run -d --name huly-minio -p 9000:9000 -p 9001:9001 \
  -e "MINIO_ACCESS_KEY=minioadmin" -e "MINIO_SECRET_KEY=minioadmin" \
  minio/minio server /data --console-address ":9001"

# Start account service
cd pods/account
ACCOUNT_PORT=3000 DB_URL=mongodb://localhost:27017 \
MONGO_URL=mongodb://localhost:27017 SERVER_SECRET=secret \
TRANSACTOR_URL=ws://localhost:3333 FRONT_URL=http://localhost:8080 \
ACCOUNTS_URL=http://localhost:3000 MINIO_ENDPOINT=localhost \
MINIO_ACCESS_KEY=minioadmin MINIO_SECRET_KEY=minioadmin \
node bundle/bundle.js &

# Start transactor service
cd ../server
SERVER_PORT=3333 DB_URL=mongodb://localhost:27017 \
MONGO_URL=mongodb://localhost:27017 SERVER_SECRET=secret \
ACCOUNTS_URL=http://localhost:3000 FRONT_URL=http://localhost:8080 \
STORAGE_CONFIG=minio MINIO_ENDPOINT=localhost \
MINIO_ACCESS_KEY=minioadmin MINIO_SECRET_KEY=minioadmin \
MODEL_JSON=../../models/all/bundle/model.json QUEUE_CONFIG="" \
UPLOAD_URL="/files" node bundle/bundle.js &

# Start frontend
cd ../../dev/prod
rushx dev-server
```

## Next Steps

1. Navigate to http://localhost:8080
2. Click "Sign Up" and create your first account
3. Create a workspace to start using Huly Platform

Happy coding! 🎉
