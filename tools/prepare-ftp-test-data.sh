#!/bin/bash
set -e

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Display banner
echo "======================================"
echo "Elysium USV - Prepare FTP Test Data"
echo "======================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Check if FTP container is running
if ! docker ps | grep -q "ftp-server"; then
  echo "Error: FTP server container is not running. Start it with: tools/local-dev.sh"
  exit 1
fi

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Ensure test data directory exists
TEST_DATA_DIR="$REPO_ROOT/data/test/ekinox"
if [ ! -d "$TEST_DATA_DIR" ]; then
  echo "Error: Test data directory not found: $TEST_DATA_DIR"
  exit 1
fi

# Create MD5 hash files if they don't already exist
echo "Creating MD5 hash files for test data..."
for data_file in "$TEST_DATA_DIR"/*; do
  # Skip if it's already an MD5 file
  if [[ "$data_file" == *".md5" ]]; then
    continue
  fi
  
  # Create the MD5 hash file if it doesn't exist
  md5_file="${data_file}.md5"
  if [ ! -f "$md5_file" ]; then
    md5sum "$data_file" | awk '{print $1}' > "$md5_file"
    echo "Created MD5 hash file: $md5_file"
  fi
done

# Prepare directory structure to copy to FTP server
FTP_DATA_DIR="$TEMP_DIR/ftp_data"
mkdir -p "$FTP_DATA_DIR"

# Copy test files to the temporary directory
echo "Copying test files to temporary directory..."
cp "$TEST_DATA_DIR"/* "$FTP_DATA_DIR/"

# Find the FTP server container ID
FTP_CONTAINER_ID=$(docker ps --filter "name=ftp-server" --format "{{.ID}}")
if [ -z "$FTP_CONTAINER_ID" ]; then
  echo "Error: Failed to find FTP server container"
  exit 1
fi

# Copy the files to the FTP server container
echo "Copying files to FTP server container..."
docker cp "$FTP_DATA_DIR/." "$FTP_CONTAINER_ID:/home/ftpuser/"

echo "Test data has been prepared and uploaded to the FTP server."
echo "The following files have been uploaded:"
ls -la "$FTP_DATA_DIR"
echo ""
echo "FTP Server Information:"
echo "- Host: localhost"
echo "- Port: 21"
echo "- Username: ftpuser"
echo "- Password: ftppass"
echo ""
echo "You can now connect to the FTP server and the files will be automatically processed."