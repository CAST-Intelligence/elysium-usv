#!/usr/bin/env python3
"""
Test script to diagnose Azurite authentication issues, specifically with blob metadata operations.
This script tests basic blob operations using the Azure SDK for Python.

Usage:
    python test_azurite.py
"""

import os
import sys
import uuid
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient

# Local Azurite connection string
CONNECTION_STRING = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"

# Test container and blob names
CONTAINER_NAME = "test-container"
BLOB_NAME = f"test-blob-{uuid.uuid4()}.txt"
TEST_CONTENT = b"Hello, Azurite!"

def print_step(step_name):
    """Print a step header."""
    print(f"\n{'=' * 10} {step_name} {'=' * 10}")

def test_azurite_connection():
    """Test basic connection to Azurite."""
    print_step("Testing Azurite connection")
    
    try:
        # Create the BlobServiceClient object
        blob_service_client = BlobServiceClient.from_connection_string(CONNECTION_STRING)
        
        # Print account information
        account_info = blob_service_client.get_account_information()
        print(f"Connected to Azurite emulator version: {account_info['sku_name']}")
        print(f"Account kind: {account_info.get('account_kind', 'unknown')}")
        
        return blob_service_client
    except Exception as e:
        print(f"Error connecting to Azurite: {e}")
        sys.exit(1)

def test_container_operations(blob_service_client):
    """Test container creation and listing."""
    print_step("Testing container operations")
    
    try:
        # Create a container
        container_client = blob_service_client.create_container(CONTAINER_NAME)
        print(f"Container '{CONTAINER_NAME}' created or already exists")
        
        # List containers
        containers = list(blob_service_client.list_containers(include_metadata=True))
        print(f"Found {len(containers)} containers:")
        for container in containers:
            print(f"  - {container.name} (metadata: {container.metadata})")
        
        return container_client
    except Exception as e:
        print(f"Error with container operations: {e}")
        sys.exit(1)

def test_blob_operations(container_client):
    """Test blob upload and download."""
    print_step("Testing blob operations")
    
    try:
        # Upload blob
        blob_client = container_client.get_blob_client(BLOB_NAME)
        blob_client.upload_blob(TEST_CONTENT, overwrite=True)
        print(f"Blob '{BLOB_NAME}' uploaded successfully")
        
        # Download blob
        download_stream = blob_client.download_blob()
        downloaded_content = download_stream.readall()
        print(f"Blob downloaded successfully: {downloaded_content}")
        
        if downloaded_content == TEST_CONTENT:
            print("✅ Content verification passed")
        else:
            print("❌ Content verification failed")
        
        return blob_client
    except Exception as e:
        print(f"Error with blob operations: {e}")
        sys.exit(1)

def test_metadata_operations(blob_client):
    """Test blob metadata operations - the operations causing auth issues in Go."""
    print_step("Testing metadata operations")
    
    try:
        # Get properties
        properties = blob_client.get_blob_properties()
        print(f"Current metadata: {properties.metadata}")
        
        # Set metadata
        metadata = {
            'validationstatus': 'valid',
            'checksum': '123456789abcdef',
            'vesselid': 'VESSEL001'
        }
        
        print(f"Setting metadata: {metadata}")
        blob_client.set_blob_metadata(metadata)
        
        # Verify metadata was set
        properties = blob_client.get_blob_properties()
        print(f"Updated metadata: {properties.metadata}")
        
        # Verify all metadata values were set correctly
        all_set = True
        for key, value in metadata.items():
            if key not in properties.metadata or properties.metadata[key] != value:
                all_set = False
                print(f"❌ Metadata '{key}' not set or incorrect")
        
        if all_set:
            print("✅ All metadata set correctly")
        else:
            print("❌ Some metadata was not set correctly")
            
    except Exception as e:
        print(f"Error with metadata operations: {e}")
        print(f"Error type: {type(e).__name__}")
        return False
    
    return True

def cleanup(blob_service_client):
    """Clean up resources created during test."""
    print_step("Cleaning up")
    
    try:
        blob_service_client.delete_container(CONTAINER_NAME)
        print(f"Container '{CONTAINER_NAME}' deleted")
    except Exception as e:
        print(f"Error during cleanup: {e}")

def main():
    """Run the test suite."""
    print("Azurite Metadata Test Script")
    print(f"Using connection string: {CONNECTION_STRING}")
    
    blob_service_client = test_azurite_connection()
    container_client = test_container_operations(blob_service_client)
    blob_client = test_blob_operations(container_client)
    metadata_success = test_metadata_operations(blob_client)
    cleanup(blob_service_client)
    
    print("\n" + "=" * 40)
    if metadata_success:
        print("✅ All tests PASSED. Metadata operations work correctly.")
        print("The issue in the Go app might be related to different auth handling.")
    else:
        print("❌ Tests FAILED. Metadata operations are problematic in Azurite.")
        print("This matches the behavior seen in the Go app.")

if __name__ == "__main__":
    main()