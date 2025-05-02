package worker

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/CAST-Intelligence/elysium-usv/internal/validation"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
)

// ValidationWorker processes blobs for validation
type ValidationWorker struct {
	worker       *Worker
	blobClient   *azblob.Client
	queueClient  *azqueue.ServiceClient
	containerName string
	queueName     string
}

// NewValidationWorker creates a new worker for blob validation
func NewValidationWorker(
	cfg *config.Config,
	blobClient *azblob.Client,
	queueClient *azqueue.ServiceClient,
) *ValidationWorker {
	vw := &ValidationWorker{
		blobClient:    blobClient,
		queueClient:   queueClient,
		containerName: cfg.BlobContainerName,
		queueName:     cfg.ValidationQueueName,
	}

	// Create the underlying worker
	worker := NewWorker(
		"validation",
		vw.processValidationQueue,
		30*time.Second, // Poll every 30 seconds
		cfg.ProcessingBatchSize,
		cfg.OperationRetryCount,
	)

	vw.worker = worker
	return vw
}

// Start starts the validation worker
func (vw *ValidationWorker) Start() {
	vw.worker.Start()
}

// Stop stops the validation worker
func (vw *ValidationWorker) Stop() {
	vw.worker.Stop()
}

// Status returns the worker status
func (vw *ValidationWorker) Status() string {
	return vw.worker.Status()
}

// LastRun returns the time of the last run
func (vw *ValidationWorker) LastRun() time.Time {
	return vw.worker.LastRun()
}

// processValidationQueue processes messages from the validation queue
func (vw *ValidationWorker) processValidationQueue(ctx context.Context, batchSize int) error {
	queueClient := vw.queueClient.NewQueueClient(vw.queueName)

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

	// If no messages, return without error
	if len(resp.Messages) == 0 {
		log.Println("No validation messages found in queue")
		return nil
	}
	
	log.Printf("Received %d messages from validation queue", len(resp.Messages))

	// Process each message
	for _, msg := range resp.Messages {
		// Extract the blob name from the message
		// Need to check if MessageText is nil
		if msg.MessageText == nil {
			log.Printf("Received message with nil MessageText, skipping")
			continue
		}
		
		blobName := *msg.MessageText
		log.Printf("Processing validation message for blob: %s", blobName)
		
		// Validate the blob
		isValid, err := validation.ValidateBlob(ctx, vw.blobClient, vw.containerName, blobName)
		if err != nil {
			log.Printf("Failed to validate blob %s: %v", blobName, err)
			continue
		}

		// If validation done (success or failure), delete the message from the queue
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

		// If valid, add to the transfer queue
		if isValid {
			log.Printf("Blob %s validated successfully, adding to transfer queue", blobName)
			
			// Queue transfer task 
			transferQueueName := "transfer-queue"
			if vw.queueName != "validation-queue" {
				// If we're using a custom queue name, transform it appropriately
				transferQueueName = strings.Replace(vw.queueName, "validation", "transfer", 1)
			}
			
			if err := QueueTransferTaskInternal(ctx, vw.queueClient, transferQueueName, blobName); err != nil {
				log.Printf("Failed to queue transfer task for blob %s: %v", blobName, err)
			}
		} else {
			log.Printf("Blob %s validation failed", blobName)
		}
	}

	return nil
}