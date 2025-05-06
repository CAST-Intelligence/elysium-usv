package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/CAST-Intelligence/elysium-usv/internal/aws"
	"github.com/CAST-Intelligence/elysium-usv/internal/azure"
	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/CAST-Intelligence/elysium-usv/internal/server"
	"github.com/CAST-Intelligence/elysium-usv/internal/worker"
)

func main() {
	// Set up logging
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.Lshortfile)
	log.Println("=== USV Data Pipeline Starting ===")
	
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}
	
	// Log key configuration values
	log.Printf("Configuration loaded: container=%s, validation_queue=%s, transfer_queue=%s, cleanup_queue=%s", 
		cfg.BlobContainerName, cfg.ValidationQueueName, cfg.TransferQueueName, cfg.CleanupQueueName)
	log.Printf("AWS endpoint: %s, bucket: %s", cfg.AWSEndpointURL, cfg.AWSBucketName)

	// Setup context for proper shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize clients
	log.Println("Initializing Azure client...")
	azureClient, err := azure.NewClient(cfg)
	if err != nil {
		log.Fatalf("Failed to create Azure client: %v", err)
	}
	log.Println("Azure client initialized successfully")

	log.Println("Initializing S3 client...")
	s3Client, err := aws.NewS3Client(cfg)
	if err != nil {
		log.Fatalf("Failed to create S3 client: %v", err)
	}
	log.Println("S3 client initialized successfully")

	// Initialize workers
	log.Println("Initializing workers...")
	validationWorker := worker.NewValidationWorker(cfg, azureClient.BlobClient, azureClient.QueueClient)
	transferWorker := worker.NewTransferWorker(cfg, azureClient.BlobClient, azureClient.QueueClient, s3Client)
	cleanupWorker := worker.NewCleanupWorker(cfg, azureClient.BlobClient, azureClient.QueueClient)
	
	// Initialize FTP worker if enabled
	var ftpWorker *worker.FTPWorker
	if cfg.FTPWatchEnabled {
		log.Printf("FTP watching enabled, directory: %s", cfg.FTPWatchDir)
		ftpWorker = worker.NewFTPWorker(cfg, azureClient.BlobClient, azureClient.QueueClient)
	}
	
	log.Println("Workers initialized successfully")

	// Start workers
	log.Println("Starting validation worker...")
	validationWorker.Start()
	log.Println("Starting transfer worker...")
	transferWorker.Start()
	log.Println("Starting cleanup worker...")
	cleanupWorker.Start()
	
	// Start FTP worker if enabled
	if ftpWorker != nil {
		log.Println("Starting FTP worker...")
		ftpWorker.Start()
	}
	
	log.Println("All workers started successfully")

	// Create and enhance server with worker status
	log.Println("Initializing HTTP server...")
	srv := server.New(cfg)
	if ftpWorker != nil {
		server.RegisterWorkerStatusEndpoints(srv, validationWorker, transferWorker, cleanupWorker, ftpWorker)
	} else {
		server.RegisterWorkerStatusEndpoints(srv, validationWorker, transferWorker, cleanupWorker)
	}
	log.Printf("HTTP server initialized on port %d", cfg.Port)
	
	// Start the server
	go startServer(srv, cfg)

	// Prepare shutdown tasks
	shutdownTasks := []shutdownTask{
		{
			name: "validation worker",
			stop: validationWorker.Stop,
		},
		{
			name: "transfer worker",
			stop: transferWorker.Stop,
		},
		{
			name: "cleanup worker",
			stop: cleanupWorker.Stop,
		},
	}
	
	// Add FTP worker to shutdown tasks if enabled
	if ftpWorker != nil {
		shutdownTasks = append(shutdownTasks, shutdownTask{
			name: "ftp worker",
			stop: ftpWorker.Stop,
		})
	}
	
	// Handle graceful shutdown
	handleGracefulShutdown(ctx, srv, cfg, shutdownTasks)
}

// shutdownTask represents a task to be executed during shutdown
type shutdownTask struct {
	name string
	stop func()
}

// startServer starts the HTTP server
func startServer(srv *http.Server, cfg *config.Config) {
	log.Printf("Starting server on port %d", cfg.Port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Failed to start server: %v", err)
	}
	
	// Add a simple sleep to allow time to start properly
	time.Sleep(100 * time.Millisecond)
}

// handleGracefulShutdown handles graceful shutdown of the server and workers
func handleGracefulShutdown(ctx context.Context, srv *http.Server, cfg *config.Config, tasks []shutdownTask) {
	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigChan
	log.Printf("Received signal %v, shutting down", sig)

	// Create shutdown context with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(ctx, cfg.ShutdownTimeout)
	defer shutdownCancel()

	// Stop all workers
	for _, task := range tasks {
		log.Printf("Stopping %s", task.name)
		task.stop()
	}

	// Shutdown the server
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	// Wait for shutdown to complete
	select {
	case <-shutdownCtx.Done():
		if shutdownCtx.Err() == context.DeadlineExceeded {
			log.Printf("Shutdown timed out, forcing exit")
		}
	default:
		log.Printf("All services shut down gracefully")
	}
}