#!/bin/bash
# Script to create management group structure for testing in CAST tenant

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