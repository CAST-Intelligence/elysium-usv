import os
import logging
from azure.storage.blob import BlobServiceClient

def update_blob_metadata(blob_name, metadata_updates):
    """
    Updates the metadata of a blob in Azure Blob Storage
    
    Parameters:
        blob_name: Full name/path of the blob
        metadata_updates: Dict containing metadata key-value pairs to update
    
    Returns:
        bool: True if update was successful, False otherwise
    """
    try:
        # Get connection string from app settings
        connection_string = os.environ["AzureWebJobsStorage"]
        
        # Parse container name and blob path from the full blob name
        # Example: "usvdata/vesselA/file.csv" -> container="usvdata", blob_path="vesselA/file.csv"
        parts = blob_name.split('/', 1)
        if len(parts) < 2:
            logging.error(f"Invalid blob name format: {blob_name}")
            return False
            
        container_name = parts[0]
        blob_path = parts[1]
        
        # Create the BlobServiceClient
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        
        # Get container client
        container_client = blob_service_client.get_container_client(container_name)
        
        # Get blob client
        blob_client = container_client.get_blob_client(blob_path)
        
        # Retrieve existing metadata
        properties = blob_client.get_blob_properties()
        existing_metadata = properties.metadata
        
        # Update with new metadata
        existing_metadata.update(metadata_updates)
        
        # Set the updated metadata on the blob
        blob_client.set_blob_metadata(existing_metadata)
        
        logging.info(f"Successfully updated metadata for blob: {blob_name}")
        return True
        
    except Exception as e:
        logging.error(f"Error updating metadata for blob {blob_name}: {str(e)}")
        return False