# Management Group Structure Testing Plan

This document outlines a step-by-step plan to implement a test version of the management group structure in the CAST tenancy and validate that the security controls function as expected.

## 1. Management Group Structure Implementation

First, we'll create a script to establish the management group hierarchy in the CAST tenant for testing.

```bash
#!/bin/bash
# Script to create management group structure for testing in CAST tenant
# Location: /infra/scripts/create-mg-structure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set variables
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export CAST_TENANT_ID="eba85e58-f7bf-4a54-9a42-5e4a3cc60ad0"
export LOCATION="australiaeast"
export TEST_PREFIX="USV-TEST-"  # Use a prefix to avoid conflicts with real structure

# Management Group Structure
MG_ROOT="${TEST_PREFIX}ROOT"
MG_ELYSIUM="${TEST_PREFIX}ELYSIUM"
MG_PROD="${TEST_PREFIX}PROD"
MG_TEST="${TEST_PREFIX}TEST"
MG_SHARED="${TEST_PREFIX}SHARED"
MG_PROD_INFRA="${TEST_PREFIX}PROD-INFRA"
MG_PROD_APP="${TEST_PREFIX}PROD-APP"
MG_PROD_DATA="${TEST_PREFIX}PROD-DATA"
MG_TEST_INFRA="${TEST_PREFIX}TEST-INFRA"
MG_TEST_APP="${TEST_PREFIX}TEST-APP"
MG_TEST_DATA="${TEST_PREFIX}TEST-DATA"
MG_MONITOR="${TEST_PREFIX}MONITOR"
MG_SECURITY="${TEST_PREFIX}SECURITY"

# Log in to Azure
echo -e "${BLUE}Logging in to Azure...${NC}"
az login --tenant "$CAST_TENANT_ID"

# Set subscription
echo -e "${BLUE}Setting subscription to $CAST_SUBSCRIPTION_ID...${NC}"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

# Create root management group
echo -e "${BLUE}Creating root management group...${NC}"
az account management-group create --name "$MG_ROOT" --display-name "USV Test Root"

# Create level 1 management groups
echo -e "${BLUE}Creating level 1 management groups...${NC}"
az account management-group create --name "$MG_ELYSIUM" --display-name "USV Test Elysium" --parent "$MG_ROOT"

# Create level 2 management groups
echo -e "${BLUE}Creating level 2 management groups...${NC}"
az account management-group create --name "$MG_PROD" --display-name "USV Test Production" --parent "$MG_ELYSIUM"
az account management-group create --name "$MG_TEST" --display-name "USV Test Environment" --parent "$MG_ELYSIUM"
az account management-group create --name "$MG_SHARED" --display-name "USV Test Shared" --parent "$MG_ELYSIUM"

# Create level 3 management groups
echo -e "${BLUE}Creating level 3 management groups...${NC}"
az account management-group create --name "$MG_PROD_INFRA" --display-name "USV Test Production Infrastructure" --parent "$MG_PROD"
az account management-group create --name "$MG_PROD_APP" --display-name "USV Test Production Application" --parent "$MG_PROD"
az account management-group create --name "$MG_PROD_DATA" --display-name "USV Test Production Data" --parent "$MG_PROD"
az account management-group create --name "$MG_TEST_INFRA" --display-name "USV Test Environment Infrastructure" --parent "$MG_TEST"
az account management-group create --name "$MG_TEST_APP" --display-name "USV Test Environment Application" --parent "$MG_TEST"
az account management-group create --name "$MG_TEST_DATA" --display-name "USV Test Environment Data" --parent "$MG_TEST"
az account management-group create --name "$MG_MONITOR" --display-name "USV Test Monitoring" --parent "$MG_SHARED"
az account management-group create --name "$MG_SECURITY" --display-name "USV Test Security" --parent "$MG_SHARED"

# Create test resource groups for each management group area
echo -e "${BLUE}Creating test resource groups...${NC}"
az group create --name "${TEST_PREFIX}prod-infra-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}prod-app-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}prod-data-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}test-infra-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}test-app-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}test-data-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}monitoring-rg" --location "$LOCATION"
az group create --name "${TEST_PREFIX}security-rg" --location "$LOCATION"

# Move subscription under the root management group
echo -e "${BLUE}Moving subscription under root management group...${NC}"
az account management-group subscription add --name "$MG_ROOT" --subscription "$CAST_SUBSCRIPTION_ID"

echo -e "${GREEN}Management group structure created successfully!${NC}"
echo -e "${YELLOW}Note: The subscription has been moved to the test root management group.${NC}"
echo -e "${YELLOW}After testing, you should move it back to its original management group.${NC}"

# Show the structure
echo -e "${BLUE}Management Group Structure:${NC}"
az account management-group list --query "[?name=='$MG_ROOT'].{name:name, displayName:displayName, children:children[].{name:name, displayName:displayName}}" -o json
```

## 2. Create RBAC Roles for Testing

Next, we'll create the custom RBAC roles needed for our testing.

```bash
#!/bin/bash
# Script to create custom RBAC roles for testing
# Location: /infra/scripts/create-test-roles.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set variables
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export TEST_PREFIX="USV-TEST-"

# Log in to Azure if not already logged in
if ! az account show > /dev/null 2>&1; then
  echo -e "${BLUE}Logging in to Azure...${NC}"
  az login
fi

# Set subscription
echo -e "${BLUE}Setting subscription to $CAST_SUBSCRIPTION_ID...${NC}"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

# Create NZ MSP Infrastructure Admin role
echo -e "${BLUE}Creating NZ MSP Infrastructure Admin role...${NC}"
cat > nz-infra-role.json << EOF
{
  "Name": "${TEST_PREFIX}NZ-Infrastructure-Admin",
  "Description": "Infrastructure management for NZ MSP (Test)",
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
    "/subscriptions/${CAST_SUBSCRIPTION_ID}"
  ]
}
EOF

az role definition create --role-definition @nz-infra-role.json

# Create US OEM Ground Station Admin role
echo -e "${BLUE}Creating US OEM Ground Station Admin role...${NC}"
cat > us-gs-role.json << EOF
{
  "Name": "${TEST_PREFIX}US-GroundStation-Config",
  "Description": "Temporary access for US OEM to configure ground station (Test)",
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
    "/subscriptions/${CAST_SUBSCRIPTION_ID}"
  ]
}
EOF

az role definition create --role-definition @us-gs-role.json

# Create Australian Data Admin role
echo -e "${BLUE}Creating Australian Data Admin role...${NC}"
cat > au-data-role.json << EOF
{
  "Name": "${TEST_PREFIX}AU-Data-Admin",
  "Description": "Full data access for Australian administrators (Test)",
  "Actions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
    "Microsoft.KeyVault/vaults/secrets/read"
  ],
  "AssignableScopes": [
    "/subscriptions/${CAST_SUBSCRIPTION_ID}"
  ]
}
EOF

az role definition create --role-definition @au-data-role.json

echo -e "${GREEN}Custom RBAC roles created successfully!${NC}"
```

## 3. Create Test Policies 

We'll create policies to enforce our controls:

```bash
#!/bin/bash
# Script to create policies for testing
# Location: /infra/scripts/create-test-policies.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set variables
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export TEST_PREFIX="USV-TEST-"

# Log in to Azure if not already logged in
if ! az account show > /dev/null 2>&1; then
  echo -e "${BLUE}Logging in to Azure...${NC}"
  az login
fi

# Set subscription
echo -e "${BLUE}Setting subscription to $CAST_SUBSCRIPTION_ID...${NC}"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

# Create Australia-only location policy
echo -e "${BLUE}Creating Australia-only location policy...${NC}"
cat > australia-only-policy.json << EOF
{
  "properties": {
    "displayName": "${TEST_PREFIX}Australia-Only-Resources",
    "description": "Ensures all resources are deployed to Australian regions",
    "mode": "All",
    "parameters": {},
    "policyRule": {
      "if": {
        "not": {
          "field": "location",
          "in": ["australiaeast", "australiasoutheast"]
        }
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
EOF

POLICY_ID=$(az policy definition create --name "${TEST_PREFIX}australia-only-policy" --rules australia-only-policy.json --query id -o tsv)

# Create test environment tagging policy
echo -e "${BLUE}Creating test environment tagging policy...${NC}"
cat > test-tagging-policy.json << EOF
{
  "properties": {
    "displayName": "${TEST_PREFIX}Environment-Tagging",
    "description": "Enforces environment tag on all resources",
    "mode": "Indexed",
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "tags.Environment",
        "exists": "false"
      },
      "then": {
        "effect": "modify",
        "details": {
          "operations": [
            {
              "operation": "addOrReplace",
              "field": "tags.Environment",
              "value": "Testing"
            }
          ],
          "roleDefinitionIds": [
            "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
          ]
        }
      }
    }
  }
}
EOF

TAGGING_POLICY_ID=$(az policy definition create --name "${TEST_PREFIX}environment-tagging-policy" --rules test-tagging-policy.json --query id -o tsv)

# Create storage security policy
echo -e "${BLUE}Creating storage security policy...${NC}"
cat > storage-security-policy.json << EOF
{
  "properties": {
    "displayName": "${TEST_PREFIX}Storage-Security",
    "description": "Enforces secure storage configuration",
    "mode": "All",
    "parameters": {},
    "policyRule": {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Storage/storageAccounts"
          },
          {
            "anyOf": [
              {
                "field": "Microsoft.Storage/storageAccounts/allowBlobPublicAccess",
                "equals": "true"
              },
              {
                "field": "Microsoft.Storage/storageAccounts/minimumTlsVersion",
                "notEquals": "TLS1_2"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
EOF

STORAGE_POLICY_ID=$(az policy definition create --name "${TEST_PREFIX}storage-security-policy" --rules storage-security-policy.json --query id -o tsv)

echo -e "${GREEN}Policies created successfully!${NC}"
```

## 4. Lighthouse Delegation Setup

Create the Lighthouse delegation for testing:

```bash
#!/bin/bash
# Script to set up Lighthouse delegation for testing
# Location: /infra/scripts/setup-lighthouse-test.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set variables
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export TEST_PREFIX="USV-TEST-"
export SELWYN_PERSONAL_TENANT_ID="01ad0f0b-0b87-4459-9e8a-cca048e3c04e"
export SELWYN_PERSONAL_USER_ID="4519de0c-bfce-4562-8d23-a35ae529fc55" 

# Log in to Azure if not already logged in
if ! az account show > /dev/null 2>&1; then
  echo -e "${BLUE}Logging in to Azure...${NC}"
  az login
fi

# Set subscription
echo -e "${BLUE}Setting subscription to $CAST_SUBSCRIPTION_ID...${NC}"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

# Create a directory for Lighthouse test resources
mkdir -p lighthouse-test-mg
cd lighthouse-test-mg

# Create Bicep file for Lighthouse delegation
echo -e "${BLUE}Creating Bicep template for Lighthouse delegation...${NC}"
cat > lighthouse-mg-delegation.bicep << EOF
// lighthouse-mg-delegation.bicep
targetScope = 'managementGroup'

// Parameters
@description('Name of the managed service offer')
param mspOfferName string = 'Test Management Group MSP Role'

@description('Description of the managed service offer')
param mspOfferDescription string = 'Test delegation for management group scoping'

@description('Tenant ID of the MSP')
param managedByTenantId string

@description('MSP principal ID')
param mspPrincipalId string

@description('MSP principal display name')
param mspPrincipalDisplayName string = 'Test MSP Administrator'

@description('Role definition ID to assign')
param roleDefinitionId string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Resources
resource registrationDefinition 'Microsoft.ManagedServices/registrationDefinitions@2019-09-01' = {
  name: guid(mspOfferName)
  properties: {
    registrationDefinitionName: mspOfferName
    description: mspOfferDescription
    managedByTenantId: managedByTenantId
    authorizations: [
      {
        principalId: mspPrincipalId
        principalIdDisplayName: mspPrincipalDisplayName
        roleDefinitionId: roleDefinitionId
      }
    ]
  }
}

resource registrationAssignment 'Microsoft.ManagedServices/registrationAssignments@2019-09-01' = {
  name: guid(mspOfferName)
  properties: {
    registrationDefinitionId: registrationDefinition.id
  }
}

// Outputs
output registrationDefinitionId string = registrationDefinition.id
output registrationAssignmentId string = registrationAssignment.id
EOF

# Deploy the Lighthouse delegation to infrastructure management group
echo -e "${BLUE}Deploying Lighthouse delegation to infrastructure management group...${NC}"
az deployment mg create \
  --name "mg-lighthouse-delegation" \
  --location "australiaeast" \
  --management-group-id "${TEST_PREFIX}PROD-INFRA" \
  --template-file "lighthouse-mg-delegation.bicep" \
  --parameters \
    managedByTenantId="$SELWYN_PERSONAL_TENANT_ID" \
    mspPrincipalId="$SELWYN_PERSONAL_USER_ID" \
    mspPrincipalDisplayName="Selwyn Personal (Test MSP)" \
    roleDefinitionId="b24988ac-6180-42a0-ab88-20f7382dd24c"

echo -e "${GREEN}Lighthouse delegation created successfully!${NC}"
```

## 5. Control Validation Tests

Create a validation script to test our controls:

```bash
#!/bin/bash
# Script to validate controls
# Location: /infra/scripts/validate-controls.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set variables
export CAST_SUBSCRIPTION_ID="323c1add-3c6f-439f-adc1-f098fcb43509"
export CAST_TENANT_ID="eba85e58-f7bf-4a54-9a42-5e4a3cc60ad0"
export SELWYN_PERSONAL_TENANT_ID="01ad0f0b-0b87-4459-9e8a-cca048e3c04e"
export TEST_PREFIX="USV-TEST-"

# Test results array
declare -a TEST_RESULTS

# Function to run a test and record result
run_test() {
  local test_name="$1"
  local command="$2"
  local expected_result="$3"
  
  echo -e "${BLUE}Running test: $test_name${NC}"
  echo -e "${YELLOW}Command: $command${NC}"
  
  # Run the command and capture output
  local output
  if output=$(eval "$command" 2>&1); then
    local success=$?
    echo -e "${YELLOW}Output: $output${NC}"
    
    # Check if output matches expected result
    if [[ "$success" -eq 0 && ("$expected_result" == "any" || "$output" == *"$expected_result"*) ]]; then
      echo -e "${GREEN}✅ Test PASSED${NC}"
      TEST_RESULTS+=("✅ PASS: $test_name")
    else
      echo -e "${RED}❌ Test FAILED${NC}"
      TEST_RESULTS+=("❌ FAIL: $test_name")
    fi
  else
    echo -e "${YELLOW}Output: $output${NC}"
    if [[ "$expected_result" == "fail" ]]; then
      echo -e "${GREEN}✅ Test PASSED (Expected failure)${NC}"
      TEST_RESULTS+=("✅ PASS: $test_name (Expected failure)")
    else
      echo -e "${RED}❌ Test FAILED${NC}"
      TEST_RESULTS+=("❌ FAIL: $test_name")
    fi
  fi
  
  echo ""
}

# Log in to CAST tenant
echo -e "${BLUE}Logging in to CAST tenant...${NC}"
az login --tenant "$CAST_TENANT_ID"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

# Test 1: Verify management group structure
run_test "Management Group Structure" \
  "az account management-group show --name \"${TEST_PREFIX}ROOT\" --expand --query name -o tsv" \
  "${TEST_PREFIX}ROOT"

# Test 2: Test Australia-only location policy
run_test "Australia-only Location Policy" \
  "az group create --name \"${TEST_PREFIX}eu-test-rg\" --location \"westeurope\"" \
  "fail"

# Test 3: Create a storage account with public access (should fail)
run_test "Storage Security Policy" \
  "az storage account create --name \"${TEST_PREFIX}pubstorage\" --resource-group \"${TEST_PREFIX}test-infra-rg\" --location \"australiaeast\" --allow-blob-public-access true --sku Standard_LRS" \
  "fail"

# Test 4: Create a compliant storage account (should succeed)
run_test "Compliant Storage Account" \
  "az storage account create --name \"${TEST_PREFIX}privstorage\" --resource-group \"${TEST_PREFIX}test-infra-rg\" --location \"australiaeast\" --allow-blob-public-access false --min-tls-version TLS1_2 --sku Standard_LRS" \
  "any"

# Test 5: Test tag enforcement policy (tag should be automatically added)
run_test "Tag Enforcement Policy" \
  "az vm create --name \"${TEST_PREFIX}testvm\" --resource-group \"${TEST_PREFIX}test-infra-rg\" --image UbuntuLTS --admin-username azureuser --generate-ssh-keys --no-wait && sleep 30 && az vm show --name \"${TEST_PREFIX}testvm\" --resource-group \"${TEST_PREFIX}test-infra-rg\" --query \"tags.Environment\" -o tsv" \
  "Testing"

# Now test the Lighthouse delegation
echo -e "${BLUE}Now testing Lighthouse delegation from Personal tenant...${NC}"

# Log in to personal tenant
echo -e "${BLUE}Logging in to Personal tenant...${NC}"
az login --tenant "$SELWYN_PERSONAL_TENANT_ID"

# Test 6: Verify Lighthouse delegation
run_test "Lighthouse Delegation" \
  "az resource list --query \"[?managedBy!=null]\"" \
  "any"

# Test 7: Verify access to infrastructure resources
run_test "Infra Resource Access via Lighthouse" \
  "az vm list --query \"[].name\" -o tsv" \
  "any"

# Test 8: Verify no access to data resources
run_test "No Data Access via Lighthouse" \
  "az storage account keys list --account-name \"${TEST_PREFIX}privstorage\" --resource-group \"${TEST_PREFIX}test-data-rg\"" \
  "fail"

# Display test results summary
echo -e "${BLUE}==== Test Results Summary ====${NC}"
for result in "${TEST_RESULTS[@]}"; do
  echo -e "${result}"
done

# Count passed and failed tests
passed_count=$(grep -c "PASS" <<< "${TEST_RESULTS[@]}")
failed_count=$(grep -c "FAIL" <<< "${TEST_RESULTS[@]}")
total_count=${#TEST_RESULTS[@]}

echo -e "${BLUE}==== Summary ====${NC}"
echo -e "Total tests: ${total_count}"
echo -e "${GREEN}Passed: ${passed_count}${NC}"
echo -e "${RED}Failed: ${failed_count}${NC}"

# Clean up test resources (optional)
read -p "Do you want to clean up test resources? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Cleaning up test resources...${NC}"
  
  # Log back into CAST tenant
  az login --tenant "$CAST_TENANT_ID"
  az account set --subscription "$CAST_SUBSCRIPTION_ID"
  
  # Delete test resource groups
  echo -e "${BLUE}Deleting test resource groups...${NC}"
  az group delete --name "${TEST_PREFIX}prod-infra-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}prod-app-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}prod-data-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}test-infra-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}test-app-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}test-data-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}monitoring-rg" --yes --no-wait
  az group delete --name "${TEST_PREFIX}security-rg" --yes --no-wait
  
  # Delete test policies
  echo -e "${BLUE}Deleting test policies...${NC}"
  az policy definition delete --name "${TEST_PREFIX}australia-only-policy"
  az policy definition delete --name "${TEST_PREFIX}environment-tagging-policy"
  az policy definition delete --name "${TEST_PREFIX}storage-security-policy"
  
  # Delete test roles
  echo -e "${BLUE}Deleting test roles...${NC}"
  az role definition delete --name "${TEST_PREFIX}NZ-Infrastructure-Admin"
  az role definition delete --name "${TEST_PREFIX}US-GroundStation-Config"
  az role definition delete --name "${TEST_PREFIX}AU-Data-Admin"
  
  # Return subscription to original management group
  echo -e "${BLUE}Moving subscription back to original management group...${NC}"
  az account management-group subscription remove --name "${TEST_PREFIX}ROOT" --subscription "$CAST_SUBSCRIPTION_ID"
  
  echo -e "${GREEN}Cleanup completed!${NC}"
else
  echo -e "${YELLOW}Skipping cleanup. You can manually clean up resources later.${NC}"
fi
```

## 6. Master Test Script

Create a master script to run all tests:

```bash
#!/bin/bash
# Master script to run all tests
# Location: /infra/scripts/run-all-tests.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== USV Management Group Structure Testing ====${NC}"
echo -e "${BLUE}This script will run all tests to validate the management group structure and controls${NC}"

# Make scripts executable
chmod +x ./create-mg-structure.sh
chmod +x ./create-test-roles.sh
chmod +x ./create-test-policies.sh
chmod +x ./setup-lighthouse-test.sh
chmod +x ./validate-controls.sh

# Run each script in sequence
echo -e "${BLUE}=== Step 1: Creating Management Group Structure ===${NC}"
./create-mg-structure.sh

echo -e "${BLUE}=== Step 2: Creating Test RBAC Roles ===${NC}"
./create-test-roles.sh

echo -e "${BLUE}=== Step 3: Creating Test Policies ===${NC}"
./create-test-policies.sh

echo -e "${BLUE}=== Step 4: Setting Up Lighthouse Delegation ===${NC}"
./setup-lighthouse-test.sh

echo -e "${BLUE}=== Step 5: Validating Controls ===${NC}"
./validate-controls.sh
```

## 7. Documentation for Test Execution

Create a README.md file for the testing process:

```markdown
# Management Group Structure Testing

This directory contains scripts to test the management group structure and security controls in a safe, isolated environment within the CAST tenant.

## Prerequisites

- Azure CLI installed and configured
- Access to CAST tenant with Contributor permissions
- Personal tenant configured for Lighthouse testing

## Testing Process

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/elysium-usv.git
   cd elysium-usv/infra/scripts
   ```

2. Run the master test script:
   ```bash
   chmod +x run-all-tests.sh
   ./run-all-tests.sh
   ```

3. Alternatively, run each script individually:
   ```bash
   # Step 1: Create management group structure
   ./create-mg-structure.sh
   
   # Step 2: Create RBAC roles
   ./create-test-roles.sh
   
   # Step 3: Create policies
   ./create-test-policies.sh
   
   # Step 4: Set up Lighthouse delegation
   ./setup-lighthouse-test.sh
   
   # Step 5: Validate controls
   ./validate-controls.sh
   ```

## What Gets Tested

The testing suite validates:

1. Management group hierarchy creation
2. Resource group organization
3. Custom RBAC role implementation
4. Geographic restriction policies (Australia-only)
5. Storage security policies
6. Tag enforcement
7. Lighthouse delegation at management group level
8. Access controls between different stakeholders

## Test Results

After running the validation script, you'll see a summary of all test results. This helps identify any controls that are not functioning as expected.

## Cleanup

The validation script includes an option to clean up all test resources. If you choose not to clean up during validation, you can run cleanup manually:

```bash
./cleanup-test-resources.sh
```

## Troubleshooting

- **Management Group Creation Issues**: Ensure you have the right permissions at the tenant level
- **Policy Assignment Failures**: Check if you have Owner role at subscription level
- **Lighthouse Delegation Issues**: Verify that your personal tenant ID and principal ID are correct
- **VM Creation Timeouts**: Some tests involving VM creation might time out in resource-constrained environments
```

## 8. Directory Structure

Your test directory structure should look like this:

```
/infra/
  /scripts/
    create-mg-structure.sh
    create-test-roles.sh
    create-test-policies.sh
    setup-lighthouse-test.sh
    validate-controls.sh
    run-all-tests.sh
    cleanup-test-resources.sh
  /bicep/
    lighthouse-mg-delegation.bicep
  /README.md
  /mg-structure-validation-plan.md
```

## 9. Expected Results

After running the tests, you should see results that validate:

1. Management group hierarchy is properly created
2. Policies enforce geographic restrictions to Australia
3. Storage security policies are enforced
4. Tags are automatically applied
5. Lighthouse delegation allows NZ MSP (personal tenant) to access only infrastructure resources
6. Data access is blocked for NZ MSP as expected

This comprehensive testing plan allows you to validate all aspects of the management group structure and security controls in a safe, isolated environment before implementing them in production.