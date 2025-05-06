#!/bin/bash
set -e

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Display banner
echo "======================================"
echo "Elysium USV Pipeline - Local Dev Setup"
echo "======================================"

echo "Command: $1"

# Clean up any existing processes
cleanup_existing_processes() {
  echo "Cleaning up any existing processes..."
  # Find and kill any running usvpipeline processes
  pkill -f "usvpipeline" 2>/dev/null || true
  # Check if port 8081 is in use and kill the process
  PROCESS_PID=$(lsof -ti:8081 2>/dev/null)
  if [ -n "$PROCESS_PID" ]; then
    echo "Killing process using port 8081 (PID: $PROCESS_PID)"
    kill -9 $PROCESS_PID 2>/dev/null || true
  fi
  # Wait for processes to exit
  sleep 1
}

# Run cleanup
cleanup_existing_processes

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Start local development environment
echo "Starting containers (Azurite, MinIO, FTP)..."
cd "$REPO_ROOT/tools"
export REPO_ROOT
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 5

# Set up environment variables for local development
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"
export AWS_ENDPOINT_URL="http://localhost:9000"
export AWS_ACCESS_KEY_ID="minioadmin"
export AWS_SECRET_ACCESS_KEY="minioadmin"
export AWS_REGION="ap-southeast-2" # Australian region for data sovereignty
export AWS_BUCKET_NAME="revelare-vessel-data"
export LOG_LEVEL="debug"
export PORT="8081"
export WORKER_COUNT="3"
export PROCESSING_BATCH_SIZE="10"
export RETENTION_DAYS="7"
export ENVIRONMENT="development"
export LOG_JSON="false"
export VALIDATION_QUEUE_NAME="validation-queue"
export TRANSFER_QUEUE_NAME="transfer-queue"
export CLEANUP_QUEUE_NAME="cleanup-queue"
export BLOB_CONTAINER_NAME="usvdata"
export OPERATION_RETRY_COUNT="3"
export OPERATION_RETRY_INTERVAL="5s"

# FTP configuration
export FTP_HOST="localhost"
export FTP_PORT="21"
export FTP_USER="ftpuser"
export FTP_PASSWORD="ftppass"

# FTP worker settings
export FTP_WATCH_ENABLED="true"
# Create a watch directory in tmp for testing
FTP_WATCH_DIR="/tmp/elysium-usv-ftp-watch"
mkdir -p "$FTP_WATCH_DIR"
export FTP_WATCH_DIR
export FTP_POLL_INTERVAL="10s"  # More frequent polling for testing

echo "Environment variables set for local development"
echo "- Azure Storage: Azurite on ports 10000-10002"
echo "- AWS S3: MinIO on port 9000 (API) and 9001 (console)"
echo "- FTP Server: localhost:21 (user: ftpuser, password: ftppass)"
echo ""
echo "You can access MinIO console at: http://localhost:9001"
echo "Access Key: minioadmin"
echo "Secret Key: minioadmin"
echo ""

# Create necessary Azure resources if requested
if [ "$1" == "setup" ] || [ "$1" == "run" ]; then
  echo "Creating necessary Azure resources..."
  
  # Sleep a bit more to ensure Azurite is fully ready
  sleep 3
  
  # Use the Azure CLI (az) for better compatibility
  echo "Creating blob container..."
  az storage container create \
    --name usvdata \
    --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
    -o none || echo "Container already exists or creation failed"

  echo "Creating queues..."
  for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
    az storage queue create \
      --name $queue \
      --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
      -o none || echo "Queue $queue already exists or creation failed"
    
    # Verify the queue was created successfully
    echo "Verifying queue $queue exists..."
    az storage queue exists \
      --name $queue \
      --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
      -o none || echo "Failed to verify queue $queue"
  done

  # Create S3 bucket in MinIO
  echo "Creating S3 bucket in MinIO..."
  AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin aws --endpoint-url http://localhost:9000 s3 mb s3://revelare-vessel-data --region ap-southeast-2 || echo "Bucket already exists or creation failed"
  
  # Create audit directory for file-based auditing
  echo "Creating audit directory..."
  mkdir -p /tmp/usvpipeline/audit
    
  echo "Azure and AWS resources created or already exist"
fi

# Reset all state function
reset_all_state() {
  echo "Resetting all state..."
  
  # Stop existing containers
  docker-compose down
  
  # Remove volume data
  docker volume rm tools_azurite-data tools_minio-data tools_ftp-data tools_ftp-watch-data || true
  
  # Remove audit logs
  rm -rf /tmp/usvpipeline/audit
  
  # Start containers again
  docker-compose up -d
  
  # Wait for services to be ready
  echo "Waiting for services to restart..."
  sleep 5
  
  # Create resources again
  echo "Creating Azure resources from scratch..."
  AZURE_CONN_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;"
  
  # Create blob container
  az storage container create \
    --name usvdata \
    --connection-string "${AZURE_CONN_STRING}BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;" || true
  
  # Create queues
  for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
    az storage queue create \
      --name $queue \
      --connection-string "${AZURE_CONN_STRING}QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;" || true
  done
  
  # Create S3 bucket
  AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin aws --endpoint-url http://localhost:9000 \
    s3 mb s3://revelare-vessel-data --region ap-southeast-2 || true
  
  # Create audit directory
  mkdir -p /tmp/usvpipeline/audit
  
  echo "All state has been reset!"
}

# Prepare FTP test data function
prepare_ftp_test_data() {
  echo "Preparing test data for FTP server..."
  if [ -f "$REPO_ROOT/tools/prepare-ftp-test-data.sh" ]; then
    bash "$REPO_ROOT/tools/prepare-ftp-test-data.sh"
  else
    echo "Error: FTP test data preparation script not found"
    exit 1
  fi
}

# Process command
case "$1" in
  "run")
    echo "Building and running the application..."
    cd "$REPO_ROOT"
    go build -o bin/usvpipeline ./cmd/usvpipeline
    ./bin/usvpipeline
    ;;
  "build")
    echo "Building the application..."
    cd "$REPO_ROOT"
    go build -o bin/usvpipeline ./cmd/usvpipeline
    echo "Build complete: $REPO_ROOT/bin/usvpipeline"
    ;;
  "setup")
    echo "Creating necessary Azure resources..."
    # Sleep a bit more to ensure Azurite is fully ready
    sleep 3
    
    # Use the Azure CLI (az) for better compatibility
    echo "Creating blob container..."
    az storage container create \
      --name usvdata \
      --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
      -o none || echo "Container already exists or creation failed"

    echo "Creating queues..."
    for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
      az storage queue create \
        --name $queue \
        --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
        -o none || echo "Queue $queue already exists or creation failed"
      
      # Verify the queue was created successfully
      echo "Verifying queue $queue exists..."
      az storage queue exists \
        --name $queue \
        --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
        -o none || echo "Failed to verify queue $queue"
    done

    # Create S3 bucket in MinIO
    echo "Creating S3 bucket in MinIO..."
    AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin aws --endpoint-url http://localhost:9000 s3 mb s3://revelare-vessel-data --region ap-southeast-2 || echo "Bucket already exists or creation failed"
    
    # Create audit directory for file-based auditing
    echo "Creating audit directory..."
    mkdir -p /tmp/usvpipeline/audit
      
    echo "Setup complete! Resources have been created."
    ;;
  "reset")
    echo "Resetting all state..."
    
    # Stop existing containers
    docker-compose down
    
    # Remove volume data
    docker volume rm tools_azurite-data tools_minio-data tools_ftp-data tools_ftp-watch-data || true
    
    # Remove audit logs
    rm -rf /tmp/usvpipeline/audit
    
    # Start containers again
    docker-compose up -d
    
    # Wait for services to be ready
    echo "Waiting for services to restart..."
    sleep 5
    
    # Create resources again
    echo "Creating Azure resources from scratch..."
    AZURE_CONN_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;"
    
    # Create blob container
    az storage container create \
      --name usvdata \
      --connection-string "${AZURE_CONN_STRING}BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;" || true
    
    # Create queues
    for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
      az storage queue create \
        --name $queue \
        --connection-string "${AZURE_CONN_STRING}QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;" || true
    done
    
    # Create S3 bucket
    AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin aws --endpoint-url http://localhost:9000 \
      s3 mb s3://revelare-vessel-data --region ap-southeast-2 || true
    
    # Create audit directory
    mkdir -p /tmp/usvpipeline/audit
    
    echo "All state has been reset!"
    ;;
  "ftp-data")
    echo "Preparing test data for FTP server..."
    if [ -f "$REPO_ROOT/tools/prepare-ftp-test-data.sh" ]; then
      bash "$REPO_ROOT/tools/prepare-ftp-test-data.sh"
    else
      echo "Error: FTP test data preparation script not found"
      exit 1
    fi
    ;;
  *)
    echo "Local environment is ready!"
    echo ""
    echo "Usage:"
    echo "  $0             - Just set up the environment"
    echo "  $0 setup       - Set up environment and create necessary Azure resources"
    echo "  $0 build       - Set up environment and build the app"
    echo "  $0 run         - Set up environment, create resources, build and run the app"
    echo "  $0 reset       - Reset all state (remove containers, volumes, and recreate resources)"
    echo "  $0 ftp-data    - Prepare and upload test data to the FTP server"
    ;;
esac