package worker

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/jlaffaye/ftp"
)

// FTPWorker watches an FTP server for files with MD5 hash companions
type FTPWorker struct {
	worker          *Worker
	config          *config.Config
	blobClient      *azblob.Client
	queueClient     *azqueue.ServiceClient
	containerName   string
	validationQueue string
	tempDir         string
}

// NewFTPWorker creates a new worker for FTP file watching
func NewFTPWorker(
	cfg *config.Config,
	blobClient *azblob.Client,
	queueClient *azqueue.ServiceClient,
) *FTPWorker {
	// Create a temporary directory for downloaded files if FTPWatchDir is not specified
	tempDir := cfg.FTPWatchDir
	if tempDir == "" {
		var err error
		tempDir, err = os.MkdirTemp("", "ftp-worker")
		if err != nil {
			log.Printf("Failed to create temp directory: %v", err)
			tempDir = os.TempDir()
		}
	}

	fw := &FTPWorker{
		config:          cfg,
		blobClient:      blobClient,
		queueClient:     queueClient,
		containerName:   cfg.BlobContainerName,
		validationQueue: cfg.ValidationQueueName,
		tempDir:         tempDir,
	}

	// Create the underlying worker
	worker := NewWorker(
		"ftp-watcher",
		fw.processFTPFiles,
		cfg.FTPPollInterval,
		cfg.ProcessingBatchSize,
		cfg.OperationRetryCount,
	)

	fw.worker = worker
	return fw
}

// Start starts the FTP worker
func (fw *FTPWorker) Start() {
	fw.worker.Start()
}

// Stop stops the FTP worker
func (fw *FTPWorker) Stop() {
	fw.worker.Stop()
}

// Status returns the worker status
func (fw *FTPWorker) Status() string {
	return fw.worker.Status()
}

// LastRun returns the time of the last run
func (fw *FTPWorker) LastRun() time.Time {
	return fw.worker.LastRun()
}

// connectFTP establishes a connection to the FTP server with retries
func (fw *FTPWorker) connectFTP(ctx context.Context) (*ftp.ServerConn, error) {
	var conn *ftp.ServerConn
	var err error

	addr := fmt.Sprintf("%s:%d", fw.config.FTPHost, fw.config.FTPPort)
	log.Printf("Connecting to FTP server at %s", addr)

	// Try to connect with retries
	for i := 0; i <= fw.config.FTPRetryCount; i++ {
		if i > 0 {
			log.Printf("Retrying FTP connection (attempt %d/%d)...", i, fw.config.FTPRetryCount)
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(fw.config.FTPRetryDelay):
				// Wait before retry
			}
		}

		// Create a connection with reasonable timeouts
		conn, err = ftp.Dial(addr, ftp.DialWithTimeout(30*time.Second))
		if err == nil {
			break
		}
		log.Printf("Failed to connect to FTP server: %v", err)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to connect to FTP server after %d attempts: %w",
			fw.config.FTPRetryCount, err)
	}

	// Login
	err = conn.Login(fw.config.FTPUser, fw.config.FTPPassword)
	if err != nil {
		conn.Quit()
		return nil, fmt.Errorf("failed to login to FTP server: %w", err)
	}

	log.Printf("Successfully connected to FTP server")
	return conn, nil
}

// processFTPFiles is the main worker function that processes files from the FTP server
func (fw *FTPWorker) processFTPFiles(ctx context.Context, batchSize int) error {
	// Check if our temp directory exists
	if _, err := os.Stat(fw.tempDir); os.IsNotExist(err) {
		if err := os.MkdirAll(fw.tempDir, 0755); err != nil {
			return fmt.Errorf("failed to create temp directory: %w", err)
		}
	}

	// Create processed directory
	processedDir := filepath.Join(fw.tempDir, "processed")
	if _, err := os.Stat(processedDir); os.IsNotExist(err) {
		if err := os.MkdirAll(processedDir, 0755); err != nil {
			return fmt.Errorf("failed to create processed directory: %w", err)
		}
	}

	// Connect to FTP server
	conn, err := fw.connectFTP(ctx)
	if err != nil {
		return err
	}
	defer conn.Quit()

	// List all files
	entries, err := conn.List(".")
	if err != nil {
		return fmt.Errorf("failed to list files: %w", err)
	}

	log.Printf("Found %d files on FTP server", len(entries))

	// Process MD5 files and their corresponding data files
	processedCount := 0
	for _, entry := range entries {
		if processedCount >= batchSize {
			break
		}

		if ctx.Err() != nil {
			return ctx.Err()
		}

		// Skip directories and non-MD5 files
		if entry.Type == ftp.EntryTypeFolder || !strings.HasSuffix(entry.Name, ".md5") {
			continue
		}

		// Find corresponding data file
		dataFileName := strings.TrimSuffix(entry.Name, ".md5")
		var dataFileFound bool
		
		for _, dataEntry := range entries {
			if dataEntry.Name == dataFileName {
				dataFileFound = true
				break
			}
		}

		if !dataFileFound {
			log.Printf("Data file not found for MD5 file: %s", entry.Name)
			continue
		}

		// Download MD5 file
		md5FilePath := filepath.Join(fw.tempDir, entry.Name)
		md5File, err := os.Create(md5FilePath)
		if err != nil {
			log.Printf("Failed to create MD5 file: %v", err)
			continue
		}

		resp, err := conn.Retr(entry.Name)
		if err != nil {
			log.Printf("Failed to download MD5 file: %v", err)
			md5File.Close()
			os.Remove(md5FilePath)
			continue
		}

		_, err = io.Copy(md5File, resp)
		resp.Close()
		md5File.Close()
		if err != nil {
			log.Printf("Failed to save MD5 file: %v", err)
			os.Remove(md5FilePath)
			continue
		}

		// Read MD5 hash
		hash, err := readMD5FromFile(md5FilePath)
		if err != nil {
			log.Printf("Failed to read MD5 from file: %v", err)
			continue
		}

		// Download data file
		dataFilePath := filepath.Join(fw.tempDir, dataFileName)
		dataFileOut, err := os.Create(dataFilePath)
		if err != nil {
			log.Printf("Failed to create data file: %v", err)
			continue
		}

		resp, err = conn.Retr(dataFileName)
		if err != nil {
			log.Printf("Failed to download data file: %v", err)
			dataFileOut.Close()
			os.Remove(dataFilePath)
			continue
		}

		_, err = io.Copy(dataFileOut, resp)
		resp.Close()
		dataFileOut.Close()
		if err != nil {
			log.Printf("Failed to save data file: %v", err)
			os.Remove(dataFilePath)
			continue
		}

		// Verify MD5 hash
		calculatedHash, err := calculateMD5(dataFilePath)
		if err != nil {
			log.Printf("Failed to calculate MD5 for data file: %v", err)
			continue
		}

		if calculatedHash != hash {
			log.Printf("MD5 hash mismatch for %s - expected: %s, got: %s",
				dataFileName, hash, calculatedHash)
			continue
		}

		// Extract vessel ID
		vesselID := "unknown"
		if ekiParts := strings.Split(dataFileName, "-EKI"); len(ekiParts) > 1 {
			ekiID := strings.Split(ekiParts[1], ".")[0]
			vesselID = fmt.Sprintf("EKI%s", ekiID)
		} else if vesselParts := strings.Split(dataFileName, "VESSEL"); len(vesselParts) > 1 {
			vesselIDPart := strings.Split(vesselParts[1], "_")[0]
			vesselID = fmt.Sprintf("VESSEL%s", vesselIDPart)
		}

		// Upload to Azure
		blobName := fmt.Sprintf("%s/%s", vesselID, dataFileName)
		log.Printf("Uploading %s with MD5 %s", dataFileName, hash)

		containerClient := fw.blobClient.ServiceClient().NewContainerClient(fw.containerName)
		blockBlobClient := containerClient.NewBlockBlobClient(blobName)

		// Prepare metadata
		metadata := map[string]*string{
			"checksum":          stringPtr(hash),
			"vesselid":          stringPtr(vesselID),
			"timestamp":         stringPtr(time.Now().UTC().Format(time.RFC3339)),
			"checksumAlgorithm": stringPtr("MD5"),
		}

		// Read file
		file, err := os.ReadFile(dataFilePath)
		if err != nil {
			log.Printf("Failed to read file %s: %v", dataFilePath, err)
			continue
		}

		// Upload file
		options := &azblob.UploadBufferOptions{
			Metadata: metadata,
		}
		_, err = blockBlobClient.UploadBuffer(ctx, file, options)
		if err != nil {
			log.Printf("Failed to upload blob %s: %v", blobName, err)
			continue
		}

		// Queue validation
		queueClient := fw.queueClient.NewQueueClient(fw.validationQueue)
		_, err = queueClient.EnqueueMessage(ctx, blobName, nil)
		if err != nil {
			log.Printf("Failed to queue validation for %s: %v", blobName, err)
			continue
		}

		log.Printf("Successfully processed %s", dataFileName)
		processedCount++

		// Move files to processed directory
		os.Rename(dataFilePath, filepath.Join(processedDir, dataFileName))
		os.Rename(md5FilePath, filepath.Join(processedDir, entry.Name))

		// Delete files from FTP server if successful
		err = conn.Delete(dataFileName)
		if err != nil {
			log.Printf("Failed to delete data file from FTP server: %v", err)
		}

		err = conn.Delete(entry.Name)
		if err != nil {
			log.Printf("Failed to delete MD5 file from FTP server: %v", err)
		}
	}

	if processedCount > 0 {
		log.Printf("Processed %d files", processedCount)
	}

	return nil
}

// readMD5FromFile reads an MD5 hash from a file
func readMD5FromFile(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", err
	}

	hash := strings.TrimSpace(string(data))
	hashParts := strings.Fields(hash)
	if len(hashParts) > 0 {
		hash = hashParts[0]
	}

	return hash, nil
}

// calculateMD5 computes the MD5 hash of a file
func calculateMD5(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hasher := md5.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hasher.Sum(nil)), nil
}

// Helper function to get string pointer
func stringPtr(s string) *string {
	return &s
}

// QueueValidationTask queues a validation task for a blob
func QueueValidationTask(ctx context.Context, queueClient *azqueue.ServiceClient, queueName, blobName string) error {
	queue := queueClient.NewQueueClient(queueName)
	_, err := queue.EnqueueMessage(ctx, blobName, nil)
	return err
}