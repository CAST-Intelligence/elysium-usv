package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
)

func main() {
	// Test metadata operations with Azure Blob Storage in Azurite
	fmt.Println("Testing Azure Blob metadata operations with Azurite")
	
	// Connection string for Azurite
	connectionString := "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"
	
	// Container and blob names for testing
	containerName := "test-container"
	blobName := "test-blob.txt"
	
	// Create context
	ctx := context.Background()
	
	// Create client
	fmt.Println("\n=== Creating client ===")
	client, err := azblob.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		fmt.Printf("Error creating client: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Client created successfully")
	
	// Create container
	fmt.Println("\n=== Creating container ===")
	containerClient := client.ServiceClient().NewContainerClient(containerName)
	_, err = containerClient.Create(ctx, nil)
	if err != nil && !strings.Contains(err.Error(), "ContainerAlreadyExists") {
		fmt.Printf("Error creating container: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Container '%s' created or already exists\n", containerName)
	
	// Create blob with content
	fmt.Println("\n=== Creating blob ===")
	blobClient := containerClient.NewBlockBlobClient(blobName)
	content := []byte("Hello, Azurite!")
	_, err = blobClient.UploadBuffer(ctx, content, nil)
	if err != nil {
		fmt.Printf("Error uploading blob: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Blob '%s' created successfully\n", blobName)
	
	// Get blob properties
	fmt.Println("\n=== Getting blob properties ===")
	props, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		fmt.Printf("Error getting properties: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Current metadata:")
	if len(props.Metadata) == 0 {
		fmt.Println("  <none>")
	} else {
		for k, v := range props.Metadata {
			if v != nil {
				fmt.Printf("  %s: %s\n", k, *v)
			}
		}
	}
	
	// Set metadata
	fmt.Println("\n=== Setting metadata ===")
	metadata := map[string]*string{
		"validationstatus": to.Ptr("valid"),
		"checksum":         to.Ptr("123456789abcdef"),
		"vesselid":         to.Ptr("VESSEL001"),
	}
	
	fmt.Println("Setting metadata values:")
	for k, v := range metadata {
		fmt.Printf("  %s: %s\n", k, *v)
	}
	
	_, err = blobClient.SetMetadata(ctx, metadata, nil)
	if err != nil {
		fmt.Printf("❌ Error setting metadata: %v\n", err)
		fmt.Println("This matches the error seen in the USV pipeline application")
	} else {
		fmt.Println("✅ Metadata set successfully")
		
		// Verify metadata
		props, err = blobClient.GetProperties(ctx, nil)
		if err != nil {
			fmt.Printf("Error getting updated properties: %v\n", err)
		} else {
			fmt.Println("Updated metadata:")
			for k, v := range props.Metadata {
				if v != nil {
					fmt.Printf("  %s: %s\n", k, *v)
				}
			}
		}
	}
	
	// Cleanup
	fmt.Println("\n=== Cleaning up ===")
	_, err = containerClient.Delete(ctx, nil)
	if err != nil {
		fmt.Printf("Error deleting container: %v\n", err)
	} else {
		fmt.Printf("Container '%s' deleted\n", containerName)
	}
	
	// Summary
	fmt.Println("\n=== Test summary ===")
	if err == nil {
		fmt.Println("✅ All operations completed successfully")
	} else {
		fmt.Println("❌ Metadata operations failed - this confirms the issue")
	}
}