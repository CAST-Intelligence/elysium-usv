package azure

import (
	"fmt"

	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
)

// Client encapsulates all Azure services used by the application
type Client struct {
	BlobClient  *azblob.Client
	QueueClient *azqueue.ServiceClient
}

// NewClient creates a new Azure client with the given configuration
func NewClient(cfg *config.Config) (*Client, error) {
	// Create the Azure clients
	blobClient, err := createBlobClient(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create blob client: %w", err)
	}

	queueClient, err := createQueueClient(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create queue client: %w", err)
	}

	return &Client{
		BlobClient:  blobClient,
		QueueClient: queueClient,
	}, nil
}

// createBlobClient creates a new Azure Blob Storage client
func createBlobClient(cfg *config.Config) (*azblob.Client, error) {
	// Try to use connection string first
	if cfg.AzureStorageConnectionString != "" {
		return azblob.NewClientFromConnectionString(cfg.AzureStorageConnectionString, nil)
	}

	// Fall back to managed identity or other authentication methods
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create credential: %w", err)
	}

	return azblob.NewClient("https://ACCOUNT_NAME.blob.core.windows.net", cred, nil)
}

// createQueueClient creates a new Azure Queue Storage client
func createQueueClient(cfg *config.Config) (*azqueue.ServiceClient, error) {
	// Try to use connection string first
	if cfg.AzureStorageConnectionString != "" {
		return azqueue.NewServiceClientFromConnectionString(cfg.AzureStorageConnectionString, nil)
	}

	// Fall back to managed identity or other authentication methods
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create credential: %w", err)
	}

	return azqueue.NewServiceClient("https://ACCOUNT_NAME.queue.core.windows.net", cred, nil)
}