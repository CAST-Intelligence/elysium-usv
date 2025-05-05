#!/usr/bin/env python3
"""
Minimal test script to demonstrate capturing ETag from S3 uploads.
This script:
1. Creates a test file with random content
2. Calculates MD5 hash locally
3. Uploads the file to MinIO/S3
4. Captures and displays the ETag from the upload response
5. Compares the local MD5 with the ETag
"""

import boto3
import hashlib
import os
import random
import string
from botocore.client import Config

# Configuration for MinIO
ENDPOINT_URL = "http://localhost:9000"
AWS_ACCESS_KEY_ID = "minioadmin"
AWS_SECRET_ACCESS_KEY = "minioadmin"
BUCKET_NAME = "revelare-vessel-data"
REGION = "ap-southeast-2"

# Create a test file
def create_test_file(file_path, size_kb=512):
    """Create a test file with random content"""
    print(f"Creating test file: {file_path} ({size_kb} KB)")
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    
    # Generate random content
    content = ''.join(random.choices(string.ascii_letters + string.digits, k=size_kb * 1024)).encode('utf-8')
    
    # Write to file
    with open(file_path, 'wb') as f:
        f.write(content)
    
    return content

# Calculate MD5 hash for a file
def calculate_md5(content):
    """Calculate MD5 hash for content"""
    md5_hash = hashlib.md5(content).hexdigest()
    return md5_hash

# Upload file to S3/MinIO and capture ETag
def upload_to_s3(file_path, object_key):
    """Upload file to S3/MinIO and return the ETag"""
    print(f"Uploading {file_path} to S3 as {object_key}")
    
    # Create S3 client
    s3_client = boto3.client(
        's3',
        endpoint_url=ENDPOINT_URL,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=REGION,
        config=Config(signature_version='s3v4')
    )
    
    # Upload file
    with open(file_path, 'rb') as f:
        response = s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=object_key,
            Body=f
        )
    
    # Extract ETag (it's surrounded by quotes)
    etag = response.get('ETag', '').strip('"')
    return etag

def main():
    # Create test file
    file_name = "test_file.bin"
    test_file_path = os.path.join("/tmp", file_name)
    
    # Generate content and calculate MD5
    content = create_test_file(test_file_path)
    local_md5 = calculate_md5(content)
    print(f"Local MD5: {local_md5}")
    
    # Upload to S3 and get ETag
    object_key = f"TEST/test_etag_{local_md5[:8]}.bin"
    etag = upload_to_s3(test_file_path, object_key)
    print(f"S3 ETag:  {etag}")
    
    # Compare MD5 and ETag
    if local_md5 == etag:
        print("✅ MD5 hash and ETag match!")
    else:
        print("❌ MD5 hash and ETag do not match!")
        
    # Cleanup
    os.remove(test_file_path)
    print(f"Test file removed: {test_file_path}")
    
    # Return values for further testing
    return {
        "local_md5": local_md5,
        "s3_etag": etag,
        "match": local_md5 == etag
    }

if __name__ == "__main__":
    main()