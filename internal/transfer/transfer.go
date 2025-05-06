package transfer

import (
	"context"
	"fmt"
	"log"
	"path/filepath"
	"strings"
	"time"

	"github.com/CAST-Intelligence/elysium-usv/internal/aws"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
)

// BlobInfo represents information about a blob
type BlobInfo struct {
	ContainerName  string
	BlobName       string
	VesselID       string
	Checksum       string
	ValidationTime string
	Metadata       map[string]string
}

// TransferValidatedBlob transfers a validated blob to S3
func TransferValidatedBlob(
	ctx context.Context,
	blobClient *azblob.Client,
	s3Client *aws.S3Client,
	containerName string,
	blobName string,
) error {
	// Get blob info
	blobInfo, err := getBlobInfo(ctx, blobClient, containerName, blobName)
	if err != nil {
		return fmt.Errorf("failed to get blob info: %w", err)
	}

	// Check if the blob has been validated - case insensitive check
	validationStatus := ""
	for k, v := range blobInfo.Metadata {
		if strings.EqualFold(k, "validationstatus") {
			validationStatus = v
			break
		}
	}
	if validationStatus != "valid" {
		return fmt.Errorf("blob has not been validated or validation failed")
	}

	// Download the blob
	containerClient := blobClient.ServiceClient().NewContainerClient(containerName)
	blobItemClient := containerClient.NewBlobClient(blobName)
	
	// Download the blob
	response, err := blobItemClient.DownloadStream(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to download blob: %w", err)
	}

	// Extract vessel ID from metadata or blob name - case insensitive check
	vesselID := ""
	for k, v := range blobInfo.Metadata {
		if strings.EqualFold(k, "vesselid") {
			vesselID = v
			break
		}
	}
	if vesselID == "" {
		// Try to extract from the blob name (first segment)
		parts := strings.Split(blobName, "/")
		if len(parts) > 0 {
			vesselID = parts[0]
		} else {
			return fmt.Errorf("vessel ID not found in metadata or blob name")
		}
	}

	// Build the S3 object key
	// For S3, we'll use the format: vesselID/data/filename
	fileName := filepath.Base(blobName)
	s3Key := aws.BuildObjectKey(vesselID, fileName)

	// Upload to S3 and get the ETag (MD5 hash)
	etag, err := s3Client.UploadObject(ctx, s3Key, response.Body)
	if err != nil {
		return fmt.Errorf("failed to upload to S3: %w", err)
	}

	// Verify the upload was successful
	exists, err := s3Client.VerifyObject(ctx, s3Key)
	if err != nil || !exists {
		return fmt.Errorf("failed to verify S3 upload: %w", err)
	}
	
	// Check if we got a valid ETag
	if etag == "" {
		log.Printf("Warning: No ETag received for %s", s3Key)
	}

	// Get properties again to get current metadata
	props, err := blobItemClient.GetProperties(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get blob properties: %w", err)
	}

	// Update blob metadata to indicate successful transfer
	updatedMetadata := map[string]*string{}
	for k, v := range props.Metadata {
		updatedMetadata[k] = v
	}
	
	transferredStatus := "transferred"
	timestamp := getCurrentTimestamp()
	s3Dest := fmt.Sprintf("%s/%s", s3Client.BucketName(), s3Key)
	
	updatedMetadata["transferstatus"] = &transferredStatus
	updatedMetadata["transfertimestamp"] = &timestamp
	updatedMetadata["s3destination"] = &s3Dest
	
	// If we have a valid ETag (MD5), store it in the metadata
	if etag != "" {
		updatedMetadata["s3etag"] = &etag
	}

	// Set the metadata
	_, err = blobItemClient.SetMetadata(ctx, updatedMetadata, nil)
	if err != nil {
		return fmt.Errorf("failed to update blob metadata: %w", err)
	}

	return nil
}

// getBlobInfo retrieves information about a blob
func getBlobInfo(ctx context.Context, client *azblob.Client, containerName, blobName string) (*BlobInfo, error) {
	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlobClient(blobName)

	// Get blob properties
	props, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get blob properties: %w", err)
	}

	// Convert metadata from map[string]*string to map[string]string
	metadata := make(map[string]string)
	for k, v := range props.Metadata {
		if v != nil {
			metadata[k] = *v
		}
	}

	// Extract metadata
	info := &BlobInfo{
		ContainerName: containerName,
		BlobName:      blobName,
		Metadata:      metadata,
	}

	// Extract additional metadata fields into struct fields - case insensitive lookups
	for k, v := range metadata {
		if strings.EqualFold(k, "checksum") {
			info.Checksum = v
		} else if strings.EqualFold(k, "vesselid") {
			info.VesselID = v
		} else if strings.EqualFold(k, "validationtimestamp") {
			info.ValidationTime = v
		}
	}

	return info, nil
}

// getCurrentTimestamp returns the current timestamp in ISO 8601 format
func getCurrentTimestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}