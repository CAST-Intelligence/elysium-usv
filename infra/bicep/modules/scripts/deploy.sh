#!/bin/bash
# Deployment script for Elysium USV Bicep modules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default variables
DEPLOYMENT_NAME="elysium-usv-$(date +%Y%m%d%H%M%S)"
LOCATION="australiaeast"
MODE="test"
PREFIX="USV-TEST-"
WITH_WHATIF=true
BACKUP=true
TENANT_ID=""
NZ_MSP_TENANT_ID="01ad0f0b-0b87-4459-9e8a-cca048e3c04e"  # Default to Selwyn's tenant for testing
NZ_MSP_INFRA_PRINCIPAL_ID=""
NZ_MSP_APP_PRINCIPAL_ID=""

# Function to display usage
usage() {
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  -n, --name NAME          Deployment name (default: elysium-usv-timestamp)"
  echo -e "  -l, --location LOCATION  Azure region for deployment (default: australiaeast)"
  echo -e "  -m, --mode MODE          Deployment mode: prod or test (default: test)"
  echo -e "  -p, --prefix PREFIX      Resource name prefix (default: USV-TEST-)"
  echo -e "  -t, --tenant TENANT_ID   Azure tenant ID"
  echo -e "  --msp-tenant MSP_ID      NZ MSP tenant ID"
  echo -e "  --msp-infra MSP_ID       NZ MSP infrastructure team principal ID"
  echo -e "  --msp-app MSP_ID         NZ MSP application team principal ID"
  echo -e "  --no-whatif              Skip what-if analysis"
  echo -e "  --no-backup              Skip backup of current state"
  echo -e "  -h, --help               Show this help message"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--name)
      DEPLOYMENT_NAME="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
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
    --msp-infra)
      NZ_MSP_INFRA_PRINCIPAL_ID="$2"
      shift 2
      ;;
    --msp-app)
      NZ_MSP_APP_PRINCIPAL_ID="$2"
      shift 2
      ;;
    --no-whatif)
      WITH_WHATIF=false
      shift
      ;;
    --no-backup)
      BACKUP=false
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

# Validate parameters
if [[ "$MODE" != "prod" && "$MODE" != "test" ]]; then
  echo -e "${RED}Error: Mode must be 'prod' or 'test'${NC}"
  exit 1
fi

if [[ "$MODE" == "prod" && -z "$NZ_MSP_INFRA_PRINCIPAL_ID" ]]; then
  echo -e "${YELLOW}Warning: NZ MSP infrastructure principal ID not provided for production deployment${NC}"
  read -p "Do you want to continue without MSP delegation? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Please provide the NZ MSP principal IDs using --msp-infra and --msp-app parameters${NC}"
    exit 1
  fi
fi

# Directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." &>/dev/null && pwd)"
BICEP_DIR="$PROJECT_ROOT/infra/bicep"
BACKUP_DIR="$PROJECT_ROOT/infra/backups"
MODULES_DIR="$BICEP_DIR/modules"

# Create backup directory if it doesn't exist
if [[ "$BACKUP" == true ]]; then
  mkdir -p "$BACKUP_DIR"
fi

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

# Backup current state if enabled
if [[ "$BACKUP" == true ]]; then
  BACKUP_FILE="$BACKUP_DIR/mg-backup-$(date +%Y%m%d%H%M%S).json"
  echo -e "${BLUE}Creating backup of current management group structure...${NC}"
  az account management-group list > "$BACKUP_FILE"
  echo -e "${GREEN}Backup created at: $BACKUP_FILE${NC}"
fi

# Function to deploy a module at tenant scope
deploy_tenant_module() {
  local module_name="$1"
  local template_file="$2"
  local parameters="$3"
  
  echo -e "${BLUE}Deploying $module_name at tenant scope...${NC}"
  
  if [[ "$WITH_WHATIF" == true ]]; then
    echo -e "${YELLOW}Running what-if analysis for $module_name...${NC}"
    az deployment tenant what-if \
      --name "${DEPLOYMENT_NAME}-${module_name}" \
      --location "$LOCATION" \
      --template-file "$template_file" \
      $parameters
    
    read -p "Continue with $module_name deployment? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}$module_name deployment skipped by user${NC}"
      return 1
    fi
  fi
  
  az deployment tenant create \
    --name "${DEPLOYMENT_NAME}-${module_name}" \
    --location "$LOCATION" \
    --template-file "$template_file" \
    $parameters
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}$module_name deployment completed successfully!${NC}"
    return 0
  else
    echo -e "${RED}$module_name deployment failed!${NC}"
    return 1
  fi
}

# Function to deploy a module at management group scope
deploy_mg_module() {
  local module_name="$1"
  local template_file="$2"
  local management_group="$3"
  local parameters="$4"
  
  echo -e "${BLUE}Deploying $module_name at management group scope ($management_group)...${NC}"
  
  if [[ "$WITH_WHATIF" == true ]]; then
    echo -e "${YELLOW}Running what-if analysis for $module_name...${NC}"
    az deployment mg what-if \
      --name "${DEPLOYMENT_NAME}-${module_name}" \
      --location "$LOCATION" \
      --management-group-id "$management_group" \
      --template-file "$template_file" \
      $parameters
    
    read -p "Continue with $module_name deployment? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}$module_name deployment skipped by user${NC}"
      return 1
    fi
  fi
  
  az deployment mg create \
    --name "${DEPLOYMENT_NAME}-${module_name}" \
    --location "$LOCATION" \
    --management-group-id "$management_group" \
    --template-file "$template_file" \
    $parameters
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}$module_name deployment completed successfully!${NC}"
    return 0
  else
    echo -e "${RED}$module_name deployment failed!${NC}"
    return 1
  fi
}

# Deploy the config at tenant scope first
echo -e "${BLUE}Getting deployment configuration...${NC}"
az deployment tenant create \
  --name "${DEPLOYMENT_NAME}-config" \
  --location "$LOCATION" \
  --template-file "$BICEP_DIR/main.bicep" \
  --parameters prefix="$PREFIX" deploymentMode="$MODE" \
  --parameters nzMspTenantId="$NZ_MSP_TENANT_ID" \
  --parameters nzMspInfraPrincipalId="$NZ_MSP_INFRA_PRINCIPAL_ID" \
  --parameters nzMspAppPrincipalId="$NZ_MSP_APP_PRINCIPAL_ID" \
  --query properties.outputs.config.value -o json > "$BACKUP_DIR/config.json"

# Step 1: Deploy management groups at tenant scope
deploy_tenant_module "management-groups" \
  "$MODULES_DIR/management-groups.bicep" \
  "--parameters mgPrefix='$PREFIX' deploymentMode='$MODE'"

# Verify management groups were created
ROOT_MG="${PREFIX}ROOT"
if ! az account management-group show --name "$ROOT_MG" &>/dev/null; then
  echo -e "${RED}Error: Root management group $ROOT_MG not found. Deployment failed.${NC}"
  exit 1
fi

# Step 2: Deploy RBAC roles at tenant scope
deploy_tenant_module "rbac-roles" \
  "$MODULES_DIR/rbac-roles.bicep" \
  "--parameters rolePrefix='$PREFIX' deploymentMode='$MODE' managementGroupIds=@$BACKUP_DIR/mg-names.json"

# Step 3: Deploy policies at appropriate management group scopes
if [[ "$MODE" == "prod" ]]; then
  MG_TARGET="${PREFIX}PROD"
else
  MG_TARGET="${PREFIX}TEST"
fi

deploy_mg_module "policies" \
  "$MODULES_DIR/policies.bicep" \
  "$MG_TARGET" \
  "--parameters policyPrefix='$PREFIX' deploymentMode='$MODE' managementGroupIds=@$BACKUP_DIR/mg-ids.json"

# Step 4: Deploy Lighthouse at resource group scope
# Create a resource group for lighthouse if it doesn't exist
LIGHTHOUSE_RG="${PREFIX}lighthouse-rg"
az group create --name "$LIGHTHOUSE_RG" --location "$LOCATION" --tags Environment="Management" Purpose="Lighthouse"

az deployment group create \
  --name "${DEPLOYMENT_NAME}-lighthouse" \
  --resource-group "$LIGHTHOUSE_RG" \
  --template-file "$MODULES_DIR/lighthouse.bicep" \
  --parameters lighthousePrefix="$PREFIX" \
  --parameters deploymentMode="$MODE" \
  --parameters managementGroupIds=@$BACKUP_DIR/mg-ids.json \
  --parameters roleIds=@$BACKUP_DIR/role-ids.json \
  --parameters nzMspTenantId="$NZ_MSP_TENANT_ID" \
  --parameters nzMspInfraPrincipalId="$NZ_MSP_INFRA_PRINCIPAL_ID" \
  --parameters nzMspAppPrincipalId="$NZ_MSP_APP_PRINCIPAL_ID"

# Move subscription to appropriate management group
echo -e "${BLUE}Moving subscription $SUBSCRIPTION_ID to management group $MG_TARGET...${NC}"
az account management-group subscription add \
  --name "$MG_TARGET" \
  --subscription "$SUBSCRIPTION_ID"

echo -e "${GREEN}Subscription moved successfully!${NC}"
echo -e "${BLUE}Deployment summary:${NC}"
echo -e "  - Mode: $MODE"
echo -e "  - Prefix: $PREFIX"
echo -e "  - Location: $LOCATION"
echo -e "  - Deployment name: $DEPLOYMENT_NAME"
echo -e "  - Subscription: $SUBSCRIPTION_ID"
echo -e "${YELLOW}Next steps: Run the validation script to verify your deployment${NC}"