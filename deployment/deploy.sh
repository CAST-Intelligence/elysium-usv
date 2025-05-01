#!/bin/bash
set -e

# Parse command line arguments
ENVIRONMENT="dev"
LOCATION="australiaeast"
RESOURCE_GROUP="elysium-usv"
DEPLOYMENT_NAME="elysium-usv-deployment"
AUTO_CONFIRM=false

print_usage() {
  echo "Usage: $0 -g <resource_group> [-e <environment>] [-l <location>] [-n <deployment_name>] [-y]"
  echo "  -g  Resource group name (required)"
  echo "  -e  Environment (dev, test, prod) - default: dev"
  echo "  -l  Azure region location - default: australiaeast"
  echo "  -n  Deployment name - default: elysium-usv-deployment"
  echo "  -y  Auto-confirm all prompts (no interactive confirmation)"
  exit 1
}

while getopts ":g:e:l:n:y" option; do
  case $option in
    g)
      RESOURCE_GROUP=$OPTARG
      ;;
    e)
      ENVIRONMENT=$OPTARG
      ;;
    l)
      LOCATION=$OPTARG
      ;;
    n)
      DEPLOYMENT_NAME=$OPTARG
      ;;
    y)
      AUTO_CONFIRM=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      print_usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      print_usage
      ;;
  esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
  echo "Error: Resource group is required"
  print_usage
fi

# Print deployment information
echo "Deploying Elysium USV Data Pipeline"
echo "--------------------------------"
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "--------------------------------"

# Confirm deployment
if [ "$AUTO_CONFIRM" != "true" ]; then
  read -p "Continue with deployment? (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ]; then
    echo "Deployment cancelled"
    exit 0
  fi
else
  echo "Auto-confirming deployment"
fi

# Check if resource group exists, create if not
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")
if [ "$RG_EXISTS" = "false" ]; then
  echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
  echo "Resource group $RESOURCE_GROUP already exists"
fi

# Check for soft-deleted Key Vault
KEY_VAULT_NAME="elysium-usv-$ENVIRONMENT-kv"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Checking for soft-deleted Key Vault: $KEY_VAULT_NAME"
DELETED_VAULT=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json)
if [ "$(echo $DELETED_VAULT | jq 'length')" -ne "0" ]; then
  echo "WARNING: A soft-deleted Key Vault with name '$KEY_VAULT_NAME' was found."
  echo "You need to purge it before continuing with deployment."
  echo ""
  echo "Run the following command to purge the Key Vault:"
  echo "  $SCRIPT_DIR/purge-keyvault.sh -e $ENVIRONMENT"
  exit 1
fi

# Deploy ARM template
echo "Deploying infrastructure..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$SCRIPT_DIR/azure-deployment.json" \
  --parameters environment="$ENVIRONMENT" location="$LOCATION" \
  --output json)

# Extract outputs
FUNCTION_APP_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.functionAppName.value')
STORAGE_ACCOUNT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.storageAccountName.value')
KEY_VAULT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.keyVaultName.value')
LOG_ANALYTICS_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.logAnalyticsWorkspaceName.value')
APP_INSIGHTS_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.applicationInsightsName.value')

echo "Infrastructure deployment completed"
echo "--------------------------------"
echo "Function App: $FUNCTION_APP_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Log Analytics Workspace: $LOG_ANALYTICS_NAME"
echo "Application Insights: $APP_INSIGHTS_NAME"
echo "--------------------------------"

# Calculate root directory
ROOT_DIR=$(dirname "$(dirname "$0")")

# Deploy Logic Apps
echo "Deploying Logic Apps..."

# First check if the Logic App templates exist
LOGIC_APP_DIR="$ROOT_DIR/src/logic-apps"
# Create directory if it doesn't exist
mkdir -p "$LOGIC_APP_DIR"
ls -la "$ROOT_DIR"/src

# Check if any Logic App templates exist
SKIP_LOGIC_APPS=true
if [ -f "$LOGIC_APP_DIR/master-orchestration-workflow.json" ] || 
   [ -f "$LOGIC_APP_DIR/s3-transfer-workflow.json" ] || 
   [ -f "$LOGIC_APP_DIR/cleanup-workflow.json" ]; then
   # At least one template exists, so we should attempt deployment
   SKIP_LOGIC_APPS=false
else
  echo "Warning: One or more Logic App template files are missing."
  echo "This is expected if this is the first run and you're setting up infrastructure."
  echo "The Logic App deployments will be skipped."
  echo "You can run the deployment again later once the template files are in place."
  SKIP_LOGIC_APPS=true
  echo "Logic Apps deployment skipped"
  echo "--------------------------------"
fi

if [ "$SKIP_LOGIC_APPS" = "false" ]; then
  echo "Debug: Logic Apps directory contents:"
  ls -la "$LOGIC_APP_DIR"
  
  echo "1. Deploying Master Orchestration Logic App..."
  if [ -f "$LOGIC_APP_DIR/master-orchestration-workflow.json" ]; then
    echo "File exists: $LOGIC_APP_DIR/master-orchestration-workflow.json"
    echo "File size: $(stat -f "%z" "$LOGIC_APP_DIR/master-orchestration-workflow.json") bytes"
    
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --name "master-orchestrator-deployment" \
      --template-file "$LOGIC_APP_DIR/master-orchestration-workflow.json" \
      --parameters workflows_name="$ENVIRONMENT-usv-master-orch" \
                  location="$LOCATION" \
                  storageName="$STORAGE_ACCOUNT_NAME" \
                  functionAppName="$FUNCTION_APP_NAME"
  else
    echo "ERROR: File does not exist: $LOGIC_APP_DIR/master-orchestration-workflow.json"
  fi
  
  echo "2. Deploying S3 Transfer Logic App..."
  if [ -f "$LOGIC_APP_DIR/s3-transfer-workflow.json" ]; then
    echo "File exists: $LOGIC_APP_DIR/s3-transfer-workflow.json"
    
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --name "s3-transfer-deployment" \
      --template-file "$LOGIC_APP_DIR/s3-transfer-workflow.json" \
      --parameters workflows_name="$ENVIRONMENT-usv-s3-transfer" \
                  location="$LOCATION" \
                  storageName="$STORAGE_ACCOUNT_NAME" \
                  functionAppName="$FUNCTION_APP_NAME"
  else
    echo "ERROR: File does not exist: $LOGIC_APP_DIR/s3-transfer-workflow.json"
  fi
  
  echo "3. Deploying Cleanup Logic App..."
  if [ -f "$LOGIC_APP_DIR/cleanup-workflow.json" ]; then
    echo "File exists: $LOGIC_APP_DIR/cleanup-workflow.json"
    
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --name "cleanup-deployment" \
      --template-file "$LOGIC_APP_DIR/cleanup-workflow.json" \
      --parameters workflows_name="$ENVIRONMENT-usv-cleanup" \
                  location="$LOCATION" \
                  storageName="$STORAGE_ACCOUNT_NAME" \
                  functionAppName="$FUNCTION_APP_NAME" \
                  retentionDays=7
  else
    echo "ERROR: File does not exist: $LOGIC_APP_DIR/cleanup-workflow.json"
  fi
  
  echo "Logic Apps deployment completed"
fi

# Deploy Function App code
echo "Deploying Azure Functions..."

# Create a ZIP deployment package
echo "Creating deployment package..."
TEMP_DIR=$(mktemp -d)
FUNCTIONS_DIR="$ROOT_DIR/src/functions"
ZIP_FILE="$TEMP_DIR/functions.zip"

# Copy function code to temp directory
mkdir -p "$TEMP_DIR/functions"
cp -R "$FUNCTIONS_DIR"/* "$TEMP_DIR/functions/" 2>/dev/null || true

# Create zip file
cd "$TEMP_DIR"
zip -r "$ZIP_FILE" functions

# Deploy functions
echo "Deploying functions to $FUNCTION_APP_NAME..."
az functionapp deployment source config-zip \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --src "$ZIP_FILE"

# Clean up
rm -rf "$TEMP_DIR"

echo "Function deployment completed"
echo "--------------------------------"
echo "Elysium USV Data Pipeline deployment completed successfully!"
echo "--------------------------------"