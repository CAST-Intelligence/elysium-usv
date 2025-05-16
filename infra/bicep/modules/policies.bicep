// Policies Module for Elysium USV
// This module creates and assigns policies for data sovereignty, security, and tagging

// Parameters
@description('Prefix for all policy names - useful for creating test policies with unique names')
param policyPrefix string = ''

@description('Deploy to production or testing mode')
@allowed([
  'prod'
  'test'
])
param deploymentMode string = 'test'

@description('Management group IDs from management-groups module')
param managementGroupIds object

// Australia-only location policy definition
resource australiaOnlyPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}prod-data-australia-only'
  properties: {
    displayName: 'Production Data Must Stay in Australia'
    description: 'Ensures all production data remains in Australian regions'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'location'
            notIn: [
              'australiaeast'
              'australiasoutheast'
            ]
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

// Test environment tagging policy definition
resource testEnvironmentTagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}test-environment-tagging'
  properties: {
    displayName: 'Test Environment Tagging Policy'
    description: 'Enforces consistent tagging for test environment resources'
    mode: 'Indexed'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags.Environment'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: 'modify'
        details: {
          operations: [
            {
              operation: 'addOrReplace'
              field: 'tags.Environment'
              value: 'Testing'
            }
          ]
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
        }
      }
    }
  }
}

// Storage account security policy definition
resource storageSecurityPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}storage-security-policy'
  properties: {
    displayName: 'Secure Storage Accounts'
    description: 'Enforces secure configuration for storage accounts'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
        ]
      }
      then: {
        effect: 'audit'
        details: {
          type: 'Microsoft.Storage/storageAccounts'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess'
                equals: 'false'
              }
              {
                field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion'
                equals: 'TLS1_2'
              }
              {
                field: 'Microsoft.Storage/storageAccounts/networkAcls.defaultAction'
                equals: 'Deny'
              }
            ]
          }
        }
      }
    }
  }
}

// OEM session monitoring policy definition
resource oemSessionPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}monitor-oem-sessions'
  properties: {
    displayName: 'Monitor OEM Configuration Sessions'
    description: 'Enforces enhanced monitoring for OEM configuration sessions'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags.USVComponent'
            equals: 'OEMConfiguration'
          }
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
        ]
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          name: 'AuditSettings'
          deploymentScope: 'resourceGroup'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Insights/diagnosticSettings/logs.enabled'
                equals: 'true'
              }
            ]
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  workspaceId: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Compute/virtualMachines/providers/diagnosticSettings'
                    apiVersion: '2021-05-01-preview'
                    name: '[concat(parameters(\'vmName\'), \'/Microsoft.Insights/AuditSettings\')]'
                    location: '[parameters(\'location\')]'
                    properties: {
                      workspaceId: '[parameters(\'workspaceId\')]'
                      logs: [
                        {
                          category: 'Administrative'
                          enabled: true
                        }
                        {
                          category: 'Security'
                          enabled: true
                        }
                        {
                          category: 'Alert'
                          enabled: true
                        }
                      ]
                      metrics: [
                        {
                          category: 'AllMetrics'
                          enabled: true
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
  }
}

// Policy assignments

// Assign Australia-only policy to production data management group
resource prodDataGeoPolicyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}australia-only-assignment'
  properties: {
    policyDefinitionId: australiaOnlyPolicy.id
    displayName: 'Production Data Location'
    description: 'Ensures all production data resources are created in Australian regions'
  }
  scope: deploymentMode == 'prod' ? managementGroupIds.prodDataMgId : managementGroupIds.testDataMgId
}

// Assign tagging policy to test management group
resource testTagPolicyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}environment-tagging-assignment'
  properties: {
    policyDefinitionId: testEnvironmentTagPolicy.id
    displayName: 'Test Environment Tagging'
    description: 'Enforces consistent tagging for test environment resources'
  }
  scope: managementGroupIds.testMgId
}

// Assign storage security policy to both prod and test data management groups
resource storageSecurityProdAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}storage-security-prod-assignment'
  properties: {
    policyDefinitionId: storageSecurityPolicy.id
    displayName: 'Secure Storage Accounts - Production'
    description: 'Enforces secure configuration for production storage accounts'
  }
  scope: managementGroupIds.prodDataMgId
}

resource storageSecurityTestAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}storage-security-test-assignment'
  properties: {
    policyDefinitionId: storageSecurityPolicy.id
    displayName: 'Secure Storage Accounts - Test'
    description: 'Enforces secure configuration for test storage accounts'
  }
  scope: managementGroupIds.testDataMgId
}

// Assign OEM session monitoring policy to test infrastructure management group
resource oemSessionPolicyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}oem-monitoring-assignment'
  properties: {
    policyDefinitionId: oemSessionPolicy.id
    displayName: 'Monitor OEM Configuration Sessions'
    description: 'Enforces enhanced monitoring for OEM configuration sessions'
  }
  scope: managementGroupIds.testInfraMgId
}

// Output policy IDs
output australiaOnlyPolicyId string = australiaOnlyPolicy.id
output testEnvironmentTagPolicyId string = testEnvironmentTagPolicy.id
output storageSecurityPolicyId string = storageSecurityPolicy.id
output oemSessionPolicyId string = oemSessionPolicy.id