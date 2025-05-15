# NZ MSP Lighthouse Implementation with AU Data Sovereignty

This document outlines the implementation strategy for using Azure Lighthouse to enable New Zealand-based MSP management of Australian resources while maintaining strict data sovereignty requirements.

## Multi-Phase Lighthouse Implementation

### Phase 1: Development & Testing (Time-Limited)
```bicep
param authorizations array = [
  {
    principalId: '${MSP_PRINCIPAL_ID}'
    principalIdDisplayName: 'NZ MSP Admin (Temporary)'
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    delegatedRoleDefinitionIds: ['b24988ac-6180-42a0-ab88-20f7382dd24c']
    // Scoped to management/infra resource groups only
  }
]
```

**Access Controls:**
1. Time-limited using Azure AD Privileged Identity Management (PIM)
2. Just-in-time admin elevation with approval workflow
3. Enhanced auditing during privileged sessions

### Phase 2: Production Operations (Permanent)
```bicep
param authorizations array = [
  {
    // Infrastructure Admin role - NO data access
    principalId: '${MSP_PRINCIPAL_ID}'
    principalIdDisplayName: 'NZ MSP Infrastructure Admin'
    roleDefinitionId: 'custom-role-id-infrastructure-admin' // Custom role with no data access
    delegatedRoleDefinitionIds: ['custom-role-id-infrastructure-admin']
  }
]
```

**Custom RBAC Role:**
```json
{
  "Name": "Infrastructure Admin No Data",
  "Description": "Can manage infrastructure but cannot access data",
  "Actions": [
    "Microsoft.Resources/deployments/*",
    "Microsoft.Network/*",
    "Microsoft.Compute/*/read",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    // Add other needed management permissions
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.DBforPostgreSQL/servers/databases/read",
    // Block ALL data plane operations
  ]
}
```

## Data Sovereignty Controls

1. **Geo-fencing with Azure Policy:**
```bicep
resource dataSovereigntyPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'enforce-australia-regions'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        not: {
          field: 'location',
          in: [
            'australiaeast',
            'australiasoutheast'
          ]
        }
      },
      then: {
        effect: 'deny'
      }
    }
  }
}
```

2. **Conditional Access for Emergencies:**
```
// Requires Australian admin approval for NZ access
// Time-limited access with enhanced monitoring
// Pre-approved access paths only
```

3. **Temporary Admin Access Protocol:**
```
1. Australian admin initiates access request
2. Justification documented and recorded
3. Time-limited token generated (max 8 hours)
4. All actions logged to separate immutable audit store
5. Post-access review required
```

## Implementation Steps

1. **Create Resource Group Structure:**
   - Management RGs: `<prefix>-management-rg` (NZ MSP full access)
   - Data RGs: `<prefix>-data-rg` (Australian access only)

2. **Deploy Custom Roles:**
   - InfrastructureAdminNoData (for NZ MSP)
   - DataOperator (for Australian team)

3. **Deploy Resource Locks:**
   - CanNotDelete locks on all data resource groups
   - No management access to modify locks for NZ MSP

4. **Create Separate Lighthouse Offers:**
   - `infrastructure-management-offer` (for NZ MSP)
   - `data-operations-offer` (for local AU operators if needed)

## Resource Type Scoping Approaches

Since Lighthouse doesn't directly support resource type scoping, use these approaches:

### Custom RBAC Roles
```bicep
// In your deployment script, first create a custom role
az role definition create --role-definition "{ 
  \"Name\": \"Storage Account Manager\", 
  \"Actions\": [\"Microsoft.Storage/storageAccounts/*\"], 
  \"NotActions\": [], 
  \"AssignableScopes\": [\"/subscriptions/${subscriptionId}\"] 
}"

// Then use that role ID in your Lighthouse delegation
param authorizations array = [
  {
    principalId: '${MSP_PRINCIPAL_ID}'
    principalIdDisplayName: 'Storage Administrator'
    roleDefinitionId: 'your-custom-role-id'
    delegatedRoleDefinitionIds: ['your-custom-role-id']
  }
]
```

### Resource Group Organization
```
// Group resources by type in different RGs
storage-rg → Delegate access to storage managers
compute-rg → Delegate access to compute managers
data-rg → Keep private, no delegation
```

## Complete Implementation Approach

```bash
# 1. Create region restriction policy
az policy definition create --name "AustraliaOnlyResources" \
  --display-name "Restrict to Australian Regions" \
  --description "Only allows resources to be created in Australian regions" \
  --rules '{
    "if": {
      "not": {
        "field": "location",
        "in": ["australiaeast", "australiasoutheast"]
      }
    },
    "then": {
      "effect": "deny"
    }
  }'

# 2. Assign the policy to subscription
az policy assignment create --name "AustraliaOnly" \
  --policy "AustraliaOnlyResources" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"

# 3. Create custom role with no data access
az role definition create --role-definition '{
  "Name": "Infrastructure Manager No Data",
  "Description": "Can manage infrastructure but not access data content",
  "Actions": [
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Network/*",
    "Microsoft.Compute/virtualMachines/*"
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/fileServices/shares/files/read"
  ],
  "AssignableScopes": ["/subscriptions/${SUBSCRIPTION_ID}"]
}'

# 4. Get the new role ID for your Lighthouse delegation
CUSTOM_ROLE_ID=$(az role definition list --name "Infrastructure Manager No Data" --query "[].name" -o tsv)

# 5. Deploy Lighthouse with custom role
# (Use the deployment script with the custom role ID)
```

This approach provides the necessary control to allow NZ-based MSP to manage infrastructure while maintaining strict data sovereignty for Australian data.