# USV Pipeline-Specific RBAC and Policy Recommendations

Based on the Elysium USV Data Pipeline architecture, this document outlines tailored RBAC and policy recommendations to implement proper data sovereignty and security controls while enabling NZ-based MSP management.

## Architecture Analysis

The pipeline has distinct components with different security requirements:

1. **Data Collection Layer** (USV → Ground Station via Starlink)
2. **Data Storage Layer** (Ground Station → Azure Blob Storage)
3. **Data Transfer Layer** (Azure Blob Storage → AWS S3 via Data Pipeline Service)
4. **Cleanup Layer** (Validated data deletion and audit)
5. **Monitoring Layer** (Authentication, Access Control, Audit, Alerting)

## Component-Specific RBAC Model

Instead of traditional blanket RBAC roles, we recommend a component-specific approach:

### 1. Infrastructure Management Role (NZ MSP)

```json
{
  "Name": "USV-Pipeline-Infrastructure-Admin",
  "Description": "Manages infrastructure components without data access",
  "Actions": [
    // Ground Station Server management
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    
    // App Service management for Data Pipeline Service
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/write",
    "Microsoft.Web/sites/restart/action",
    "Microsoft.Web/sites/start/action",
    "Microsoft.Web/sites/stop/action",
    "Microsoft.Web/sites/config/read",
    "Microsoft.Web/sites/config/write",
    "Microsoft.Web/sites/deployments/read",
    
    // Storage infrastructure management (not data access)
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/write",
    "Microsoft.Storage/storageAccounts/listkeys/action",
    
    // Monitoring infrastructure
    "Microsoft.Insights/components/read",
    "Microsoft.Insights/components/write",
    "Microsoft.Insights/metricAlerts/read",
    "Microsoft.Insights/metricAlerts/write",
    
    // Network management
    "Microsoft.Network/virtualNetworks/*",
    "Microsoft.Network/networkSecurityGroups/*",
    "Microsoft.Network/privateEndpoints/*"
  ],
  "NotActions": [
    // Block ALL data plane operations
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete/action",
    
    // Block all key vault data operations
    "Microsoft.KeyVault/vaults/secrets/read",
    
    // Block all log analytics data operations
    "Microsoft.OperationalInsights/workspaces/query/read",
    
    // Block AWS credential access
    "Microsoft.Web/sites/config/list/action"
  ],
  "AssignableScopes": ["/subscriptions/${SUBSCRIPTION_ID}"]
}
```

### 2. Monitoring Role (NZ MSP)

```json
{
  "Name": "USV-Pipeline-Monitoring-Admin",
  "Description": "Monitors pipeline health without data access",
  "Actions": [
    // Health monitoring access
    "Microsoft.Insights/components/read",
    "Microsoft.Insights/metricAlerts/read",
    "Microsoft.Insights/activityLogAlerts/read",
    "Microsoft.Insights/diagnosticSettings/read",
    
    // App metrics access
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/metrics/read",
    
    // Log analytics - metadata only
    "Microsoft.OperationalInsights/workspaces/read",
    "Microsoft.OperationalInsights/workspaces/schema/read",
    
    // Storage metrics (not data)
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/blobServices/read"
  ],
  "NotActions": [
    // Block data access completely
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.OperationalInsights/workspaces/query/read"
  ],
  "AssignableScopes": ["/subscriptions/${SUBSCRIPTION_ID}"]
}
```

### 3. Data Processing Role (AU Only)

```json
{
  "Name": "USV-Data-Processing-Admin",
  "Description": "Processes and manages USV data (AU personnel only)",
  "Actions": [
    // All storage data operations
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
    
    // S3 transfer operations
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/write",
    "Microsoft.Web/sites/config/read",
    "Microsoft.Web/sites/config/write",
    
    // Get AWS credentials
    "Microsoft.KeyVault/vaults/secrets/read",
    
    // Read audit logs
    "Microsoft.OperationalInsights/workspaces/query/read"
  ],
  "AssignableScopes": ["/subscriptions/${SUBSCRIPTION_ID}"]
}
```

## Resource Group Organization for Lighthouse

Organize resource groups for precise Lighthouse delegation:

```
elysium-usv-infra-rg         # Infrastructure RG - NZ MSP can access
├── Ground Station VMs 
├── App Service Plans
├── Networking components
└── Monitoring infrastructure

elysium-usv-app-rg           # Application RG - NZ MSP can access 
├── Data Pipeline Service apps
└── Non-data related services

elysium-usv-data-rg          # Data RG - AU only access
├── Storage Accounts (with survey data)
└── Data retention policies

elysium-usv-security-rg      # Security RG - AU only access
├── Key Vault (credentials)
└── AWS connection information
```

## Pipeline-Specific Azure Policies

### 1. Data Geo-Restriction Policy

```bicep
resource usvDataLocationPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'usv-data-australia-only'
  properties: {
    displayName: 'USV Data Must Stay in Australia'
    description: 'Ensures all USV data storage remains in Australian regions'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type',
            in: [
              'Microsoft.Storage/storageAccounts',
              'Microsoft.Web/sites',
              'Microsoft.OperationalInsights/workspaces'
            ]
          },
          {
            field: 'tags.DataType',
            equals: 'USVSurveyData'
          },
          {
            field: 'location',
            notIn: [
              'australiaeast',
              'australiasoutheast'
            ]
          }
        ]
      },
      then: {
        effect: 'deny'
      }
    }
  }
}
```

### 2. USV Pipeline Component Tagging Policy

```bicep
resource usvComponentTaggingPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'usv-component-tagging'
  properties: {
    displayName: 'USV Pipeline Component Tagging'
    description: 'Enforces tagging for USV pipeline components'
    mode: 'Indexed'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags.USVComponent',
            exists: 'false'
          },
          {
            anyOf: [
              {
                field: 'name',
                like: '*usv*'
              },
              {
                field: 'name',
                like: '*vessel*'
              },
              {
                field: 'resourceGroupName',
                like: '*elysium*'
              }
            ]
          }
        ]
      },
      then: {
        effect: 'audit'
      }
    }
  }
}
```

### 3. Storage Network Restriction for USV Data

```bicep
resource usvStorageNetworkPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'usv-storage-network-restriction'
  properties: {
    displayName: 'USV Storage Security Controls'
    description: 'Enforces private network access and advanced security for USV data storage'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type',
            equals: 'Microsoft.Storage/storageAccounts'
          },
          {
            field: 'tags.USVComponent',
            equals: 'DataStorage'
          },
          {
            anyOf: [
              {
                field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess',
                equals: 'true'
              },
              {
                field: 'Microsoft.Storage/storageAccounts/networkAcls.defaultAction',
                equals: 'Allow'
              },
              {
                field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion',
                notEquals: 'TLS1_2'
              }
            ]
          }
        ]
      },
      then: {
        effect: 'deny'
      }
    }
  }
}
```

## Lighthouse Implementation for USV Pipeline

For the Elysium USV pipeline, we recommend two Lighthouse delegations:

### 1. Infrastructure Management Delegation

```bash
# Deploy with our script
./lighthouse-test/deploy-delegation.sh \
  --scope rg \
  --tenant "${NZ_MSP_TENANT_ID}" \
  --principal "${NZ_MSP_PRINCIPAL_ID}" \
  --resource-group "elysium-usv-infra-rg" \
  --name "USV Infrastructure Team"
```

### 2. Application Management Delegation

```bash
# Deploy with our script
./lighthouse-test/deploy-delegation.sh \
  --scope rg \
  --tenant "${NZ_MSP_TENANT_ID}" \
  --principal "${NZ_MSP_PRINCIPAL_ID}" \
  --resource-group "elysium-usv-app-rg" \
  --name "USV Application Team"
```

## Pipeline-Specific PIM Configuration

For NZ staff that require temporary elevated access:

1. Define an emergency access role in Azure AD PIM
2. Require justification with pull request link or ticket number
3. Implement time-based restrictions (8 hours max)
4. Require Australian admin approval with MFA
5. Set up enhanced monitoring during access period

## Geographic Conditional Access for USV Pipeline

Set up a conditional access policy specifically for USV resources:

```
Name: USV-Data-Geo-Protection
Target Users: All users with access to USV data components
Conditions:
  - Exclude Australian IPs
  - Target USV data applications 
  - Registration state: All devices
Controls:
  - Block access
  - Require MFA + Approval for emergency access
Session Controls:
  - Enhanced monitoring for all sessions
  - Disable persistent browser sessions
```

## Recommendations for AWS S3 Bucket Policies

While outside the Azure Lighthouse scope, we recommend the following AWS-side policies:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonAustralianIPs",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::revelare-vessel-data/*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": [
            "Australian IP CIDR ranges"
          ]
        }
      }
    },
    {
      "Sid": "AllowVesselSpecificUploads",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:role/usv-pipeline-transfer-role"
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::revelare-vessel-data/vessel-*/*"
    }
  ]
}
```

## Audit and Monitoring Implementation

Based on your current architecture, we recommend additional monitoring specifically for Lighthouse delegated access:

```bash
# Create alerts for delegated users accessing USV components
az monitor activity-log alert create \
  --name "nz-msp-usv-access-alert" \
  --resource-group "elysium-usv-security-rg" \
  --condition "category=Administrative" \
  --condition "caller=*@nzmsp.com" \
  --action-group "security-alerts"

# Create Log Analytics query for MSP activity
az monitor log-analytics query \
  --workspace "${LOG_ANALYTICS_WORKSPACE}" \
  --analytics-query "AzureActivity 
    | where Category == 'Administrative' 
    | where Caller contains 'nzmsp.com' 
    | where ResourceGroup startswith 'elysium-usv' 
    | project TimeGenerated, Caller, CategoryValue, OperationName, ResourceProvider, ResourceGroup, Status"
```

## Implementation Sequence

1. Set up resource groups with proper organization
2. Create custom RBAC roles specific to USV pipeline components
3. Apply tagging to all USV resources for consistent policy application
4. Deploy Azure Policies for resource protection
5. Establish conditional access policies for geographic restrictions
6. Deploy Lighthouse delegations for infrastructure and application management
7. Configure monitoring and alerting for delegated access
8. Implement automated compliance reporting

These recommendations are tailored to the specific data flow and components of your USV pipeline while enabling secure cross-region management capabilities.