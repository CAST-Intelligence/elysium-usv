# Go Implementation Plan for Elysium USV Data Pipeline

## Overview

This document outlines a simplified implementation plan using Go as the orchestration layer for the USV data pipeline. The implementation will focus on simplicity, maintainability, and direct use of Azure and AWS SDKs to create a robust data transfer system.

## Architectural Approach

- **Single Go Binary**: Monolithic design with clean internal separation of concerns
- **Direct SDK Integration**: Use Azure and AWS SDKs without unnecessary abstraction layers
- **Offload to Managed Services**: Leverage cloud services for storage, queues, and key management
- **Local Development**: Azurite and MinIO containers for emulating Azure Storage and AWS S3

## Implementation Phases

### Phase 1: Project Scaffolding and Local Environment Setup

1. **Project Structure Setup**
   - Set up Go module and package structure
   - Integrate with existing repository layout 
   - Create configuration loading mechanism

2. **Local Development Environment**
   - Docker Compose setup with Azurite (Azure Storage emulator)
   - MinIO container for S3-compatible storage testing
   - Local development scripts and documentation

3. **Core Infrastructure**
   - Azure authentication and connection setup
   - Logging and error handling framework
   - Health check and metrics endpoints

### Phase 2: Core Pipeline Components

1. **Data Validation Service**
   - Blob storage integration
   - Checksum calculation and verification
   - Metadata management
   - Validation status tracking

2. **S3 Transfer Mechanism**
   - AWS credentials management via Azure Key Vault
   - Secure S3 upload implementation
   - Transfer verification
   - Retry and error handling logic

3. **Data Retention & Cleanup**
   - Policy-based cleanup of transferred data
   - Audit record generation
   - Secure deletion verification

### Phase 3: Orchestration and Pipeline Integration

1. **Pipeline Scheduler**
   - Time-based job scheduling
   - Event-driven processing triggers
   - Concurrency and rate limiting

2. **Monitoring & Alerting**
   - Prometheus metrics export
   - Structured logging integration
   - Azure Monitor integration

3. **End-to-end Testing**
   - Integration test suite
   - Simulated failure scenarios
   - Performance testing

### Phase 4: Deployment and Operations

1. **Azure Deployment**
   - App Service deployment scripts
   - Infrastructure as Code updates
   - CI/CD pipeline integration

2. **Documentation**
   - Architecture documentation
   - Operations manual
   - Monitoring guidelines

3. **Security Finalization**
   - Security review
   - Penetration testing
   - Compliance validation

## Directory Structure

```
/elysium-usv/                    # Existing repository root
  /cmd/                          # Go command-line applications
    /usvpipeline/                # Main pipeline orchestrator
      main.go                    # Entry point
  
  /internal/                     # Private application code
    /validation/                 # Data validation logic
    /transfer/                   # S3 transfer handling
    /audit/                      # Audit logging
    /azure/                      # Azure interactions
    /aws/                        # AWS interactions
    /config/                     # Configuration
    /worker/                     # Background workers
    /server/                     # HTTP server components
  
  /tools/                        # Development and operations tools
    /local-dev.sh                # Local development script
    /docker-compose.yml          # Local development containers
  
  /deployment/                   # Deployment scripts
    /app-service/                # Azure App Service deployment
    /terraform/                  # Infrastructure as Code

  /test/                         # Test data and integration tests
    /mock-data/                  # Sample test data
    /integration/                # Integration test suites
```

## Technical Components

### Core Libraries

- **Azure SDKs**:
  - Azure Storage SDK for Go (blobs, queues, tables)
  - Azure Key Vault SDK for secrets management
  - Azure Identity SDK for managed identity support

- **AWS SDKs**:
  - AWS SDK for Go v2 (S3, STS)

- **Supporting Libraries**:
  - Zerolog for structured logging
  - Chi or Gorilla Mux for HTTP routing
  - Viper for configuration management
  - Testify for testing

### Key Implementation Patterns

1. **Worker Pattern**:
   - Background workers with graceful shutdown
   - Channel-based coordination
   - Resource pooling for efficiency

2. **Circuit Breaker Pattern**:
   - Prevent cascading failures
   - Auto-recovery mechanisms
   - Rate limiting and backoff

3. **Observability Pattern**:
   - Correlation IDs for request tracing
   - Structured logging
   - Metrics collection at key points

4. **Configuration Pattern**:
   - Environment variable overrides
   - Configuration file support
   - Secrets injection via Azure Key Vault

## Local Development Process

1. **Start Local Environment**:
   ```bash
   cd elysium-usv
   docker-compose up -d
   ```

2. **Configure Local Settings**:
   ```bash
   export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;..."
   export AWS_ENDPOINT_URL="http://localhost:9000"
   export AWS_ACCESS_KEY_ID="minioadmin"
   export AWS_SECRET_ACCESS_KEY="minioadmin"
   ```

3. **Run Application**:
   ```bash
   go run ./cmd/usvpipeline
   ```

4. **Test Data Generation**:
   ```bash
   # Upload test data to Azurite
   tools/upload-test-data.sh
   ```

## Deployment Process

1. **Build for Linux**:
   ```bash
   GOOS=linux GOARCH=amd64 go build -o usvpipeline ./cmd/usvpipeline
   ```

2. **Deploy to Azure App Service**:
   ```bash
   deployment/app-service/deploy.sh
   ```

3. **Configure Azure Settings**:
   - Set App Settings for environment variables
   - Configure Managed Identity
   - Set up monitoring and scaling rules

## Timeline

- **Phase 1**: 1-2 weeks
- **Phase 2**: 2-3 weeks
- **Phase 3**: 1-2 weeks
- **Phase 4**: 1 week

Total estimated time: 5-8 weeks

## Success Criteria

1. **Functional**:
   - Successful validation of USV data with checksum verification
   - Secure transfer to client S3 buckets with proper credentials
   - Compliant retention and cleanup with audit trails
   - Proper error handling and recovery

2. **Non-Functional**:
   - Performance meeting or exceeding client requirements
   - Security compliance with Australian defense requirements
   - Maintainable, well-documented code
   - Robust local development and testing environment