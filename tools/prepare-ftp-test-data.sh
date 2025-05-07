#!/bin/bash
# Script to prepare test data for FTP testing

set -e

# Define directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEST_DATA_DIR="../test/mock-data"
mkdir -p "$TEST_DATA_DIR"

# Function to create test files using the Python script
create_test_files() {
  echo "Creating test data files using Python..."
  python3 "$SCRIPT_DIR/ftp_uploader.py" --create-test-data --dir "$TEST_DATA_DIR"
}

# Function to start the Docker environment
start_docker_env() {
  echo "Starting Docker environment..."
  docker-compose -f "$SCRIPT_DIR/docker-compose.yml" up -d ftp-server azurite minio minio-setup azure-setup
  echo "Docker environment is running"
  
  # Wait for FTP server to be ready
  echo "Waiting for FTP server to be ready..."
  sleep 10
}

# Function to upload files to FTP using Python script
upload_to_ftp() {
  echo "Uploading files to FTP server using Python..."
  python3 "$SCRIPT_DIR/ftp_uploader.py" --dir "$TEST_DATA_DIR" --remote-dir "/upload"
}

# Function to check Docker logs
show_logs() {
  echo "Showing logs from the FTP server container:"
  docker-compose -f "$SCRIPT_DIR/docker-compose.yml" logs ftp-server
}

# Function to show help
show_help() {
  echo "Usage: $0 [OPTION]"
  echo "Prepare test data for FTP testing"
  echo ""
  echo "Options:"
  echo "  create     Create test data files"
  echo "  start      Start Docker environment"
  echo "  upload     Upload files to FTP server using Python"
  echo "  logs       Show container logs"
  echo "  help       Show this help message"
  echo ""
  echo "If no option is specified, all steps will be executed in sequence."
}

# Process command line arguments
if [ $# -eq 0 ]; then
  create_test_files
  start_docker_env
  upload_to_ftp
  show_logs
else
  case "$1" in
    create)
      create_test_files
      ;;
    start)
      start_docker_env
      ;;
    upload)
      upload_to_ftp
      ;;
    logs)
      show_logs
      ;;
    help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
fi

echo "Done"