#!/usr/bin/env python3

import argparse
import os
import random
import time
import datetime
import uuid
import json
import hashlib
import sys
from azure.storage.blob import BlobServiceClient, ContentSettings

def generate_mock_survey_data(size_kb, valid=True):
    """
    Generate mock survey data of specified size.
    
    Parameters:
        size_kb: Size of data to generate in KB
        valid: Whether to generate valid data (True) or corrupt data (False)
    
    Returns:
        Tuple containing (data_bytes, checksum)
    """
    # Generate random bytes data
    data_bytes = os.urandom(size_kb * 1024)
    
    if not valid:
        # Corrupt the data slightly by modifying a few random bytes
        data_list = bytearray(data_bytes)
        for _ in range(10):
            pos = random.randint(0, len(data_list) - 1)
            data_list[pos] = random.randint(0, 255)
        data_bytes = bytes(data_list)
    
    # Calculate SHA256 checksum
    sha256_hash = hashlib.sha256(data_bytes).hexdigest()
    
    return data_bytes, sha256_hash

def upload_mock_data(connection_string, container_name, vessel_id, file_count, size_range, 
                     corrupt_percentage=0, time_interval=None):
    """
    Upload mock survey data to Azure Blob Storage.
    
    Parameters:
        connection_string: Azure Storage connection string
        container_name: Blob container name
        vessel_id: Vessel identifier
        file_count: Number of files to generate
        size_range: Tuple of (min_kb, max_kb) for file sizes
        corrupt_percentage: Percentage of files to corrupt (0-100)
        time_interval: Optional delay between uploads (in seconds)
    """
    try:
        # Create blob service client
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        
        # Create container if it doesn't exist
        try:
            container_client = blob_service_client.create_container(container_name)
            print(f"Container '{container_name}' created successfully")
        except:
            container_client = blob_service_client.get_container_client(container_name)
            print(f"Using existing container '{container_name}'")
        
        # Generate and upload files
        for i in range(file_count):
            # Determine if this file should be corrupt
            corrupt = random.random() < (corrupt_percentage / 100.0)
            
            # Generate random file size
            size_kb = random.randint(size_range[0], size_range[1])
            
            # Generate the data
            data_bytes, checksum = generate_mock_survey_data(size_kb, not corrupt)
            
            # Corrupt the checksum if needed while keeping the data valid
            if corrupt:
                checksum = ''.join(random.choice('0123456789abcdef') for _ in range(64))
                print(f"File {i+1}/{file_count} will have invalid checksum")
            
            # Generate a timestamp with slight randomness
            timestamp = datetime.datetime.utcnow() - datetime.timedelta(
                minutes=random.randint(0, 30),
                seconds=random.randint(0, 59)
            )
            timestamp_str = timestamp.isoformat()
            
            # Create blob name 
            blob_name = f"{vessel_id}/data_{timestamp.strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}.bin"
            
            # Set metadata
            metadata = {
                "vesselId": vessel_id,
                "timestamp": timestamp_str,
                "checksum": checksum,
                "checksumAlgorithm": "SHA256",
                "originalSize": str(size_kb),
                "isTest": "true"
            }
            
            # Upload to blob storage
            blob_client = container_client.get_blob_client(blob_name)
            
            blob_client.upload_blob(
                data_bytes, 
                overwrite=True,
                metadata=metadata,
                content_settings=ContentSettings(content_type="application/octet-stream")
            )
            
            print(f"Uploaded file {i+1}/{file_count}: {blob_name} ({size_kb} KB, {'corrupted' if corrupt else 'valid'})")
            
            # Sleep if interval specified
            if time_interval and i < file_count - 1:
                print(f"Waiting {time_interval} seconds before next upload...")
                time.sleep(time_interval)
                
        print(f"\nCompleted upload of {file_count} mock survey data files")
        
    except Exception as e:
        print(f"Error uploading mock data: {str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Generate and upload mock USV survey data to Azure Blob Storage")
    
    parser.add_argument("--connection-string", 
                        help="Azure Storage connection string")
    parser.add_argument("--container", default="usvdata",
                        help="Blob container name (default: usvdata)")
    parser.add_argument("--vessel-id", default="VESSEL001",
                        help="Vessel identifier (default: VESSEL001)")
    parser.add_argument("--count", type=int, default=5,
                        help="Number of files to generate (default: 5)")
    parser.add_argument("--min-size", type=int, default=10,
                        help="Minimum file size in KB (default: 10)")
    parser.add_argument("--max-size", type=int, default=100,
                        help="Maximum file size in KB (default: 100)")
    parser.add_argument("--corrupt", type=float, default=10.0,
                        help="Percentage of files to corrupt (default: 10%%)")
    parser.add_argument("--interval", type=float, default=None,
                        help="Time interval between uploads in seconds (default: None)")
    
    args = parser.parse_args()
    
    # Connection string must be provided or in environment
    connection_string = args.connection_string or os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    if not connection_string:
        print("Error: Azure Storage connection string must be provided")
        parser.print_help()
        sys.exit(1)
    
    # Upload the mock data
    upload_mock_data(
        connection_string=connection_string,
        container_name=args.container,
        vessel_id=args.vessel_id,
        file_count=args.count,
        size_range=(args.min_size, args.max_size),
        corrupt_percentage=args.corrupt,
        time_interval=args.interval
    )

if __name__ == "__main__":
    main()