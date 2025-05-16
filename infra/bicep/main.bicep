// Main Bicep file for Elysium USV Infrastructure
// This file orchestrates the deployment of management groups, RBAC roles, policies, and lighthouse delegations

// Since we're deploying to tenant scope, we need a specialized approach
// The actual deployment will be handled by a bash script that deploys each module separately

// Parameters 
@description('Prefix for all resources - useful for creating test structures with unique names')
param prefix string = ''

@description('Deploy to production or testing mode')
@allowed([
  'prod'
  'test'
])
param deploymentMode string = 'test'

@description('NZ MSP (CAST) tenant ID')
param nzMspTenantId string = '01ad0f0b-0b87-4459-9e8a-cca048e3c04e'  // Default to Selwyn's tenant for testing

@description('NZ MSP infrastructure team principal ID')
param nzMspInfraPrincipalId string = '00000000-0000-0000-0000-000000000000'  // Replace with actual ID

@description('NZ MSP application team principal ID')
param nzMspAppPrincipalId string = '00000000-0000-0000-0000-000000000000'  // Replace with actual ID

// This is a tenant-level deployment template that will be broken down into individual deployments
// by the deployment script since Bicep has limitations with tenant-scoped module references

// For direct use of this template, update the modules scope parameter as needed
// We don't reference modules directly in a tenant-scoped template since each 
// module needs individual scoping rules

// Output expected configuration values for deployment script reference
output config object = {
  prefix: prefix
  deploymentMode: deploymentMode
  nzMspTenantId: nzMspTenantId
  nzMspInfraPrincipalId: nzMspInfraPrincipalId
  nzMspAppPrincipalId: nzMspAppPrincipalId
}