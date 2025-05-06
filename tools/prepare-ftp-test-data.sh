#!/bin/bash
# Script to prepare test data for FTP testing

set -e

# Create test directory if it doesn't exist
TEST_DATA_DIR="../test/mock-data"
mkdir -p "$TEST_DATA_DIR"

# Function to create test files
create_test_files() {
  echo "Creating test data files..."
  
  # Create random data files with vessel IDs
  for i in {1..3}; do
    vessel_id=$(printf "%03d" $i)
    filename="${TEST_DATA_DIR}/vessel${vessel_id}_data_1.bin"
    
    # Create 1MB random data file
    dd if=/dev/urandom of="$filename" bs=1024 count=1024 2>/dev/null
    
    # Calculate and save MD5 hash
    md5_hash=$(md5sum "$filename" | awk '{print $1}')
    echo "$md5_hash" > "${filename}.md5"
    
    echo "Created test file: $filename with MD5: $md5_hash"
  done
  
  # Also create files with EKI format
  for i in {1..2}; do
    eki_id=$(printf "%04d" $i)
    filename="${TEST_DATA_DIR}/data-EKI${eki_id}.bin"
    
    # Create 512KB random data file
    dd if=/dev/urandom of="$filename" bs=1024 count=512 2>/dev/null
    
    # Calculate and save MD5 hash
    md5_hash=$(md5sum "$filename" | awk '{print $1}')
    echo "$md5_hash" > "${filename}.md5"
    
    echo "Created test file: $filename with MD5: $md5_hash"
  done
}

# Function to start the Docker environment
start_docker_env() {
  echo "Starting Docker environment..."
  docker-compose -f tools/docker-compose.yml up -d
  echo "Docker environment is running"
}

# Function to check Docker logs
show_logs() {
  echo "Showing logs from the FTP data setup container:"
  docker-compose -f tools/docker-compose.yml logs ftp-data-setup
}

# Function to show help
show_help() {
  echo "Usage: $0 [OPTION]"
  echo "Prepare test data for FTP testing"
  echo ""
  echo "Options:"
  echo "  create     Create test data files"
  echo "  start      Start Docker environment"
  echo "  logs       Show container logs"
  echo "  help       Show this help message"
  echo ""
  echo "If no option is specified, all steps will be executed in sequence."
}

# Process command line arguments
if [ $# -eq 0 ]; then
  create_test_files
  start_docker_env
  sleep 5
  show_logs
else
  case "$1" in
    create)
      create_test_files
      ;;
    start)
      start_docker_env
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