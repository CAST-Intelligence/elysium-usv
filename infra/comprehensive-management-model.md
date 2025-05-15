# Comprehensive Management Model for USV Pipeline

This updated model incorporates requirements for multiple stakeholders (AU, NZ, US) and implements a management group-based approach with proper separation of testing and production environments.

## Multi-Stakeholder Analysis

The USV Pipeline has three key stakeholders with different access requirements:

1. **Australian Team (Elysium)** - Full control, data access rights, compliance responsibility
2. **NZ-based MSP (CAST)** - Infrastructure management, support, maintenance
3. **US-based OEM (SeaSats)** - Ground station configuration, USV integration, temporary access

## Management Group Hierarchy

We recommend structuring Azure using management groups for better policy inheritance and access control:

```
Root Management Group
├── Elysium-USV-MG (Top-level for all USV resources)
│   ├── USV-Production-MG (Production environment)
│   │   ├── USV-Prod-Infra-MG (Infrastructure components)
│   │   ├── USV-Prod-App-MG (Application components)
│   │   └── USV-Prod-Data-MG (Data components - AU only)
│   │
│   ├── USV-Testing-MG (Test environment)
│   │   ├── USV-Test-Infra-MG (Test infrastructure)
│   │   ├── USV-Test-App-MG (Test applications)
│   │   └── USV-Test-Data-MG (Test data - AU only)
│   │
│   └── USV-Shared-MG (Shared services)
│       ├── USV-Monitoring-MG (Monitoring resources)
│       └── USV-Security-MG (Security resources)
```

## Management Group-Scoped RBAC Model

### 1. Infrastructure Management Roles

#### 1.1 NZ MSP Infrastructure Admin (CAST)
```json
{
  "Name": "USV-NZ-Infrastructure-Admin",
  "Description": "Infrastructure management for NZ MSP",
  "Actions": [
    "Microsoft.Compute/virtualMachines/*",
    "Microsoft.Web/sites/*",
    "Microsoft.Network/*",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/write",
    "Microsoft.Insights/components/*",
    "Microsoft.OperationalInsights/workspaces/read"
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.KeyVault/vaults/secrets/read"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/USV-Prod-Infra-MG",
    "/providers/Microsoft.Management/managementGroups/USV-Test-Infra-MG"
  ]
}
```

#### 1.2 US OEM Ground Station Admin (SeaSats)
```json
{
  "Name": "USV-US-GroundStation-Config",
  "Description": "Temporary access for US OEM to configure ground station",
  "Actions": [
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    "Microsoft.Network/networkInterfaces/read",
    "Microsoft.Network/networkInterfaces/write",
    "Microsoft.Network/publicIPAddresses/read",
    "Microsoft.Network/publicIPAddresses/join/action"
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.KeyVault/vaults/secrets/read"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/USV-Test-Infra-MG"
  ]
}
```

### 2. Application Management Roles

#### 2.1 NZ MSP Application Admin
```json
{
  "Name": "USV-NZ-App-Admin",
  "Description": "Application management for NZ MSP",
  "Actions": [
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/write",
    "Microsoft.Web/sites/config/read",
    "Microsoft.Web/sites/config/write",
    "Microsoft.Web/sites/restart/action",
    "Microsoft.Web/sites/slots/read",
    "Microsoft.Web/sites/slots/write"
  ],
  "NotActions": [
    "Microsoft.Web/sites/config/list/action",
    "Microsoft.Web/sites/config/appsettings/list/action"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/USV-Prod-App-MG",
    "/providers/Microsoft.Management/managementGroups/USV-Test-App-MG"
  ]
}
```

### 3. Data Management Roles (AU Only)

```json
{
  "Name": "USV-AU-Data-Admin",
  "Description": "Full data access for Australian administrators",
  "Actions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
    "Microsoft.KeyVault/vaults/secrets/read"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/USV-Prod-Data-MG",
    "/providers/Microsoft.Management/managementGroups/USV-Test-Data-MG"
  ]
}
```

## Temporary Access Model for US OEM

To handle the US-based OEM's need for ground station VM configuration:

### 1. Just-In-Time VM Access with PIM

```bash
# Create a PIM-enabled role assignment
az rest --method POST \
  --uri "https://management.azure.com/providers/Microsoft.Authorization/roleAssignmentScheduleRequests?api-version=2020-10-01" \
  --headers "Content-Type=application/json" \
  --body "{
    \"properties\": {
      \"principalId\": \"${US_OEM_USER_ID}\",
      \"roleDefinitionId\": \"/providers/Microsoft.Authorization/roleDefinitions/${USV_US_GROUNDSTATION_ROLE_ID}\",
      \"requestType\": \"AdminExtend\",
      \"justification\": \"Ground station configuration for USV deployment\",
      \"scheduleName\": \"USVConfigSession\",
      \"duration\": \"PT8H\",
      \"scope\": \"/providers/Microsoft.Management/managementGroups/USV-Test-Infra-MG\"
    }
  }"
```

### 2. Configuration VM Pattern

Deploy a dedicated configuration VM that has:
1. Network access to ground station VM 
2. Pre-installed OEM tools
3. Screenshots recorded for audit purposes
4. No data storage capabilities

```bicep
resource oemJumpBox 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: 'usv-oem-jumpbox'
  location: 'australiaeast'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: oemJumpBoxNic.id
        }
      ]
    }
    osProfile: {
      computerName: 'usv-oem-jumpbox'
      adminUsername: 'oemadmin'
      adminPassword: 'secure-password-from-keyvault'
    }
  }
  tags: {
    USVComponent: 'OEMConfiguration'
    DataAccess: 'None'
    TemporaryResource: 'True'
  }
}
```

### 3. Session Monitoring Policy

```bicep
resource oemSessionPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'monitor-oem-sessions'
  properties: {
    displayName: 'Monitor OEM Configuration Sessions'
    description: 'Enforces enhanced monitoring for OEM configuration sessions'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags.USVComponent',
            equals: 'OEMConfiguration'
          },
          {
            field: 'type',
            equals: 'Microsoft.Compute/virtualMachines'
          }
        ]
      },
      then: {
        effect: 'deployIfNotExists',
        details: {
          type: 'Microsoft.Insights/diagnosticSettings',
          name: 'AuditSettings',
          deploymentScope: 'resourceGroup',
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Insights/diagnosticSettings/logs.enabled',
                equals: 'true'
              }
            ]
          },
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ],
          deployment: {
            properties: {
              mode: 'incremental',
              template: {
                // Enhanced monitoring template
              }
            }
          }
        }
      }
    }
  }
}
```

## Management Group-Specific Azure Policies

### 1. Production Data Geo-Restriction

```bicep
resource prodDataGeoPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'prod-data-australia-only'
  properties: {
    displayName: 'Production Data Must Stay in Australia'
    description: 'Ensures all production data remains in Australian regions'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
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

// Assign to production data management group
resource prodDataGeoPolicyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'prod-data-geo-assignment'
  properties: {
    policyDefinitionId: prodDataGeoPolicy.id
    displayName: 'Production Data Location'
    scope: '/providers/Microsoft.Management/managementGroups/USV-Prod-Data-MG'
  }
}
```

### 2. Testing Environment Tagging Policy

```bicep
resource testEnvironmentTagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'test-environment-tagging'
  properties: {
    displayName: 'Test Environment Tagging Policy'
    description: 'Enforces consistent tagging for test environment resources'
    mode: 'Indexed'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags.Environment',
            exists: 'false'
          }
        ]
      },
      then: {
        effect: 'modify',
        details: {
          operations: [
            {
              operation: 'addOrReplace',
              field: 'tags.Environment',
              value: 'Testing'
            }
          ],
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
        }
      }
    }
  }
}

// Assign to testing management group
resource testTagPolicyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'test-tag-assignment'
  properties: {
    policyDefinitionId: testEnvironmentTagPolicy.id
    displayName: 'Test Environment Tagging'
    scope: '/providers/Microsoft.Management/managementGroups/USV-Testing-MG'
  }
}
```

## Lighthouse Implementation for Management Groups

### 1. NZ MSP Infrastructure Access Delegation

```bash
# Deploy with management group scope for infrastructure components
./lighthouse-test/deploy-delegation.sh \
  --scope mg \
  --tenant "${NZ_MSP_TENANT_ID}" \
  --principal "${NZ_MSP_PRINCIPAL_ID}" \
  --mg-id "USV-Prod-Infra-MG" \
  --name "NZ MSP Infrastructure Team"
```

### 2. NZ MSP Application Access Delegation

```bash
# Deploy with management group scope for application components
./lighthouse-test/deploy-delegation.sh \
  --scope mg \
  --tenant "${NZ_MSP_TENANT_ID}" \
  --principal "${NZ_MSP_PRINCIPAL_ID}" \
  --mg-id "USV-Prod-App-MG" \
  --name "NZ MSP Application Team"
```

### 3. US OEM Test Environment Temporary Access

```bash
# For US OEM, we don't use Lighthouse but instead use PIM for temporary access
# The US team would request access via PIM to the ground station resources
# This keeps their access temporary, scoped, and under AU team approval
```

## Multi-Region Conditional Access

### For Production Data Access

```
Name: USV-Production-Data-Protection
Target Users: All users with data access roles
Conditions:
  - Exclude Australian IPs
  - Target data storage applications
  - Include all device types
Controls:
  - Block access completely (no exceptions)
Session Controls:
  - N/A (blocked)
```

### For US OEM Ground Station Configuration

```
Name: US-OEM-Temporary-Access
Target Users: US OEM team members
Conditions:
  - Apply when accessing ground station resources
  - All locations
  - All device types
Controls:
  - Grant access with:
    - Require MFA
    - Require approved Australian approver
    - Require device compliance
    - Maximum session length: 8 hours
Session Controls:
  - Sign-in frequency: 1 hour
  - Screen recording enabled
  - App enforced restrictions
```

## Implementation Sequence

1. Create the management group hierarchy
2. Define custom RBAC roles for each stakeholder group
3. Apply MG-level policies for environment separation
4. Implement conditional access policies for geographic restrictions
5. Deploy Lighthouse delegations for NZ MSP at appropriate MG scopes
6. Configure PIM for US OEM team access to ground station resources
7. Set up monitoring and alerting based on management group structure
8. Document access patterns for each stakeholder

## Test and Production Management Group Differences

| Feature | Test MG | Production MG |
|---------|---------|--------------|
| Data Retention | 7 days | Based on compliance requirements |
| Access Control | Less stringent | Strict AU-only for data |
| US OEM Access | Permitted with monitoring | Not permitted (config done in test) |
| Resource Locks | None | CanNotDelete on data resources |
| Alerting | Limited alerts | Comprehensive alerting |
| Deployment Methods | CI/CD allowed | Manual approval required |
| Network Access | Broader | Restricted to AU IPs for data |

This model provides:
1. Clear separation between test and production environments
2. Proper role-based access for each stakeholder group
3. Management group-based policy inheritance
4. Temporary, secure access for US OEM to configure ground station VMs
5. Comprehensive auditing and compliance