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
    
    # Handle remote directory formatting
    if remote_dir.startswith('/'):
        remote_dir = remote_dir[1:]  # Remove leading slash
    
    remote_path = f"{remote_dir}/{filename}"
    
    # Upload the file
    with open(local_file, "rb") as file:
        logger.info(f"Uploading {filename} to {remote_path}")
        # Enable passive mode with extended range
        ftp.set_pasv(True)
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
        md5_remote_path = f"{remote_dir}/{md5_filename}"
        logger.info(f"Uploading {md5_filename} to {md5_remote_path}")
        ftp.storbinary(f"STOR {md5_remote_path}", md5_file)
        logger.info(f"Successfully uploaded {md5_filename}")
    
    # Clean up temporary MD5 file if it was created
    if not os.path.exists(local_file + ".md5"):
        os.remove(md5_path)


def upload_directory(ftp, local_dir, remote_dir, pattern="*.bin"):
    """Upload all files matching pattern in a directory to the FTP server."""
    uploaded_count = 0
    
    # List directories to check if we're in the home directory
    logger.debug(f"Current directory: {ftp.pwd()}")
    logger.debug(f"Directory listing: {ftp.nlst()}")
    
    # Create the remote directory structure
    if remote_dir.startswith('/'):
        # Remove leading slash for relative paths
        remote_dir = remote_dir[1:]
    
    # Create each directory in the path if needed
    parts = remote_dir.split('/')
    current_dir = ""
    for part in parts:
        if part:
            try:
                current_dir = current_dir + "/" + part if current_dir else part
                logger.debug(f"Trying to create directory: {current_dir}")
                ftp.mkd(current_dir)
                logger.info(f"Created remote directory: {current_dir}")
            except ftplib.error_perm as e:
                logger.debug(f"Directory probably exists: {e}")
    
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
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--file", help="Specific file to upload")
    group.add_argument("--dir", help="Directory containing files to upload")
    
    args = parser.parse_args()
    
    # Set logging level based on verbose flag
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        # Enable FTP debugging
        ftplib.FTP.debugging = 2
    
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
        try:
            ftp.connect(args.host, args.port)
            logger.debug("FTP connect successful")
        except Exception as e:
            logger.error(f"FTP connect error: {e}")
            raise
        
        try:
            ftp.login(args.user, args.password)
            logger.debug("FTP login successful")
        except Exception as e:
            logger.error(f"FTP login error: {e}")
            raise
            
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