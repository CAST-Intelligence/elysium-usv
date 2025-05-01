# Elysium USV Data Pipeline

## Overview
This project implements a secure data pipeline for transferring survey data captured by Unmanned Surface Vehicles (USVs) from SeaSats to Revelare. The system ensures data sovereignty, security, and proper data handling according to Australian defense requirements.

## Architecture
The pipeline architecture connects SeaSats USVs via Starlink to an Azure-hosted ground station in Australia, then securely transfers validated data to Revelare's AWS S3 buckets.

### System Architecture Diagram

```mermaid
%%{init: {'flowchart': {'subGraphTitleMargin': {'top':15,'bottom': 30}}}}%%


flowchart TD
    USV(SeaSats USV) -->|Starlink| GS(Ground Station Server)
    GS -->|Validate & Process| ABS(Azure Blob Storage)
    ABS --> DPS(Data Pipeline Service)
    
    subgraph AZ["`Azure (Elysium) 
    ***Australia Region***`"]
        GS
        ABS
        DPS
        AAC(Authentication & Access Control)
        AS(Audit System)
        AL(Alerting Service)
    end
    
    subgraph "`AWS (Revelare)`"
        S3(AWS S3 Bucket)
        S3P1(Vessel 1 Prefix)
        S3P2(Vessel 2 Prefix)
        S3 --- S3P1
        S3 --- S3P2
    end
    
    DPS -->|Upload Data| S3
    DPS <-->|Validate Transfer| S3
    DPS -->|Cleanup Validated Data| ABS
    
    AAC -.->|Access Control| GS
    AAC -.->|Access Control| ABS
    AAC -.->|Access Control| DPS
    
    AS -.->|Audit Logs| GS
    AS -.->|Audit Logs| ABS
    AS -.->|Audit Logs| DPS
    
    AL -.->|Monitor| GS
    AL -.->|Monitor| ABS
    AL -.->|Monitor| DPS
    AL -.->|Monitor| S3
    
    classDef azure fill:#0072C6,color:white,stroke:none;
    classDef aws fill:#FF9900,color:white,stroke:none;
    classDef usv fill:#00A170,color:white,stroke:none;
    
    class GS,ABS,DPS,AAC,AS,AL azure;
    class S3,S3P1,S3P2 aws;
    class USV usv;
```

### Data Flow Sequence

```mermaid
sequenceDiagram
    participant USV as SeaSats USV
    participant GS as Ground Station
    participant ABS as Azure Blob Storage
    participant DPS as Data Pipeline Service
    participant S3 as AWS S3 Bucket
    participant AS as Audit System
    
    USV->>GS: Transmit survey data via Starlink
    USV->>GS: Transmit checksums for verification
    GS-->>USV: Confirm data integrity
    GS->>AS: Log data receipt with integrity status
    GS->>GS: Validate & preprocess data
    GS->>ABS: Store data with vessel ID & timestamp
    ABS->>AS: Log storage operation
    
    loop Scheduled Transfer
        DPS->>ABS: Retrieve non-uploaded data
        DPS->>S3: Upload to vessel-specific S3 prefix
        S3-->>DPS: Confirm upload (checksums)
        DPS->>AS: Log successful transfer
        DPS->>ABS: Mark data as validated
    end
    
    loop Scheduled Cleanup
        DPS->>ABS: Identify validated data past retention
        DPS->>ABS: Delete validated data
        ABS->>AS: Log deletion operation
    end
    
    Note over AS: Generate audit reports & destruction certificates
```

## Key Components

1. **Data Collection Layer**
   - SeaSats USV collecting survey data
   - Starlink satellite communication

2. **Azure Infrastructure (Australia Region)**
   - Ground Station Server for receiving USV data
   - Azure Blob Storage for temporary data storage
   - Data Pipeline Service for validation and transfer
   - Authentication and Access Control with geo-locking

3. **AWS Integration**
   - S3 Transfer Service with vessel-specific credentials
   - Validation and cleanup processes

4. **Monitoring and Compliance**
   - Comprehensive audit system
   - Alerting service for operational monitoring

## Requirements Satisfied

- ✅ Direct upload to Revelare's AWS S3 bucket at regular intervals
- ✅ Dedicated key/secret per vessel with limited permissions
- ✅ Data retention until validated in Revelare's S3
- ✅ Scheduled removal of validated data
- ✅ Audit capabilities for data destruction certification
- ✅ Australia data sovereignty with geo-locking and access controls

## Implementation Notes

This repository contains the code and configuration for implementing the complete data pipeline, including:

- Azure infrastructure as code (ARM templates)
- Data pipeline services and validation logic
- AWS S3 integration components
- Monitoring and auditing tools
- Documentation and operational guides

## Hybrid Implementation Architecture

This solution uses a hybrid approach combining Azure Functions and Logic Apps:

### Azure Functions Components
- **Data Validation Function**: Blob-triggered function that validates data integrity with checksum verification
- **AWS Authentication Function**: Generates secure, vessel-specific credentials for S3 access
- **Generate Audit Certificate Function**: Creates compliance records for data destruction certification

### Logic App Workflows
- **Master Orchestration Workflow**: Coordinates the end-to-end pipeline execution
- **S3 Transfer Workflow**: Manages secure transfer of validated data to AWS S3
- **Cleanup Workflow**: Handles data retention policies and certified data destruction

## Development & Deployment

### Prerequisites
- Azure CLI installed and authenticated
- Azure subscription with permissions to create resources
- Access to AWS account for S3 bucket (for production)

### Local Development Setup
1. Install Python 3.9+ and required packages:
   ```
   pip install -r src/functions/requirements.txt
   pip install -r tools/requirements.txt
   ```

2. Set up Azure Function Core Tools for local testing.

3. For local testing, set the connection string:
   ```
   export AZURE_STORAGE_CONNECTION_STRING="your_storage_connection_string"
   ```

### Testing with Mock Data
Use the mock data generator to simulate USV data:

```bash
python tools/mock-data-generator.py --count 10 --interval 5
```

Options:
- `--count`: Number of files to generate
- `--min-size`/`--max-size`: File size range in KB
- `--corrupt`: Percentage of files to corrupt (for testing validation)
- `--interval`: Seconds between uploads (simulates real data flow)
- `--vessel-id`: Vessel identifier

### Deployment
Deploy using the included deployment script:

```bash
cd deployment
chmod +x deploy.sh
./deploy.sh -g your-resource-group -e dev
```

Options:
- `-g`: Resource group name (required)
- `-e`: Environment (dev, test, prod)
- `-l`: Azure region location (default: australiaeast)

The script:
1. Creates/updates resources using ARM templates
2. Deploys all Azure Functions
3. Deploys Logic App workflows
4. Sets up necessary connections

## Monitoring & Maintenance

- Use Azure Application Insights for monitoring function performance
- View Logic App run history for workflow execution details
- Audit logs are stored in Azure Table Storage for compliance records