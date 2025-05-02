#!/bin/bash
set -e

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Display banner
echo "======================================"
echo "Elysium USV Pipeline - Local Dev Setup"
echo "======================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Start local development environment
echo "Starting Azurite and MinIO containers..."
cd "$REPO_ROOT/tools"
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
export PORT="8080"
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

echo "Environment variables set for local development"
echo "- Azure Storage: Azurite on ports 10000-10002"
echo "- AWS S3: MinIO on port 9000 (API) and 9001 (console)"
echo ""
echo "You can access MinIO console at: http://localhost:9001"
echo "Access Key: minioadmin"
echo "Secret Key: minioadmin"
echo ""

# Create necessary Azure resources if requested
if [ "$1" == "setup" ] || [ "$1" == "run" ]; then
  echo "Creating necessary Azure resources..."
  
  echo "Creating blob container..."
  curl -X PUT \
    "http://localhost:10000/devstoreaccount1/usvdata?restype=container" \
    -H "x-ms-version: 2019-12-12" \
    -H "x-ms-date: $(date -u +"%a, %d %b %Y %H:%M:%S GMT")" \
    -H "Content-Length: 0" \
    -H "Authorization: SharedKey devstoreaccount1:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==" \
    -s -o /dev/null || echo "Container already exists or creation failed"

  echo "Creating queues..."
  for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
    curl -X PUT \
      "http://localhost:10001/devstoreaccount1/$queue" \
      -H "x-ms-version: 2019-12-12" \
      -H "x-ms-date: $(date -u +"%a, %d %b %Y %H:%M:%S GMT")" \
      -H "Content-Length: 0" \
      -H "Authorization: SharedKey devstoreaccount1:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==" \
      -v || echo "Queue $queue already exists or creation failed"
    
    # Verify the queue was created successfully
    echo "Verifying queue $queue..."
    curl -X GET \
      "http://localhost:10001/devstoreaccount1/$queue/messages?numofmessages=1" \
      -H "x-ms-version: 2019-12-12" \
      -H "x-ms-date: $(date -u +"%a, %d %b %Y %H:%M:%S GMT")" \
      -H "Authorization: SharedKey devstoreaccount1:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==" \
      -v || echo "Failed to verify queue $queue"
  done

  # Create S3 bucket in MinIO
  echo "Creating S3 bucket in MinIO..."
  AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin aws --endpoint-url http://localhost:9000 s3 mb s3://revelare-vessel-data --region ap-southeast-2 || echo "Bucket already exists or creation failed"
  
  # Create audit directory for file-based auditing
  echo "Creating audit directory..."
  mkdir -p /tmp/usvpipeline/audit
    
  echo "Azure and AWS resources created or already exist"
fi

# Build and run if requested
if [ "$1" == "run" ]; then
  echo "Building and running the application..."
  cd "$REPO_ROOT"
  go build -o bin/usvpipeline ./cmd/usvpipeline
  ./bin/usvpipeline
elif [ "$1" == "build" ]; then
  echo "Building the application..."
  cd "$REPO_ROOT"
  go build -o bin/usvpipeline ./cmd/usvpipeline
  echo "Build complete: $REPO_ROOT/bin/usvpipeline"
elif [ "$1" == "setup" ]; then
  echo "Setup complete! Resources have been created."
else
  echo "Local environment is ready!"
  echo ""
  echo "Usage:"
  echo "  $0         - Just set up the environment"
  echo "  $0 setup   - Set up environment and create necessary Azure resources"
  echo "  $0 build   - Set up environment and build the app"
  echo "  $0 run     - Set up environment, create resources, build and run the app"
fi