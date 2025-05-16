#!/bin/bash
# Validation script for Elysium USV Bicep deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default variables
PREFIX="USV-TEST-"
TENANT_ID=""
NZ_MSP_TENANT_ID=""
CLEANUP=false

# Test results array
declare -a TEST_RESULTS

# Function to display usage
usage() {
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  -p, --prefix PREFIX      Resource name prefix (default: USV-TEST-)"
  echo -e "  -t, --tenant TENANT_ID   Azure tenant ID"
  echo -e "  --msp-tenant MSP_ID      NZ MSP tenant ID for Lighthouse tests"
  echo -e "  --cleanup                Clean up test resources after validation"
  echo -e "  -h, --help               Show this help message"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -p|--prefix)
      PREFIX="$2"
      shift 2
      ;;
    -t|--tenant)
      TENANT_ID="$2"
      shift 2
      ;;
    --msp-tenant)
      NZ_MSP_TENANT_ID="$2"
      shift 2
      ;;
    --cleanup)
      CLEANUP=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
done

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

# Log in to Azure if tenant ID is provided
if [[ -n "$TENANT_ID" ]]; then
  echo -e "${BLUE}Logging in to Azure tenant $TENANT_ID...${NC}"
  az login --tenant "$TENANT_ID"
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo -e "${RED}Error: Could not determine Azure subscription ID. Please log in to Azure first.${NC}"
  exit 1
fi

echo -e "${BLUE}Using subscription: $SUBSCRIPTION_ID${NC}"

# Test 1: Verify management group structure
run_test "Management Group Structure" \
  "az account management-group show --name \"${PREFIX}ROOT\" --expand --query name -o tsv" \
  "${PREFIX}ROOT"

# Test 2: Verify level 1 management groups
run_test "Level 1 Management Groups" \
  "az account management-group show --name \"${PREFIX}ELYSIUM\" --expand --query name -o tsv" \
  "${PREFIX}ELYSIUM"

# Test 3: Verify level 2 management groups
run_test "Level 2 Management Groups - Production" \
  "az account management-group show --name \"${PREFIX}PROD\" --expand --query name -o tsv" \
  "${PREFIX}PROD"

run_test "Level 2 Management Groups - Test" \
  "az account management-group show --name \"${PREFIX}TEST\" --expand --query name -o tsv" \
  "${PREFIX}TEST"

run_test "Level 2 Management Groups - Shared" \
  "az account management-group show --name \"${PREFIX}SHARED\" --expand --query name -o tsv" \
  "${PREFIX}SHARED"

# Test 4: Verify custom RBAC roles
run_test "NZ Infrastructure Admin Role" \
  "az role definition list --custom-role-only true --query \"[?roleName=='${PREFIX}USV-NZ-Infrastructure-Admin'].roleName\" -o tsv" \
  "${PREFIX}USV-NZ-Infrastructure-Admin"

run_test "US Ground Station Config Role" \
  "az role definition list --custom-role-only true --query \"[?roleName=='${PREFIX}USV-US-GroundStation-Config'].roleName\" -o tsv" \
  "${PREFIX}USV-US-GroundStation-Config"

run_test "AU Data Admin Role" \
  "az role definition list --custom-role-only true --query \"[?roleName=='${PREFIX}USV-AU-Data-Admin'].roleName\" -o tsv" \
  "${PREFIX}USV-AU-Data-Admin"

# Test 5: Verify policy definitions
run_test "Australia-only Policy" \
  "az policy definition list --query \"[?name=='${PREFIX}prod-data-australia-only'].name\" -o tsv" \
  "${PREFIX}prod-data-australia-only"

# Test 6: Create a test resource group in non-Australian region (should fail if policy is working)
run_test "Australia-only Location Policy Enforcement" \
  "az group create --name \"${PREFIX}eu-test-rg\" --location \"westeurope\"" \
  "fail"

# Test 7: Create a resource group in Australia (should succeed)
run_test "Australia Location Allowed" \
  "az group create --name \"${PREFIX}au-test-rg\" --location \"australiaeast\"" \
  "any"

# Only run Lighthouse tests if MSP tenant ID is provided
if [[ -n "$NZ_MSP_TENANT_ID" ]]; then
  echo -e "${BLUE}Testing Lighthouse delegation...${NC}"
  
  # Test 8: Verify Lighthouse registration definitions
  run_test "Lighthouse Registration Definitions" \
    "az managedservices definition list --query \"[?contains(properties.registrationDefinitionName, '${PREFIX}')].properties.registrationDefinitionName\" -o tsv" \
    "${PREFIX}"
  
  # Log in to MSP tenant to verify delegation
  echo -e "${BLUE}Logging in to MSP tenant $NZ_MSP_TENANT_ID to verify delegation...${NC}"
  az login --tenant "$NZ_MSP_TENANT_ID"
  
  # Test 9: Verify Lighthouse delegation from MSP side
  run_test "Lighthouse Delegation from MSP Side" \
    "az managedservices assignment list --query \"[].name\" -o tsv" \
    "any"
  
  # Log back to main tenant
  echo -e "${BLUE}Logging back to main tenant...${NC}"
  az login --tenant "$TENANT_ID"
fi

# Create a storage account to test tagging policy
TEST_STORAGE_NAME="${PREFIX}teststorage$(date +%s | cut -c1-6)"
TEST_RESOURCE_GROUP="${PREFIX}au-test-rg"

run_test "Create Compliant Storage Account" \
  "az storage account create --name \"${TEST_STORAGE_NAME}\" --resource-group \"${TEST_RESOURCE_GROUP}\" --location \"australiaeast\" --allow-blob-public-access false --min-tls-version TLS1_2 --sku Standard_LRS" \
  "any"

# Test automatic tagging
run_test "Automatic Environment Tagging" \
  "az resource show --resource-group \"${TEST_RESOURCE_GROUP}\" --name \"${TEST_STORAGE_NAME}\" --resource-type \"Microsoft.Storage/storageAccounts\" --query \"tags.Environment\" -o tsv" \
  "Testing"

# Display test results summary
echo -e "${BLUE}==== Test Results Summary ====${NC}"
for result in "${TEST_RESULTS[@]}"; do
  echo -e "${result}"
done

# Count passed and failed tests
passed_count=$(echo "${TEST_RESULTS[@]}" | grep -o "PASS" | wc -l)
failed_count=$(echo "${TEST_RESULTS[@]}" | grep -o "FAIL" | wc -l)
total_count=${#TEST_RESULTS[@]}

echo -e "${BLUE}==== Summary ====${NC}"
echo -e "Total tests: ${total_count}"
echo -e "${GREEN}Passed: ${passed_count}${NC}"
echo -e "${RED}Failed: ${failed_count}${NC}"

# Clean up test resources if cleanup flag is set
if [[ "$CLEANUP" == true ]]; then
  echo -e "${BLUE}Cleaning up test resources...${NC}"
  
  # Delete test resource groups
  echo -e "${BLUE}Deleting test resource groups...${NC}"
  az group delete --name "${PREFIX}au-test-rg" --yes --no-wait
  
  # Return subscription to original management group
  echo -e "${BLUE}Moving subscription back to original management group...${NC}"
  az account management-group subscription remove --name "${PREFIX}TEST" --subscription "$SUBSCRIPTION_ID"
  az account management-group subscription remove --name "${PREFIX}PROD" --subscription "$SUBSCRIPTION_ID"
  
  echo -e "${GREEN}Cleanup completed!${NC}"
else
  echo -e "${YELLOW}Skipping cleanup. Use --cleanup flag to clean up test resources.${NC}"
  echo -e "${YELLOW}You can manually clean up resources later.${NC}"
fi

# Final result
if [[ "$failed_count" -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed. Please check the results.${NC}"
  exit 1
fi