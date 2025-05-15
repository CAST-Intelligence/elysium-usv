# Australian Data Geo-Lock Implementation

This document outlines the technical implementation to ensure data remains geo-locked to Australia within the Azure tenancy, particularly for pipelines that push data to end-client S3 buckets.

## 1. Storage Account Geo-restriction

Create storage accounts with geo-replication restricted to Australian regions only:

```bash
# Create storage account with geo-redundancy restricted to Australia
az storage account create \
  --name "australialockeddata" \
  --resource-group "data-rg" \
  --location "australiaeast" \
  --sku "RAGRS" \
  --kind "StorageV2" \
  --allow-blob-public-access false \
  --min-tls-version "TLS1_2" \
  --enable-hierarchical-namespace false
```

## 2. Azure Policy for Network Restrictions

Apply a policy that enforces private endpoint connections only:

```bicep
resource storageNetworkPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'enforce-storage-private-link'
  properties: {
    policyType: 'Custom'
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
            field: 'Microsoft.Storage/storageAccounts/networkAcls.defaultAction',
            notEquals: 'Deny'
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

## 3. Private Endpoints with Regional Restriction

```bash
# Create VNET with Australia-only endpoints
az network vnet create \
  --name "australia-vnet" \
  --resource-group "network-rg" \
  --location "australiaeast" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "private-endpoints" \
  --subnet-prefix "10.0.1.0/24"

# Create private endpoint
az network private-endpoint create \
  --name "storage-endpoint" \
  --resource-group "network-rg" \
  --vnet-name "australia-vnet" \
  --subnet "private-endpoints" \
  --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/data-rg/providers/Microsoft.Storage/storageAccounts/australialockeddata" \
  --group-id "blob" \
  --connection-name "blobconnection"
```

## 4. Key Vault with Geo-Restriction for Pipeline Credentials

```bash
# Create geo-restricted Key Vault
az keyvault create \
  --name "australia-pipeline-kv" \
  --resource-group "security-rg" \
  --location "australiaeast" \
  --enabled-for-deployment false \
  --enabled-for-disk-encryption false \
  --enabled-for-template-deployment false \
  --sku "standard" \
  --network-acls-ips "deny" 
```

## 5. S3 Transfer Pipeline with Geographic Controls

Create an Azure Logic App with tight geographic controls:

```bicep
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'australia-s3-transfer'
  location: 'australiaeast'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      // Logic App definition with S3 transfer
    }
    parameters: {
      // Parameters including S3 credentials from Key Vault
    }
  }
}
```

## 6. Azure Data Factory with Managed Identity

```bicep
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'australia-data-factory'
  location: 'australiaeast'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}
```

## 7. Create Audit Logging for Data Transfer Activities

```bash
# Set up Activity Log alert for data access
az monitor activity-log alert create \
  --name "data-transfer-alert" \
  --resource-group "monitoring-rg" \
  --condition "category=DataAction" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --action-group "security-team-ag"
```

## 8. Azure Resource Tags for Data Classification

```bash
az tag create --name "DataClassification" --values "Protected" "Sensitive" 
az tag create --name "DataLocation" --values "AustraliaOnly"

# Apply tags to storage accounts
az resource tag --tags "DataClassification=Protected" "DataLocation=AustraliaOnly" \
  --resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/data-rg/providers/Microsoft.Storage/storageAccounts/australialockeddata"
```

## 9. Azure Policy for Tag Enforcement

```bicep
resource tagEnforcementPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'enforce-data-classification-tags'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type',
            equals: 'Microsoft.Storage/storageAccounts'
          },
          {
            field: 'tags.DataLocation',
            notEquals: 'AustraliaOnly'
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

## 10. Access Control for Pipeline Identity

```bash
# Grant pipeline managed identity access to storage
PIPELINE_IDENTITY=$(az identity show --name "pipeline-identity" --resource-group "security-rg" --query principalId -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$PIPELINE_IDENTITY" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/data-rg/providers/Microsoft.Storage/storageAccounts/australialockeddata"
```

## Integration with S3 Transfer Pipeline

For the pipeline that pushes data to end-client S3 bucket:

1. **Use Managed Identity**: Ensure all S3 transfer jobs use Azure Managed Identity
2. **Run in Australian Region**: Deploy all Logic Apps/Functions in Australian datacenters
3. **Private Link for AWS**: Use AWS Private Link to connect to S3 over private network
4. **Encrypt Data in Transit**: Ensure TLS 1.2+ for all transfers
5. **Client-Side Encryption**: Consider encrypting data before it leaves Azure
6. **S3 Bucket Policy**: Recommend client applies policy to only accept connections from Australian IPs

## Compliance Documentation

For each data transfer, maintain an audit trail including:

1. Data source location (Australia)
2. Data processing location (Australia)
3. Data transfer method (Private endpoint)
4. Transfer validation checksum
5. Transfer completion timestamp
6. Verification that data remained in Australian jurisdiction

## Security Controls Verification

Run periodic verification of geo-controls:

```bash
# Script to verify all data storage is in Australian regions
az storage account list --query "[?location!='australiaeast' && location!='australiasoutheast'].{name:name, location:location}" -o table

# Verify network restrictions are active
az storage account list --query "[?networkRuleSet.defaultAction=='Allow'].name" -o table

# Verify private endpoints are configured
az network private-endpoint list --query "[].{name:name, privateLinkServiceConnections:privateLinkServiceConnections[].name}" -o table
```

These controls work together to ensure that:
1. Data is physically stored only in Australian regions
2. Access is restricted to Australian networks/endpoints
3. The transfer pipeline operates with least privilege
4. All data movement is audited and monitored
5. Policy enforcement prevents misconfiguration

With these controls in place, data sovereignty requirements can be maintained while still enabling efficient operation of the data pipeline to S3.