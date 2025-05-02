package worker

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/CAST-Intelligence/elysium-usv/internal/audit"
	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
)

// CleanupWorker processes blobs for cleanup after transfer
type CleanupWorker struct {
	worker        *Worker
	blobClient    *azblob.Client
	queueClient   *azqueue.ServiceClient
	containerName string
	queueName     string
	retentionDays int
}

// NewCleanupWorker creates a new worker for blob cleanup
func NewCleanupWorker(
	cfg *config.Config,
	blobClient *azblob.Client,
	queueClient *azqueue.ServiceClient,
) *CleanupWorker {
	cw := &CleanupWorker{
		blobClient:    blobClient,
		queueClient:   queueClient,
		containerName: cfg.BlobContainerName,
		queueName:     cfg.CleanupQueueName,
		retentionDays: cfg.RetentionDays,
	}

	// Create the underlying worker
	worker := NewWorker(
		"cleanup",
		cw.processCleanupQueue,
		30*time.Second, // Poll every 30 seconds
		cfg.ProcessingBatchSize,
		cfg.OperationRetryCount,
	)

	cw.worker = worker
	return cw
}

// Start starts the cleanup worker
func (cw *CleanupWorker) Start() {
	cw.worker.Start()
}

// Stop stops the cleanup worker
func (cw *CleanupWorker) Stop() {
	cw.worker.Stop()
}

// Status returns the worker status
func (cw *CleanupWorker) Status() string {
	return cw.worker.Status()
}

// LastRun returns the time of the last run
func (cw *CleanupWorker) LastRun() time.Time {
	return cw.worker.LastRun()
}

// processCleanupQueue processes messages from the cleanup queue
func (cw *CleanupWorker) processCleanupQueue(ctx context.Context, batchSize int) error {
	queueClient := cw.queueClient.NewQueueClient(cw.queueName)

	// Create options for dequeuing messages
	options := &azqueue.DequeueMessagesOptions{
		NumberOfMessages: &[]int32{int32(batchSize)}[0], // Convert batch size to int32 pointer
		VisibilityTimeout: &[]int32{30}[0], // 30 seconds visibility timeout
	}
	
	// Dequeue messages from the queue
	resp, err := queueClient.DequeueMessages(ctx, options)
	if err != nil {
		return fmt.Errorf("failed to dequeue messages: %w", err)
	}

	// If no messages, process expired blobs instead
	if len(resp.Messages) == 0 {
		log.Println("No cleanup messages found in queue, checking for expired blobs")
		return cw.processExpiredBlobs(ctx, batchSize)
	}
	
	log.Printf("Received %d messages from cleanup queue", len(resp.Messages))

	// Process each message
	for _, msg := range resp.Messages {
		// Extract the blob name from the message
		// Need to check if MessageText is nil
		if msg.MessageText == nil {
			log.Printf("Received message with nil MessageText, skipping")
			continue
		}
		
		blobName := *msg.MessageText
		log.Printf("Processing cleanup message for blob: %s", blobName)

		// Cleanup the blob
		err := cw.cleanupBlob(ctx, blobName)
		if err != nil {
			log.Printf("Failed to cleanup blob %s: %v", blobName, err)
			continue
		}

		// If cleanup successful, delete the message from the queue
		// Need to check if MessageID and PopReceipt are nil
		if msg.MessageID == nil || msg.PopReceipt == nil {
			log.Printf("Received message with nil MessageID or PopReceipt, skipping")
			continue
		}
		
		_, err = queueClient.DeleteMessage(ctx, *msg.MessageID, *msg.PopReceipt, nil)
		if err != nil {
			log.Printf("Failed to delete message for blob %s: %v", blobName, err)
			continue
		}

		log.Printf("Blob %s cleaned up successfully", blobName)
	}

	return nil
}

// processExpiredBlobs looks for blobs that are beyond retention period and cleans them up
func (cw *CleanupWorker) processExpiredBlobs(ctx context.Context, batchSize int) error {
	// Create container client
	containerClient := cw.blobClient.ServiceClient().NewContainerClient(cw.containerName)

	// List blobs
	pager := containerClient.NewListBlobsFlatPager(nil)
	
	processed := 0
	for pager.More() && processed < batchSize {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list blobs: %w", err)
		}
		
		for _, blob := range resp.Segment.BlobItems {
			// Check if the blob has been transferred (via metadata)
			blobClient := containerClient.NewBlobClient(*blob.Name)
			props, err := blobClient.GetProperties(ctx, nil)
			if err != nil {
				log.Printf("Failed to get properties for blob %s: %v", *blob.Name, err)
				continue
			}

			// Skip if not transferred yet
			var transferStatus string
			if v := props.Metadata["transferstatus"]; v != nil {
				transferStatus = *v
			}
			
			if transferStatus != "transferred" {
				continue
			}

			// Check if the blob is past the retention period
			if blob.Properties.LastModified != nil {
				lastModTime := *blob.Properties.LastModified
				retentionPeriod := time.Duration(cw.retentionDays) * 24 * time.Hour
				
				if time.Since(lastModTime) > retentionPeriod {
					// Blob is past retention, clean it up
					if err := cw.cleanupBlob(ctx, *blob.Name); err != nil {
						log.Printf("Failed to cleanup expired blob %s: %v", *blob.Name, err)
						continue
					}
					
					log.Printf("Expired blob %s cleaned up successfully", *blob.Name)
					processed++
					
					if processed >= batchSize {
						break
					}
				}
			}
		}
	}

	return nil
}

// cleanupBlob performs cleanup operations on a blob
func (cw *CleanupWorker) cleanupBlob(ctx context.Context, blobName string) error {
	// Create blob client
	containerClient := cw.blobClient.ServiceClient().NewContainerClient(cw.containerName)
	blobClient := containerClient.NewBlobClient(blobName)
	
	// Get properties to verify it has been transferred
	props, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get blob properties: %w", err)
	}
	
	// Ensure the blob has been transferred before deletion
	var transferStatus, s3Destination string
	if v := props.Metadata["transferstatus"]; v != nil {
		transferStatus = *v
	}
	
	if transferStatus != "transferred" {
		return fmt.Errorf("blob %s has not been transferred yet", blobName)
	}
	
	// Get the S3 destination for the audit log
	if v := props.Metadata["s3destination"]; v != nil {
		s3Destination = *v
	} else {
		s3Destination = "unknown"
	}
	
	// Generate an audit certificate before deletion
	if err := audit.GenerateAuditCertificate(ctx, blobName, s3Destination); err != nil {
		return fmt.Errorf("failed to generate audit certificate: %w", err)
	}
	
	// Delete the blob
	_, err = blobClient.Delete(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to delete blob: %w", err)
	}
	
	return nil
}

// QueueCleanupTaskInternal adds a blob to the cleanup queue - for internal use by the transfer worker
func QueueCleanupTaskInternal(ctx context.Context, queueClient *azqueue.ServiceClient, queueName, blobName string) error {
	client := queueClient.NewQueueClient(queueName)
	
	// Add the message to the queue
	_, err := client.EnqueueMessage(ctx, blobName, nil)
	if err != nil {
		return fmt.Errorf("failed to queue cleanup task: %w", err)
	}
	
	return nil
}