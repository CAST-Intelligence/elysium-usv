#!/bin/bash
set -e

echo "===== Alternative Azurite Setup and Test ====="
echo "This script will:"
echo "1. Install Azurite globally via npm"
echo "2. Start Azurite in the background"
echo "3. Run tests to check if metadata operations work"
echo ""

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Install Azurite globally
echo "Installing Azurite globally..."
npm install -g azurite

# Start Azurite in the background
echo "Starting Azurite..."
# Kill any existing Azurite process
pkill -f azurite || true
sleep 1

# Start Azurite with default ports
azurite --silent --location ~/.azurite --debug ~/.azurite/debug.log &
AZURITE_PID=$!
echo "Azurite started with PID $AZURITE_PID"

# Wait for Azurite to start
echo "Waiting for Azurite to be ready..."
sleep 3

# Install Python dependencies
echo "Installing Python dependencies..."
pip install azure-storage-blob

# Run the Python test
echo "Running Python test..."
python test_azurite.py

# Build and run the Go test
echo "Building and running Go test..."
go build -o test_azurite_go test_azurite.go
./test_azurite_go

# Cleanup
echo "Cleaning up..."
if ps -p $AZURITE_PID > /dev/null; then
    kill $AZURITE_PID
    echo "Azurite process terminated"
fi

# Provide recommendations based on test results
echo ""
echo "===== Recommendations ====="
echo "If the Python test succeeded but the Go test failed, it likely indicates a difference"
echo "in how the two SDKs handle authentication with Azurite."
echo ""
echo "Options to fix the issue:"
echo "1. Use a different version of Azurite in your Docker Compose setup"
echo "2. Implement one of the alternative state tracking mechanisms we discussed"
echo "3. Update your Go code to use the same authentication approach as the Python SDK"
echo ""