#!/bin/bash
set -e

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Display banner
echo "======================================"
echo "Elysium USV - Upload Test Data"
echo "======================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Check if containers are running
if ! docker ps | grep -q "azurite"; then
  echo "Error: Azurite container is not running. Start it with: tools/local-dev.sh"
  exit 1
fi

# Ensure test data directory exists
TEST_DATA_DIR="$REPO_ROOT/test/mock-data"
mkdir -p "$TEST_DATA_DIR"

# Generate some random test data files if they don't exist
if [ ! -f "$TEST_DATA_DIR/vessel001_data_1.bin" ]; then
  echo "Generating test data files..."
  
  # Generate test files of different sizes
  dd if=/dev/urandom of="$TEST_DATA_DIR/vessel001_data_1.bin" bs=1024 count=1024
  dd if=/dev/urandom of="$TEST_DATA_DIR/vessel001_data_2.bin" bs=1024 count=512
  dd if=/dev/urandom of="$TEST_DATA_DIR/vessel002_data_1.bin" bs=1024 count=2048
  
  echo "Test data files generated"
fi

# Calculate checksums for the files
echo "Calculating checksums for test files..."
VESSEL001_DATA_1_CHECKSUM=$(shasum -a 256 "$TEST_DATA_DIR/vessel001_data_1.bin" | cut -d ' ' -f 1)
VESSEL001_DATA_2_CHECKSUM=$(shasum -a 256 "$TEST_DATA_DIR/vessel001_data_2.bin" | cut -d ' ' -f 1)
VESSEL002_DATA_1_CHECKSUM=$(shasum -a 256 "$TEST_DATA_DIR/vessel002_data_1.bin" | cut -d ' ' -f 1)

echo "Checksums:"
echo "- vessel001_data_1.bin: $VESSEL001_DATA_1_CHECKSUM"
echo "- vessel001_data_2.bin: $VESSEL001_DATA_2_CHECKSUM"
echo "- vessel002_data_1.bin: $VESSEL002_DATA_1_CHECKSUM"

# Use the Azure CLI to upload the test data to Azurite
echo "Uploading test data to Azurite..."

# Create the container if it doesn't exist
echo "Creating container in Azurite..."
az storage container create \
  --name usvdata \
  --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"

# Create all required queues if they don't exist
for queue in "validation-queue" "transfer-queue" "cleanup-queue"; do
  echo "Creating $queue in Azurite..."
  az storage queue create \
    --name $queue \
    --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;"
  
  echo "Checking $queue exists..."
  az storage queue exists \
    --name $queue \
    --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;"
done

# Function to upload a file with metadata and queue a validation message
upload_file() {
  local file_path=$1
  local blob_name=$2
  local vessel_id=$3
  local checksum=$4
  
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  echo "Uploading $file_path to $blob_name..."
  # Debugging - show metadata
  echo "Setting metadata: checksum=$checksum vesselid=$vessel_id"
  
  # Use direct HTTP API for better metadata control
  metadata_str="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<Metadata>
  <checksum>$checksum</checksum>
  <vesselid>$vessel_id</vesselid>
  <timestamp>$timestamp</timestamp>
  <checksumAlgorithm>SHA256</checksumAlgorithm>
</Metadata>"
  
  # First upload the blob
  az storage blob upload \
    --container-name usvdata \
    --file "$file_path" \
    --name "$blob_name" \
    --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"
    
  # Then set metadata explicitly
  curl -X PUT \
    "http://127.0.0.1:10000/devstoreaccount1/usvdata/$blob_name?comp=metadata" \
    -H "x-ms-version: 2019-12-12" \
    -H "x-ms-date: $(date -u +"%a, %d %b %Y %H:%M:%S GMT")" \
    -H "x-ms-meta-checksum: $checksum" \
    -H "x-ms-meta-vesselid: $vessel_id" \
    -H "x-ms-meta-timestamp: $timestamp" \
    -H "x-ms-meta-checksumAlgorithm: SHA256" \
    -H "Authorization: SharedKey devstoreaccount1:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==" \
    -H "Content-Length: 0"
    
  # Verify metadata was set correctly
  echo "Verifying metadata for $blob_name..."
  curl -X HEAD \
    "http://127.0.0.1:10000/devstoreaccount1/usvdata/$blob_name" \
    -H "x-ms-version: 2019-12-12" \
    -H "x-ms-date: $(date -u +"%a, %d %b %Y %H:%M:%S GMT")" \
    -H "Authorization: SharedKey devstoreaccount1:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==" \
    -v
  
  # Add message to validation queue
  echo "Adding message to validation queue for $blob_name..."
  az storage message put \
    --queue-name validation-queue \
    --content "$blob_name" \
    --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;"
}

# Generate today's date in YYYYMMDD format
TODAY=$(date +%Y%m%d)

# Upload the test files
upload_file "$TEST_DATA_DIR/vessel001_data_1.bin" "VESSEL001/data_${TODAY}_1.bin" "VESSEL001" "$VESSEL001_DATA_1_CHECKSUM"
upload_file "$TEST_DATA_DIR/vessel001_data_2.bin" "VESSEL001/data_${TODAY}_2.bin" "VESSEL001" "$VESSEL001_DATA_2_CHECKSUM"
upload_file "$TEST_DATA_DIR/vessel002_data_1.bin" "VESSEL002/data_${TODAY}_1.bin" "VESSEL002" "$VESSEL002_DATA_1_CHECKSUM"

# Upload one file with incorrect checksum for testing validation
incorrect_checksum="0000000000000000000000000000000000000000000000000000000000000000"
upload_file "$TEST_DATA_DIR/vessel001_data_1.bin" "VESSEL001/data_${TODAY}_invalid.bin" "VESSEL001" "$incorrect_checksum"

echo "Test data upload complete"
echo ""
echo "The following files have been uploaded to Azurite blob storage:"
echo "- usvdata/VESSEL001/data_${TODAY}_1.bin (valid)"
echo "- usvdata/VESSEL001/data_${TODAY}_2.bin (valid)"
echo "- usvdata/VESSEL002/data_${TODAY}_1.bin (valid)"
echo "- usvdata/VESSEL001/data_${TODAY}_invalid.bin (invalid checksum)"
echo ""
echo "Messages have been added to the validation queue for processing."
echo "You can now run the application to process these files:"
echo "  ./local-dev.sh run"