package aws

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"strings"

	"github.com/CAST-Intelligence/elysium-usv/internal/config"
	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// S3Client represents an AWS S3 client
type S3Client struct {
	client     *s3.Client
	bucketName string
}

// NewS3Client creates a new S3 client with the given configuration
func NewS3Client(cfg *config.Config) (*S3Client, error) {
	// Create AWS configuration
	var awsConfig aws.Config
	var err error

	// Check if we're using a custom S3 endpoint (e.g., MinIO)
	if cfg.AWSEndpointURL != "" {
		// Custom options for local development with MinIO
		customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{
				URL:               cfg.AWSEndpointURL,
				HostnameImmutable: true,
				SigningRegion:     cfg.AWSRegion,
			}, nil
		})

		awsConfig, err = awsconfig.LoadDefaultConfig(context.Background(),
			awsconfig.WithRegion(cfg.AWSRegion),
			awsconfig.WithEndpointResolverWithOptions(customResolver),
			awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
				cfg.AWSAccessKey,
				cfg.AWSSecretKey,
				"",
			)),
		)
	} else {
		// Standard AWS configuration
		awsConfig, err = awsconfig.LoadDefaultConfig(context.Background(),
			awsconfig.WithRegion(cfg.AWSRegion),
		)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Create S3 client
	client := s3.NewFromConfig(awsConfig)

	return &S3Client{
		client:     client,
		bucketName: cfg.AWSBucketName,
	}, nil
}

// BucketName returns the name of the bucket used by this client
func (c *S3Client) BucketName() string {
	return c.bucketName
}

// UploadObject uploads an object to S3 and returns the ETag (MD5 hash)
func (c *S3Client) UploadObject(ctx context.Context, key string, reader io.Reader) (string, error) {
	// Convert reader to byte array
	buf := new(bytes.Buffer)
	_, err := buf.ReadFrom(reader)
	if err != nil {
		return "", fmt.Errorf("failed to read data: %w", err)
	}

	// Get the data size
	data := buf.Bytes()
	dataSize := len(data)
	log.Printf("Preparing to upload %d bytes to S3: %s/%s", dataSize, c.bucketName, key)

	// Calculate MD5 hash locally before upload
	md5Hash := md5.Sum(data)
	calculatedMD5 := hex.EncodeToString(md5Hash[:])
	log.Printf("Calculated MD5 hash for %s: %s", key, calculatedMD5)

	// Upload the object
	response, err := c.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(c.bucketName),
		Key:    aws.String(key),
		Body:   bytes.NewReader(data),
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload object: %w", err)
	}

	// Extract ETag (MD5 hash) from response
	var eTag string
	if response.ETag != nil {
		// ETag is usually returned with quotes, so strip them
		eTag = strings.Trim(*response.ETag, "\"")
		log.Printf("Received ETag from S3 for %s: %s", key, eTag)

		// Compare with calculated MD5
		if strings.EqualFold(eTag, calculatedMD5) {
			log.Printf("MD5 verification succeeded for %s: calculated=%s, S3=%s", key, calculatedMD5, eTag)
		} else {
			log.Printf("WARNING: MD5 mismatch for %s: calculated=%s, S3=%s", key, calculatedMD5, eTag)
		}
	} else {
		log.Printf("WARNING: No ETag received from S3 for %s", key)
	}

	// Verify the object was uploaded correctly
	log.Printf("Upload complete, verifying object in S3: %s/%s", c.bucketName, key)
	exists, err := c.VerifyObject(ctx, key)
	if err != nil {
		return eTag, fmt.Errorf("upload succeeded but verification failed: %w", err)
	}
	if !exists {
		return eTag, fmt.Errorf("upload appeared to succeed but object not found in S3")
	}

	log.Printf("Successfully uploaded and verified object in S3: %s/%s (%d bytes)", c.bucketName, key, dataSize)
	return eTag, nil
}

// VerifyObject verifies that an object exists in S3
func (c *S3Client) VerifyObject(ctx context.Context, key string) (bool, error) {
	log.Printf("Verifying object exists in S3: %s/%s", c.bucketName, key)
	
	// Check if the object exists
	resp, err := c.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(c.bucketName),
		Key:    aws.String(key),
	})
	
	// Handle specific error types
	if err != nil {
		// For now, just check if the error string contains "not found" or "not exist"
		// This is a simplification since the exact error type can vary between S3 implementations
		errStr := err.Error()
		if strings.Contains(strings.ToLower(errStr), "not found") || 
		   strings.Contains(strings.ToLower(errStr), "not exist") ||
		   strings.Contains(strings.ToLower(errStr), "no such key") {
			log.Printf("Object not found in S3: %s/%s", c.bucketName, key)
			return false, nil
		}
		
		// Unknown error
		return false, fmt.Errorf("failed to verify object: %w", err)
	}
	
	// Object exists, log some details
	contentLength := int64(0)
	if resp.ContentLength != nil {
		contentLength = *resp.ContentLength
	}
	
	log.Printf("Object verified in S3: %s/%s (size: %d bytes)", c.bucketName, key, contentLength)
	return true, nil
}

// BuildObjectKey builds a fully qualified S3 key for a blob
// The format is: {vesselId}/data/{blobName}
func BuildObjectKey(vesselID, blobName string) string {
	return fmt.Sprintf("%s/data/%s", vesselID, blobName)
}