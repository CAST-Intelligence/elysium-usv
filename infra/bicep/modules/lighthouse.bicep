// Lighthouse Module for Elysium USV
// This module creates Azure Lighthouse delegations for NZ MSP tenancy

// Parameters
@description('Prefix for all Lighthouse delegations - useful for creating test delegations with unique names')
param lighthousePrefix string = ''

@description('Deploy to production or testing mode')
@allowed([
  'prod'
  'test'
])
param deploymentMode string = 'test'

@description('Management group IDs from management-groups module')
param managementGroupIds object

@description('Role IDs from rbac-roles module')
param roleIds object

@description('NZ MSP tenant ID (CAST tenant)')
param nzMspTenantId string = '11111111-1111-1111-1111-111111111111'  // Default to a placeholder value

@description('NZ MSP principal ID for infrastructure team')
param nzMspInfraPrincipalId string = '22222222-2222-2222-2222-222222222222'  // Default to a placeholder value

@description('NZ MSP principal ID for application team')
param nzMspAppPrincipalId string = '33333333-3333-3333-3333-333333333333'  // Default to a placeholder value

// Define the Lighthouse delegation for NZ MSP Infrastructure management
resource nzMspInfraDelegation 'Microsoft.ManagedServices/registrationDefinitions@2022-10-01' = {
  name: guid('nzMspInfraDelegation', deploymentMode, lighthousePrefix)
  properties: {
    registrationDefinitionName: '${lighthousePrefix}NZ MSP Infrastructure Delegation'
    description: 'Delegates infrastructure management to NZ MSP'
    managedByTenantId: nzMspTenantId
    authorizations: [
      {
        principalId: nzMspInfraPrincipalId
        principalIdDisplayName: 'NZ MSP Infrastructure Team'
        roleDefinitionId: roleIds.nzInfraAdminRoleId
      }
    ]
  }
}

// Define the Lighthouse delegation for NZ MSP Application management
resource nzMspAppDelegation 'Microsoft.ManagedServices/registrationDefinitions@2022-10-01' = {
  name: guid('nzMspAppDelegation', deploymentMode, lighthousePrefix)
  properties: {
    registrationDefinitionName: '${lighthousePrefix}NZ MSP Application Delegation'
    description: 'Delegates application management to NZ MSP'
    managedByTenantId: nzMspTenantId
    authorizations: [
      {
        principalId: nzMspAppPrincipalId
        principalIdDisplayName: 'NZ MSP Application Team'
        roleDefinitionId: roleIds.nzAppAdminRoleId
      }
    ]
  }
}

// Assign the Infrastructure Lighthouse delegation to the appropriate management groups
resource nzMspInfraProdAssignment 'Microsoft.ManagedServices/registrationAssignments@2022-10-01' = if (deploymentMode == 'prod') {
  name: guid(managementGroupIds.prodInfraMgId, nzMspInfraDelegation.id)
  properties: {
    registrationDefinitionId: nzMspInfraDelegation.id
  }
  scope: resourceGroup()
}

resource nzMspInfraTestAssignment 'Microsoft.ManagedServices/registrationAssignments@2022-10-01' = {
  name: guid(managementGroupIds.testInfraMgId, nzMspInfraDelegation.id)
  properties: {
    registrationDefinitionId: nzMspInfraDelegation.id
  }
  scope: resourceGroup()
}

// Assign the Application Lighthouse delegation to the appropriate management groups
resource nzMspAppProdAssignment 'Microsoft.ManagedServices/registrationAssignments@2022-10-01' = if (deploymentMode == 'prod') {
  name: guid(managementGroupIds.prodAppMgId, nzMspAppDelegation.id)
  properties: {
    registrationDefinitionId: nzMspAppDelegation.id
  }
  scope: resourceGroup()
}

resource nzMspAppTestAssignment 'Microsoft.ManagedServices/registrationAssignments@2022-10-01' = {
  name: guid(managementGroupIds.testAppMgId, nzMspAppDelegation.id)
  properties: {
    registrationDefinitionId: nzMspAppDelegation.id
  }
  scope: resourceGroup()
}

// Outputs
output nzMspInfraDelegationId string = nzMspInfraDelegation.id
output nzMspAppDelegationId string = nzMspAppDelegation.id