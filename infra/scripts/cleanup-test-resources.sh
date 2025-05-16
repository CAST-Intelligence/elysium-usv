#!/bin/bash
# Script to clean up all test resources

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
export TEST_PREFIX="USV-TEST-"

# Log in to Azure if not already logged in
if ! az account show > /dev/null 2>&1; then
  echo -e "${BLUE}Logging in to Azure...${NC}"
  az login --tenant "$CAST_TENANT_ID"
fi

# Set subscription
echo -e "${BLUE}Setting subscription to $CAST_SUBSCRIPTION_ID...${NC}"
az account set --subscription "$CAST_SUBSCRIPTION_ID"

echo -e "${BLUE}Starting cleanup of all test resources...${NC}"

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
az group delete --name "${TEST_PREFIX}eu-test-rg" --yes --no-wait 2>/dev/null || true

# Delete test policies
echo -e "${BLUE}Deleting test policy assignments...${NC}"
az policy assignment delete --name "${TEST_PREFIX}australia-only-assignment" 2>/dev/null || true
az policy assignment delete --name "${TEST_PREFIX}environment-tagging-assignment" 2>/dev/null || true
az policy assignment delete --name "${TEST_PREFIX}storage-security-assignment" 2>/dev/null || true

echo -e "${BLUE}Deleting test policy definitions...${NC}"
az policy definition delete --name "${TEST_PREFIX}australia-only-policy" 2>/dev/null || true
az policy definition delete --name "${TEST_PREFIX}environment-tagging-policy" 2>/dev/null || true
az policy definition delete --name "${TEST_PREFIX}storage-security-policy" 2>/dev/null || true

# Delete test roles
echo -e "${BLUE}Deleting test role definitions...${NC}"
az role definition delete --name "${TEST_PREFIX}NZ-Infrastructure-Admin" 2>/dev/null || true
az role definition delete --name "${TEST_PREFIX}US-GroundStation-Config" 2>/dev/null || true
az role definition delete --name "${TEST_PREFIX}AU-Data-Admin" 2>/dev/null || true

# Return subscription to original management group
echo -e "${BLUE}Moving subscription back to original management group...${NC}"
az account management-group subscription remove --name "${TEST_PREFIX}ROOT" --subscription "$CAST_SUBSCRIPTION_ID" 2>/dev/null || true

# Delete Lighthouse delegations
echo -e "${BLUE}Deleting Lighthouse delegations...${NC}"
for assignmentId in $(az managedservices assignment list --query "[?contains(properties.registrationDefinitionId, '${TEST_PREFIX}')].name" -o tsv 2>/dev/null || echo ""); do
  if [ -n "$assignmentId" ]; then
    az managedservices assignment delete --assignment "$assignmentId"
  fi
done

for definitionId in $(az managedservices definition list --query "[?contains(properties.registrationDefinitionName, '${TEST_PREFIX}')].name" -o tsv 2>/dev/null || echo ""); do
  if [ -n "$definitionId" ]; then
    az managedservices definition delete --definition "$definitionId"
  fi
done

# Delete management groups (need to do this in reverse order)
echo -e "${BLUE}Deleting management groups...${NC}"
# Level 3
az account management-group delete --name "${TEST_PREFIX}PROD-INFRA" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}PROD-APP" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}PROD-DATA" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}TEST-INFRA" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}TEST-APP" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}TEST-DATA" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}MONITOR" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}SECURITY" 2>/dev/null || true

# Level 2
az account management-group delete --name "${TEST_PREFIX}PROD" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}TEST" 2>/dev/null || true
az account management-group delete --name "${TEST_PREFIX}SHARED" 2>/dev/null || true

# Level 1
az account management-group delete --name "${TEST_PREFIX}ELYSIUM" 2>/dev/null || true

# Root
az account management-group delete --name "${TEST_PREFIX}ROOT" 2>/dev/null || true

echo -e "${GREEN}Cleanup completed!${NC}"
echo -e "${YELLOW}Note: Some resources might still be in the process of deletion.${NC}"
echo -e "${YELLOW}If you get errors when running the tests again, wait a few minutes and try again.${NC}"