import logging
import azure.functions as func
import json
import uuid
import datetime
import os
from azure.data.tables import TableServiceClient

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Generates audit certificates for data deletion compliance.
    Creates a digital record of data destruction for compliance purposes.
    
    Parameters:
        req: HTTP request containing blob details for certificate generation
    
    Returns:
        HTTP response with certificate ID and details
    """
    logging.info('Audit Certificate Generation function processed a request.')

    try:
        req_body = req.get_json()
        blob_name = req_body.get('blobName')
        metadata = req_body.get('metadata', {})
        transfer_timestamp = req_body.get('transferTimestamp')
        s3_destination = req_body.get('s3Destination')
        
        # Validate inputs
        if not blob_name or not transfer_timestamp or not s3_destination:
            return func.HttpResponse(
                json.dumps({"error": "Missing required parameters for certificate generation."}),
                mimetype="application/json",
                status_code=400
            )
            
        # Generate unique certificate ID
        certificate_id = str(uuid.uuid4())
        
        # Create certificate data
        certificate = {
            "certificateId": certificate_id,
            "generationTimestamp": datetime.datetime.utcnow().isoformat(),
            "blobName": blob_name,
            "vesselId": metadata.get('vesselId', 'unknown'),
            "originalTimestamp": metadata.get('timestamp', 'unknown'),
            "validationTimestamp": metadata.get('validationTimestamp', 'unknown'),
            "transferTimestamp": transfer_timestamp,
            "s3Destination": s3_destination,
            "deletionTimestamp": datetime.datetime.utcnow().isoformat(),
            "issuedBy": "Elysium Data Pipeline"
        }
        
        # Store certificate in Azure Table Storage for long-term audit
        store_certificate(certificate)
        
        # Return certificate data
        return func.HttpResponse(
            json.dumps(certificate),
            mimetype="application/json",
            status_code=200
        )
    
    except ValueError as e:
        return func.HttpResponse(
            json.dumps({"error": f"Invalid request format: {str(e)}"}),
            mimetype="application/json",
            status_code=400
        )
    except Exception as e:
        logging.error(f"Error generating audit certificate: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error generating certificate"}),
            mimetype="application/json",
            status_code=500
        )

def store_certificate(certificate):
    """
    Stores the generated certificate in Azure Table Storage for long-term audit purposes.
    
    Parameters:
        certificate: Dict containing certificate data
    """
    try:
        # Get connection string from app settings
        connection_string = os.environ["AzureWebJobsStorage"]
        
        # Create table service client
        table_service = TableServiceClient.from_connection_string(connection_string)
        
        # Get table client - create if it doesn't exist
        table_name = "AuditCertificates"
        table_client = table_service.create_table_if_not_exists(table_name)
        
        # Create entity for table storage
        entity = {
            "PartitionKey": certificate["vesselId"],
            "RowKey": certificate["certificateId"],
            "BlobName": certificate["blobName"],
            "GenerationTimestamp": certificate["generationTimestamp"],
            "OriginalTimestamp": certificate["originalTimestamp"],
            "ValidationTimestamp": certificate["validationTimestamp"],
            "TransferTimestamp": certificate["transferTimestamp"],
            "S3Destination": certificate["s3Destination"],
            "DeletionTimestamp": certificate["deletionTimestamp"],
            "IssuedBy": certificate["issuedBy"]
        }
        
        # Insert entity
        table_client.create_entity(entity)
        
        logging.info(f"Certificate {certificate['certificateId']} stored in Azure Table Storage")
        
    except Exception as e:
        logging.error(f"Error storing certificate in Table Storage: {str(e)}")
        # We don't raise the exception here - we log it but still return the certificate
        # This ensures the Logic App can continue even if table storage fails