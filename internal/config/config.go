package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds the application configuration loaded from environment variables
type Config struct {
	// Azure settings
	AzureStorageConnectionString string
	AzureKeyVaultName           string
	AzureKeyVaultEndpoint       string

	// AWS settings
	AWSEndpointURL  string
	AWSAccessKey    string
	AWSSecretKey    string
	AWSRegion       string
	AWSBucketName   string

	// Server settings
	Port            int
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	ShutdownTimeout time.Duration

	// Pipeline settings
	WorkerCount            int
	ValidationQueueName    string
	TransferQueueName      string
	CleanupQueueName       string
	BlobContainerName      string
	RetentionDays          int
	ProcessingBatchSize    int
	OperationRetryCount    int
	OperationRetryInterval time.Duration

	// Logging settings
	LogLevel string
	LogJSON  bool
}

// Default configuration values
const (
	defaultPort                = 8080
	defaultReadTimeout         = 30 * time.Second
	defaultWriteTimeout        = 30 * time.Second
	defaultShutdownTimeout     = 10 * time.Second
	defaultWorkerCount         = 3
	defaultBlobContainerName   = "usvdata"
	defaultValidationQueueName = "validation-queue"
	defaultTransferQueueName   = "transfer-queue"
	defaultCleanupQueueName    = "cleanup-queue"
	defaultRetentionDays       = 7
	defaultBatchSize           = 10
	defaultRetryCount          = 3
	defaultRetryInterval       = 5 * time.Second
	defaultLogLevel            = "info"
)

// Load loads configuration from environment variables
func Load() (*Config, error) {
	config := Config{
		// Azure settings
		AzureStorageConnectionString: os.Getenv("AZURE_STORAGE_CONNECTION_STRING"),
		AzureKeyVaultName:           os.Getenv("AZURE_KEY_VAULT_NAME"),
		AzureKeyVaultEndpoint:       os.Getenv("AZURE_KEY_VAULT_ENDPOINT"),

		// AWS settings
		AWSEndpointURL: os.Getenv("AWS_ENDPOINT_URL"),
		AWSAccessKey:   os.Getenv("AWS_ACCESS_KEY_ID"),
		AWSSecretKey:   os.Getenv("AWS_SECRET_ACCESS_KEY"),
		AWSRegion:      os.Getenv("AWS_REGION"),
		AWSBucketName:  getEnvOrDefault("AWS_BUCKET_NAME", "revelare-vessel-data"),

		// Server settings
		Port:            getEnvAsIntOrDefault("PORT", defaultPort),
		ReadTimeout:     getEnvAsDurationOrDefault("READ_TIMEOUT", defaultReadTimeout),
		WriteTimeout:    getEnvAsDurationOrDefault("WRITE_TIMEOUT", defaultWriteTimeout),
		ShutdownTimeout: getEnvAsDurationOrDefault("SHUTDOWN_TIMEOUT", defaultShutdownTimeout),

		// Pipeline settings
		WorkerCount:            getEnvAsIntOrDefault("WORKER_COUNT", defaultWorkerCount),
		ValidationQueueName:    getEnvOrDefault("VALIDATION_QUEUE_NAME", defaultValidationQueueName),
		TransferQueueName:      getEnvOrDefault("TRANSFER_QUEUE_NAME", defaultTransferQueueName),
		CleanupQueueName:       getEnvOrDefault("CLEANUP_QUEUE_NAME", defaultCleanupQueueName),
		BlobContainerName:      getEnvOrDefault("BLOB_CONTAINER_NAME", defaultBlobContainerName),
		RetentionDays:          getEnvAsIntOrDefault("RETENTION_DAYS", defaultRetentionDays),
		ProcessingBatchSize:    getEnvAsIntOrDefault("PROCESSING_BATCH_SIZE", defaultBatchSize),
		OperationRetryCount:    getEnvAsIntOrDefault("OPERATION_RETRY_COUNT", defaultRetryCount),
		OperationRetryInterval: getEnvAsDurationOrDefault("OPERATION_RETRY_INTERVAL", defaultRetryInterval),

		// Logging settings
		LogLevel: getEnvOrDefault("LOG_LEVEL", defaultLogLevel),
		LogJSON:  getEnvAsBoolOrDefault("LOG_JSON", false),
	}

	// Validate required settings
	if err := config.validateRequired(); err != nil {
		return nil, err
	}

	return &config, nil
}

// validateRequired ensures that all required configuration values are set
func (c *Config) validateRequired() error {
	if c.AzureStorageConnectionString == "" {
		return fmt.Errorf("AZURE_STORAGE_CONNECTION_STRING is required")
	}

	// In production, we need AWS credentials
	if isProduction() && (c.AWSAccessKey == "" || c.AWSSecretKey == "" || c.AWSRegion == "") {
		return fmt.Errorf("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION are required in production")
	}

	return nil
}

// Helper functions
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsIntOrDefault(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvAsBoolOrDefault(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}

func getEnvAsDurationOrDefault(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}

func isProduction() bool {
	env := strings.ToLower(os.Getenv("ENVIRONMENT"))
	return env == "production" || env == "prod"
}