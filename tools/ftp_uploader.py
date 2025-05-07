#!/usr/bin/env python3
"""
FTP Uploader Script

This script uploads files to an FTP server for testing purposes.
It can upload specific files or all files in a directory.
"""

import os
import sys
import ftplib
import argparse
import logging
from pathlib import Path
import hashlib


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)


def calculate_md5(file_path):
    """Calculate MD5 hash of a file."""
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def upload_file(ftp, local_file, remote_dir):
    """Upload a single file to the FTP server."""
    filename = os.path.basename(local_file)
    remote_path = f"{remote_dir}/{filename}"
    
    # Upload the file
    with open(local_file, "rb") as file:
        logger.info(f"Uploading {filename} to {remote_path}")
        ftp.storbinary(f"STOR {remote_path}", file)
        logger.info(f"Successfully uploaded {filename}")
    
    # Calculate and upload MD5 checksum file
    md5_hash = calculate_md5(local_file)
    md5_filename = f"{filename}.md5"
    md5_path = os.path.join(os.path.dirname(local_file), md5_filename)
    
    # Write MD5 to temporary file
    with open(md5_path, "w") as md5_file:
        md5_file.write(md5_hash)
    
    # Upload MD5 file
    with open(md5_path, "rb") as md5_file:
        logger.info(f"Uploading {md5_filename} to {remote_dir}/{md5_filename}")
        ftp.storbinary(f"STOR {remote_dir}/{md5_filename}", md5_file)
        logger.info(f"Successfully uploaded {md5_filename}")
    
    # Clean up temporary MD5 file if it was created
    if not os.path.exists(local_file + ".md5"):
        os.remove(md5_path)


def upload_directory(ftp, local_dir, remote_dir, pattern="*.bin"):
    """Upload all files matching pattern in a directory to the FTP server."""
    uploaded_count = 0
    
    # Create the remote directory if it doesn't exist
    try:
        ftp.mkd(remote_dir)
        logger.info(f"Created remote directory: {remote_dir}")
    except ftplib.error_perm:
        # Directory probably already exists
        pass
    
    # Loop through all files in the directory matching the pattern
    for file_path in Path(local_dir).glob(pattern):
        try:
            upload_file(ftp, str(file_path), remote_dir)
            uploaded_count += 1
        except Exception as e:
            logger.error(f"Failed to upload {file_path}: {e}")
    
    return uploaded_count


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description="Upload files to FTP server")
    parser.add_argument("--host", default="localhost", help="FTP server hostname")
    parser.add_argument("--port", type=int, default=21, help="FTP server port")
    parser.add_argument("--user", default="ftpuser", help="FTP username")
    parser.add_argument("--password", default="ftppass", help="FTP password")
    parser.add_argument("--remote-dir", default="/upload", help="Remote directory")
    parser.add_argument("--create-test-data", action="store_true", help="Create test data files")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--file", help="Specific file to upload")
    group.add_argument("--dir", help="Directory containing files to upload")
    
    args = parser.parse_args()
    
    # Create test data if requested
    if args.create_test_data:
        test_data_dir = "../test/mock-data"
        os.makedirs(test_data_dir, exist_ok=True)
        
        # Create test files similar to prepare-ftp-test-data.sh
        logger.info("Creating test data files...")
        
        # Copy logic from prepare-ftp-test-data.sh to create test files
        import subprocess
        import random
        
        # Create vessel files
        for i in range(1, 4):
            vessel_id = f"{i:03d}"
            filename = f"{test_data_dir}/vessel{vessel_id}_data_1.bin"
            
            # Create 1MB random data file
            with open(filename, 'wb') as f:
                f.write(os.urandom(1024 * 1024))  # 1MB of random data
            
            # Calculate MD5
            md5_hash = calculate_md5(filename)
            with open(f"{filename}.md5", 'w') as f:
                f.write(md5_hash)
            
            logger.info(f"Created test file: {filename} with MD5: {md5_hash}")
        
        # Create EKI files
        for i in range(1, 3):
            eki_id = f"{i:04d}"
            filename = f"{test_data_dir}/data-EKI{eki_id}.bin"
            
            # Create 512KB random data file
            with open(filename, 'wb') as f:
                f.write(os.urandom(512 * 1024))  # 512KB of random data
            
            # Calculate MD5
            md5_hash = calculate_md5(filename)
            with open(f"{filename}.md5", 'w') as f:
                f.write(md5_hash)
            
            logger.info(f"Created test file: {filename} with MD5: {md5_hash}")
    
    try:
        # Connect to the FTP server
        logger.info(f"Connecting to FTP server at {args.host}:{args.port}")
        ftp = ftplib.FTP()
        ftp.connect(args.host, args.port)
        ftp.login(args.user, args.password)
        logger.info(f"Successfully connected to FTP server")
        
        # Upload file(s)
        if args.file:
            # Upload a single file
            upload_file(ftp, args.file, args.remote_dir)
            logger.info(f"Successfully uploaded 1 file to FTP server")
        else:
            # Upload all .bin files in the directory
            count = upload_directory(ftp, args.dir, args.remote_dir)
            logger.info(f"Successfully uploaded {count} files to FTP server")
        
        # Close the FTP connection
        ftp.quit()
        logger.info("FTP connection closed")
        
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()