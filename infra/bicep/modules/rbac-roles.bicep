// RBAC Roles Module for Elysium USV
// This module creates custom RBAC roles for NZ MSP, US OEM, and AU team

// Parameters
@description('Prefix for all role names - useful for creating test roles with unique names')
param rolePrefix string = ''

@description('Deploy to production or testing mode')
@allowed([
  'prod'
  'test'
])
param deploymentMode string = 'test'

@description('Management group IDs from management-groups module')
param managementGroupIds object

// Custom role definitions

// NZ MSP Infrastructure Admin Role
resource nzInfraAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('${rolePrefix}USV-NZ-Infrastructure-Admin')
  properties: {
    roleName: '${rolePrefix}USV-NZ-Infrastructure-Admin'
    description: 'Infrastructure management for NZ MSP'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/*'
          'Microsoft.Web/sites/*'
          'Microsoft.Network/*'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Storage/storageAccounts/write'
          'Microsoft.Insights/components/*'
          'Microsoft.OperationalInsights/workspaces/read'
        ]
        notActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
          'Microsoft.KeyVault/vaults/secrets/read'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroupIds.prodInfraMgId
      managementGroupIds.testInfraMgId
    ]
  }
}

// US OEM Ground Station Admin Role
resource usGroundStationRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('${rolePrefix}USV-US-GroundStation-Config')
  properties: {
    roleName: '${rolePrefix}USV-US-GroundStation-Config'
    description: 'Temporary access for US OEM to configure ground station'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/write'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/restart/action'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkInterfaces/write'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/publicIPAddresses/join/action'
        ]
        notActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
          'Microsoft.KeyVault/vaults/secrets/read'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroupIds.testInfraMgId
    ]
  }
}

// AU Data Admin Role
resource auDataAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('${rolePrefix}USV-AU-Data-Admin')
  properties: {
    roleName: '${rolePrefix}USV-AU-Data-Admin'
    description: 'Full data access for Australian administrators'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete'
          'Microsoft.KeyVault/vaults/secrets/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroupIds.prodDataMgId
      managementGroupIds.testDataMgId
    ]
  }
}

// NZ MSP Application Admin Role
resource nzAppAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('${rolePrefix}USV-NZ-App-Admin')
  properties: {
    roleName: '${rolePrefix}USV-NZ-App-Admin'
    description: 'Application management for NZ MSP'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Web/sites/read'
          'Microsoft.Web/sites/write'
          'Microsoft.Web/sites/config/read'
          'Microsoft.Web/sites/config/write'
          'Microsoft.Web/sites/restart/action'
          'Microsoft.Web/sites/slots/read'
          'Microsoft.Web/sites/slots/write'
        ]
        notActions: [
          'Microsoft.Web/sites/config/list/action'
          'Microsoft.Web/sites/config/appsettings/list/action'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroupIds.prodAppMgId
      managementGroupIds.testAppMgId
    ]
  }
}

// Output role IDs for other modules
output nzInfraAdminRoleId string = nzInfraAdminRole.id
output usGroundStationRoleId string = usGroundStationRole.id
output auDataAdminRoleId string = auDataAdminRole.id
output nzAppAdminRoleId string = nzAppAdminRole.id