package worker

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
	"github.com/CAST-Intelligence/elysium-usv/internal/aws"
	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/CAST-Intelligence/elysium-usv/internal/transfer"
)

// TransferWorker processes validated blobs for transfer to S3
type TransferWorker struct {
	worker        *Worker
	blobClient    *azblob.Client
	queueClient   *azqueue.ServiceClient
	s3Client      *aws.S3Client
	containerName string
	queueName     string
}

// NewTransferWorker creates a new worker for S3 transfers
func NewTransferWorker(
	cfg *config.Config,
	blobClient *azblob.Client,
	queueClient *azqueue.ServiceClient,
	s3Client *aws.S3Client,
) *TransferWorker {
	tw := &TransferWorker{
		blobClient:    blobClient,
		queueClient:   queueClient,
		s3Client:      s3Client,
		containerName: cfg.BlobContainerName,
		queueName:     cfg.TransferQueueName,
	}

	// Create the underlying worker
	worker := NewWorker(
		"transfer",
		tw.processTransferQueue,
		30*time.Second, // Poll every 30 seconds
		cfg.ProcessingBatchSize,
		cfg.OperationRetryCount,
	)

	tw.worker = worker
	return tw
}

// Start starts the transfer worker
func (tw *TransferWorker) Start() {
	tw.worker.Start()
}

// Stop stops the transfer worker
func (tw *TransferWorker) Stop() {
	tw.worker.Stop()
}

// Status returns the worker status
func (tw *TransferWorker) Status() string {
	return tw.worker.Status()
}

// LastRun returns the time of the last run
func (tw *TransferWorker) LastRun() time.Time {
	return tw.worker.LastRun()
}

// processTransferQueue processes messages from the transfer queue
func (tw *TransferWorker) processTransferQueue(ctx context.Context, batchSize int) error {
	queueClient := tw.queueClient.NewQueueClient(tw.queueName)

	// Create options for dequeuing messages
	options := &azqueue.DequeueMessagesOptions{
		NumberOfMessages:  &[]int32{int32(batchSize)}[0], // Convert batch size to int32 pointer
		VisibilityTimeout: &[]int32{30}[0],               // 30 seconds visibility timeout
	}

	// Dequeue messages from the queue
	resp, err := queueClient.DequeueMessages(ctx, options)
	if err != nil {
		return fmt.Errorf("failed to dequeue messages: %w", err)
	}

	// If no messages, return without error
	if len(resp.Messages) == 0 {
		log.Println("No transfer messages found in queue")
		return nil
	}

	log.Printf("Received %d messages from transfer queue", len(resp.Messages))

	// Process each message
	for _, msg := range resp.Messages {
		// Extract the blob name from the message
		// Need to check if MessageText is nil
		if msg.MessageText == nil {
			log.Printf("Received message with nil MessageText, skipping")
			continue
		}

		blobName := *msg.MessageText
		log.Printf("Processing transfer message for blob: %s", blobName)

		// Transfer the blob to S3
		err := transfer.TransferValidatedBlob(ctx, tw.blobClient, tw.s3Client, tw.containerName, blobName)
		if err != nil {
			log.Printf("Failed to transfer blob %s: %v", blobName, err)
			continue
		}

		// If transfer successful, delete the message from the queue
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

		// Log the transfer for audit purposes
		if err := tw.logTransfer(ctx, blobName); err != nil {
			log.Printf("Failed to log transfer for blob %s: %v", blobName, err)
		}

		log.Printf("Blob %s transferred successfully to S3", blobName)

		// Queue cleanup task if needed
		cleanupQueueName := "cleanup-queue"
		if tw.queueName != "transfer-queue" {
			// If we're using a custom queue name, transform it appropriately
			cleanupQueueName = strings.Replace(tw.queueName, "transfer", "cleanup", 1)
		}

		if err := QueueCleanupTaskInternal(ctx, tw.queueClient, cleanupQueueName, blobName); err != nil {
			log.Printf("Failed to queue cleanup task for blob %s: %v", blobName, err)
		}
	}

	return nil
}

// logTransfer logs the transfer operation
func (tw *TransferWorker) logTransfer(ctx context.Context, blobName string) error {
	// In a production system, this would record the transfer in Azure Tables
	// For now, just log it
	log.Printf("Transfer logged for blob: %s", blobName)
	return nil
}

// QueueTransferTaskInternal adds a blob to the transfer queue - for internal use
func QueueTransferTaskInternal(ctx context.Context, queueClient *azqueue.ServiceClient, queueName, blobName string) error {
	client := queueClient.NewQueueClient(queueName)

	// Add the message to the queue
	_, err := client.EnqueueMessage(ctx, blobName, nil)
	if err != nil {
		return fmt.Errorf("failed to queue transfer task: %w", err)
	}

	return nil
}
