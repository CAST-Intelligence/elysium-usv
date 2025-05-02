package validation

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
)

// VerifyChecksum validates the checksum of a blob against the expected value
func VerifyChecksum(ctx context.Context, client *azblob.Client, containerName, blobName string, expectedChecksum string) (bool, error) {
	// Get a container client and then a blob client
	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlobClient(blobName)
	
	// Download the blob
	response, err := blobClient.DownloadStream(ctx, nil)
	if err != nil {
		return false, fmt.Errorf("failed to download blob: %w", err)
	}

	// Read the blob data
	body := response.Body
	defer body.Close()

	// Buffer to store the blob data
	var buffer bytes.Buffer
	_, err = io.Copy(&buffer, body)
	if err != nil {
		return false, fmt.Errorf("failed to read blob data: %w", err)
	}

	// Calculate the checksum
	calculatedChecksum, err := calculateSHA256(buffer.Bytes())
	if err != nil {
		return false, fmt.Errorf("failed to calculate checksum: %w", err)
	}

	// Compare the checksums
	isValid := calculatedChecksum == expectedChecksum
	return isValid, nil
}

// calculateSHA256 calculates the SHA256 hash of the data
func calculateSHA256(data []byte) (string, error) {
	hasher := sha256.New()
	_, err := hasher.Write(data)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hasher.Sum(nil)), nil
}

// ValidateBlob performs validation on a blob and updates its metadata
func ValidateBlob(ctx context.Context, client *azblob.Client, containerName, blobName string) (bool, error) {
	// Get a container client and then a blob client
	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlobClient(blobName)

	// Get the blob properties to access metadata
	props, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		return false, fmt.Errorf("failed to get blob properties: %w", err)
	}

	// Extract metadata - need to handle nil strings
	metadata := make(map[string]string)
	for k, v := range props.Metadata {
		if v != nil {
			metadata[k] = *v
		}
	}

	// Check for checksum in metadata
	expectedChecksum, ok := metadata["checksum"]
	if !ok {
		return false, fmt.Errorf("checksum not found in blob metadata")
	}

	// Verify the checksum
	isValid, err := VerifyChecksum(ctx, client, containerName, blobName, expectedChecksum)
	if err != nil {
		return false, err
	}

	// Update the metadata map for Azure SDK
	updatedMetadata := map[string]*string{}
	for k, v := range props.Metadata {
		updatedMetadata[k] = v
	}
	
	// Add validation status fields
	validStatus := getValidationStatus(isValid)
	timestamp := getCurrentTimestamp()
	validStatusPtr := &validStatus
	timestampPtr := &timestamp
	updatedMetadata["validationstatus"] = validStatusPtr
	updatedMetadata["validationtimestamp"] = timestampPtr

	// Set the updated metadata
	_, err = blobClient.SetMetadata(ctx, updatedMetadata, nil)
	if err != nil {
		return false, fmt.Errorf("failed to update blob metadata: %w", err)
	}

	return isValid, nil
}

// getValidationStatus returns the validation status string
func getValidationStatus(isValid bool) string {
	if isValid {
		return "valid"
	}
	return "invalid"
}

// getCurrentTimestamp returns the current time in ISO 8601 format
func getCurrentTimestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}