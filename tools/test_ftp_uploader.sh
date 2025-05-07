#!/bin/bash
# Test script for FTP uploader

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Step 1: Create test data
echo "Step 1: Creating test data..."
"$SCRIPT_DIR/prepare-ftp-test-data.sh" create

# Step 2: Start Docker environment with FTP server
echo "Step 2: Starting Docker environment..."
"$SCRIPT_DIR/prepare-ftp-test-data.sh" start

# Step 3: Upload files to FTP server
echo "Step 3: Uploading files to FTP server..."
"$SCRIPT_DIR/prepare-ftp-test-data.sh" upload

# Step 4: Verify upload by listing FTP contents
echo "Step 4: Verifying upload by listing FTP contents..."
python3 -c "
import ftplib

# Connect to the FTP server
ftp = ftplib.FTP()
ftp.connect('localhost', 21)
ftp.login('ftpuser', 'ftppass')

# List directories
print('FTP Root directory contents:')
ftp.retrlines('LIST')

# List upload directory
try:
    print('\nUpload directory contents:')
    ftp.cwd('/upload')
    ftp.retrlines('LIST')
except Exception as e:
    print(f'Error accessing upload directory: {e}')

# Close the connection
ftp.quit()
"

echo "FTP uploader test completed!"