import logging
import azure.functions as func
import hashlib
import json
import datetime

from .blob_metadata_updater import update_blob_metadata

def main(blobTrigger: func.InputStream, inputBlob: func.InputStream, outputQueueItem: func.Out[str]) -> None:
    """
    Data Validation Azure Function that verifies the integrity of USV data files
    using checksum verification.
    
    Parameters:
        blobTrigger: Triggered when new blob is created
        inputBlob: Contents of the uploaded blob
        outputQueueItem: Queue for sending validated data for processing
    """
    logging.info(f"Data Validation Function processing blob: {blobTrigger.name}")
    
    try:
        # Extract metadata from blob
        metadata = blobTrigger.metadata
        
        # Verify required metadata exists
        if not all(key in metadata for key in ['vesselId', 'timestamp', 'checksum']):
            raise ValueError("Required metadata (vesselId, timestamp, or checksum) is missing")
            
        vessel_id = metadata.get('vesselId')
        timestamp = metadata.get('timestamp')
        provided_checksum = metadata.get('checksum')
        checksum_algorithm = metadata.get('checksumAlgorithm', 'SHA256')
        
        # Calculate actual checksum
        actual_checksum = calculate_checksum(inputBlob, checksum_algorithm)
        
        # Verify checksum
        is_valid = provided_checksum.lower() == actual_checksum.lower()
        
        # Create validation result
        validation_result = {
            "blobName": blobTrigger.name,
            "vesselId": vessel_id,
            "timestamp": timestamp,
            "isValid": is_valid,
            "validationTimestamp": datetime.datetime.utcnow().isoformat(),
            "errorMessage": None if is_valid else "Checksum verification failed"
        }
        
        # Update the blob metadata with validation results
        metadata_updates = {
            "validationStatus": "valid" if is_valid else "invalid",
            "validationTimestamp": datetime.datetime.utcnow().isoformat()
        }
        
        update_result = update_blob_metadata(blobTrigger.name, metadata_updates)
        if not update_result:
            logging.warning(f"Failed to update metadata for blob {blobTrigger.name}")
        
        # If valid, add to processing queue
        if is_valid:
            logging.info(f"Blob {blobTrigger.name} passed validation. Adding to processing queue.")
            outputQueueItem.set(json.dumps(validation_result))
        else:
            logging.error(f"Blob {blobTrigger.name} failed validation. Expected: {provided_checksum}, Actual: {actual_checksum}")
            # TODO: Add to error notification system or a separate error queue
            # In a production environment, we would typically:
            # 1. Send alert to monitoring system
            # 2. Move invalid file to a quarantine container
            # 3. Record failure in an audit database
    
    except Exception as e:
        logging.error(f"Error validating blob {blobTrigger.name}: {str(e)}")
        # In production, would add more robust error handling:
        # 1. Send notification to operations team
        # 2. Log detailed error information for diagnostic purposes
        # 3. Potentially retry logic for transient errors

def calculate_checksum(stream, algorithm='SHA256'):
    """
    Calculate checksum of file stream using specified algorithm
    
    Parameters:
        stream: File stream to calculate checksum for
        algorithm: Checksum algorithm to use (SHA256, MD5, SHA1)
    
    Returns:
        Hexadecimal string representation of the checksum
    """
    # Reset stream position
    stream.seek(0)
    
    # Select hashing algorithm
    if algorithm.upper() == 'MD5':
        hash_obj = hashlib.md5()
    elif algorithm.upper() == 'SHA1':
        hash_obj = hashlib.sha1()
    else:  # Default to SHA256
        hash_obj = hashlib.sha256()
    
    # Process the stream in chunks to handle large files efficiently
    chunk_size = 4096
    for byte_block in iter(lambda: stream.read(chunk_size), b""):
        hash_obj.update(byte_block)
    
    # Reset stream position for other operations
    stream.seek(0)
    
    # Return hexadecimal representation of hash
    return hash_obj.hexdigest()