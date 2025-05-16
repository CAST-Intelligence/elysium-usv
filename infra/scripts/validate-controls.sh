#!/bin/bash
# Script to validate controls

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
  az policy assignment delete --name "${TEST_PREFIX}australia-only-assignment"
  az policy assignment delete --name "${TEST_PREFIX}environment-tagging-assignment"
  az policy assignment delete --name "${TEST_PREFIX}storage-security-assignment"
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