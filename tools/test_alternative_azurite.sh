#!/bin/bash
set -e

echo "===== Testing Alternative Azurite Setup ====="
echo "This script will:"
echo "1. Stop existing Azurite containers"
echo "2. Start new Azurite with loose auth mode"
echo "3. Run test to see if metadata operations work"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Stop any existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.yml down

# Start containers with alternative configuration
echo "Starting containers with alternative configuration..."
docker-compose -f docker-compose-alt.yml up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 5

# Check if containers are running
echo "Checking if containers are running..."
if ! docker ps | grep -q "azurite"; then
  echo "Error: Azurite container failed to start"
  exit 1
fi

# Run the Go test to see if metadata operations work
echo "Building Go test..."
go build -o test_azurite_go test_azurite.go

echo "Running Go test against alternative Azurite..."
./test_azurite_go

# Provide status
echo ""
echo "===== Test Results ====="
if [ $? -eq 0 ]; then
  echo "✅ Alternative Azurite setup works with metadata operations!"
  echo "You should update the main docker-compose.yml with these changes."
else
  echo "❌ Alternative Azurite setup still has issues with metadata operations."
  echo "Consider implementing one of the alternative state tracking mechanisms."
fi