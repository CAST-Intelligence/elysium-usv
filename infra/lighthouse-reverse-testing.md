# Lighthouse Reverse Testing: CAST as Customer, Personal Tenant as MSP

This document outlines the technical steps for setting up a test of Azure Lighthouse where CAST is the customer tenant and your personal Azure tenant acts as the Managed Service Provider (MSP). This reversed approach will still validate the technical aspects of the Lighthouse delegation process.

## Required Information

Before beginning, please gather the following information:

**CAST Tenant (Customer):**
- Tenant ID: `CAST_TENANT_ID` (replace with actual ID)
- Subscription ID: `CAST_SUBSCRIPTION_ID` (replace with actual ID)
- Resource Group: `CAST_RG` (create or use existing resource group)

```bash
# Set these variables in your shell
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export CAST_TENANT_ID="eba85e58-f7bf-4a54-9a42-5e4a3cc60ad0"
export CAST_RG="lighthouse-test-rg"
```

**Selwyn's Personal Tenant (MSP):**
- Tenant ID: `SELWYN_PERSONAL_TENANT_ID` (replace with actual ID)
- User principal ID (your account): `SELWYN_PERSONAL_USER_ID` (get from Azure AD → Users)
- Email associated with your account: `SELWYN_PERSONAL_EMAIL`

```bash
# Set these variables in your shell
export SELWYN_PERSONAL_TENANT_ID="01ad0f0b-0b87-4459-9e8a-cca048e3c04e"
export SELWYN_PERSONAL_USER_ID="4519de0c-bfce-4562-8d23-a35ae529fc55"
export SELWYN_PERSONAL_EMAIL="selwyn.mccracken@gmail.com"
```

## 1. Setup in CAST Tenant (Customer)

First, you'll create resources in the CAST tenant that will be managed by your personal tenant.

```bash
# Log in to CAST tenant
az login --tenant "${CAST_TENANT_ID}"

# Verify you're in the right tenant
az account show --query "{name:name, id:id, tenantId:tenantId}"

# Create or use an existing resource group
az group create --name "${CAST_RG}" --location "australiaeast" --subscription "${CAST_SUBSCRIPTION_ID}"

# Optional: Create a test resource for management
az storage account create --name "caststoragelh$(date +%s)" --resource-group "${CAST_RG}" --location "australiaeast" --sku "Standard_LRS"
```

## 2. Create Lighthouse Delegation with Bicep

Create a Bicep template that will delegate access to your personal tenant.

```bash
# Create a directory for Lighthouse resources
mkdir -p lighthouse-test
cd lighthouse-test

# Create Bicep template for Lighthouse delegation
cat > lighthouse-delegation.bicep << EOF
// lighthouse-delegation.bicep

// Parameters
@description('Name of the managed service offer')
param mspOfferName string = 'Selwyn Personal Tenant Management'

@description('Description of the managed service offer')
param mspOfferDescription string = 'Lighthouse test delegation to personal tenant'

@description('Tenant ID of the MSP')
param managedByTenantId string = '${SELWYN_PERSONAL_TENANT_ID}'

@description('Array of role assignments for the MSP')
param authorizations array = [
  {
    principalId: '${SELWYN_PERSONAL_USER_ID}'
    principalIdDisplayName: 'Selwyn Personal Admin'
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role
  }
]

// Resources
resource registrationDefinition 'Microsoft.ManagedServices/registrationDefinitions@2019-09-01' = {
  name: guid(mspOfferName)
  properties: {
    registrationDefinitionName: mspOfferName
    description: mspOfferDescription
    managedByTenantId: managedByTenantId
    authorizations: authorizations
  }
}

resource registrationAssignment 'Microsoft.ManagedServices/registrationAssignments@2019-09-01' = {
  name: guid(mspOfferName)
  dependsOn: [
    registrationDefinition
  ]
  properties: {
    registrationDefinitionId: registrationDefinition.id
  }
}

// Outputs
output registrationDefinitionId string = registrationDefinition.id
output registrationAssignmentId string = registrationAssignment.id
EOF
```

## 3. Deploy Lighthouse Delegation with Bicep

Now deploy the Bicep template to allow your personal tenant to manage CAST resources.

```bash
# First, ensure Bicep is installed
az bicep install

# IMPORTANT: Lighthouse delegation must be at subscription scope, not resource group scope
# Deploy Lighthouse delegation at subscription level
az deployment sub create \
  --name "selwyn-personal-lighthouse-delegation" \
  --location "australiaeast" \
  --template-file "lighthouse-delegation.bicep"
```

## 4. Verify Lighthouse Setup from MSP Side

After setting up the delegation, verify that your personal tenant can access CAST resources.

```bash
# Log out of CAST tenant
az logout

# Log in to your personal tenant
az login --tenant "${SELWYN_PERSONAL_TENANT_ID}"

# List delegated resources (should show CAST resources)
az resource list --query "[?managedBy!=null]"

# List all delegated tenants
az rest --method GET \
  --uri "https://management.azure.com/providers/Microsoft.ManagedServices/operationStatuses/getAllTenants?api-version=2019-09-01" \
  --query "properties.delegatedResourceTenants"
```

## 3.1 Creating Test Resources in CAST Tenant

Before updating the Lighthouse delegation, let's create a specific resource group for testing:

```bash
# Log in to CAST tenant
az login --tenant "${CAST_TENANT_ID}"

# Verify you're in the right tenant
az account show --query "{name:name, id:id, tenantId:tenantId}"

# Create a dedicated test resource group
export TEST_RG="selwyn-test-rg"
az group create --name "${TEST_RG}" --location "australiaeast"

# Create a test storage account in the resource group
RANDOM_STR=$(openssl rand -hex 4)
STORAGE_ACCT="selwyntest${RANDOM_STR}"
az storage account create \
  --name "${STORAGE_ACCT}" \
  --resource-group "${TEST_RG}" \
  --location "australiaeast" \
  --sku "Standard_LRS"

# Optionally create an App Service Plan to test more resource types
az appservice plan create \
  --name "selwyn-test-plan" \
  --resource-group "${TEST_RG}" \
  --sku "B1" \
  --is-linux
```

You can also run the provided script to create these resources in one go:
```bash
chmod +x ./lighthouse-test/create-test-resources.sh
./lighthouse-test/create-test-resources.sh
```

## 3.2 Deploy Updated Lighthouse Delegation

Now deploy the updated Bicep template to scope your access to just the test resource group:

```bash
# Deploy the updated Lighthouse delegation at subscription level
# but with scope limited to the test resource group
az deployment sub create \
  --name "selwyn-rg-scoped-delegation" \
  --location "australiaeast" \
  --template-file "lighthouse-delegation.bicep" \
  --parameters resourceGroupName="${TEST_RG}"
```

## 5. Perform Test Operations as MSP

Now you can test managing CAST resources from your personal tenant. Here are some sample operations:

```bash
# Get CAST subscription details
az account list --query "[?tenantId=='${CAST_TENANT_ID}']"
CAST_SUB_ID=$(az account list --query "[?tenantId=='${CAST_TENANT_ID}'].id" -o tsv)

# List resources in the delegated resource group
az resource list --subscription "$CAST_SUB_ID" --resource-group "${TEST_RG}"

# Create a test resource in CAST tenant
az webapp create \
  --name "selwyn-test-webapp" \
  --resource-group "${TEST_RG}" \
  --subscription "$CAST_SUB_ID" \
  --plan "selwyn-test-plan"

# Example management task: view storage accounts
az storage account list --subscription "$CAST_SUB_ID" --resource-group "${TEST_RG}" --query "[].name"

# Example management task: list storage keys (testing permission boundaries)
STORAGE_ACCT=$(az storage account list --subscription "$CAST_SUB_ID" --resource-group "${TEST_RG}" --query "[0].name" -o tsv)
az storage account keys list \
  --account-name "$STORAGE_ACCT" \
  --resource-group "${TEST_RG}" \
  --subscription "$CAST_SUB_ID"

# Verify you CANNOT access resources outside your scoped resource group
az resource list --subscription "$CAST_SUB_ID" --resource-group "some-other-rg"
```

## 6. Monitoring Lighthouse Activities

In the CAST tenant, you can monitor activities performed via Lighthouse:

```bash
# Switch back to CAST tenant
az login --tenant "${CAST_TENANT_ID}"

# View activity by MSP users
az monitor activity-log list \
  --resource-group "${CAST_RG}" \
  --caller "${SELWYN_PERSONAL_EMAIL}" \
  --query "[].{Operation:operationName.localizedValue, Status:status.localizedValue, Time:eventTimestamp}"
```

## 7. Clean Up

When testing is completed, you can clean up the Lighthouse delegation.

```bash
# From CAST tenant
az login --tenant "${CAST_TENANT_ID}"

# List Lighthouse assignments
az managedservices assignment list --query "[].{Name:name, Definition:properties.registrationDefinitionId}"

# Remove Lighthouse delegation (use IDs from previous command)
ASSIGNMENT_ID=$(az managedservices assignment list --query "[0].name" -o tsv)
DEFINITION_ID=$(az managedservices assignment list --query "[0].properties.registrationDefinitionId" -o tsv | cut -d'/' -f3)

az managedservices assignment delete --assignment "$ASSIGNMENT_ID"
az managedservices definition delete --definition "$DEFINITION_ID"
```

## Differences from Production Implementation

This test reverses the roles from the actual implementation:
1. In this test: CAST = customer, Personal tenant = MSP
2. In production: Elysium = customer, CAST = MSP

The technical process remains the same, but in production:
- You would deploy from the Elysium tenant to delegate to CAST
- CAST would access Elysium resources through Lighthouse
- Strict RBAC and conditional access policies would be implemented
- Location-based and role-based restrictions would be in place

## Notes on Multi-tenancy Implementation

For Azure Lighthouse implementations:
- The customer tenant (owner of the resources) maintains full control
- MSP access can be scoped to specific roles and resources
- MSP actions are auditable in the customer's activity logs
- Policies and access controls remain in effect for MSP users
- No data or resources are transferred between tenants