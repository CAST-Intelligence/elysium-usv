#!/bin/bash
set -e

# Parse command line arguments
ENVIRONMENT="dev"
LOCATION="australiaeast"
RESOURCE_GROUP=""
DEPLOYMENT_NAME="elysium-usv-deployment"

print_usage() {
  echo "Usage: $0 -g <resource_group> [-e <environment>] [-l <location>] [-n <deployment_name>]"
  echo "  -g  Resource group name (required)"
  echo "  -e  Environment (dev, test, prod) - default: dev"
  echo "  -l  Azure region location - default: australiaeast"
  echo "  -n  Deployment name - default: elysium-usv-deployment"
  exit 1
}

while getopts ":g:e:l:n:" option; do
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
read -p "Continue with deployment? (y/n): " CONTINUE
if [ "$CONTINUE" != "y" ]; then
  echo "Deployment cancelled"
  exit 0
fi

# Check if resource group exists, create if not
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")
if [ "$RG_EXISTS" = "false" ]; then
  echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
  echo "Resource group $RESOURCE_GROUP already exists"
fi

# Deploy ARM template
echo "Deploying infrastructure..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file azure-deployment.json \
  --parameters environment="$ENVIRONMENT" location="$LOCATION" \
  --output json)

# Extract outputs
FUNCTION_APP_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.functionAppName.value')
STORAGE_ACCOUNT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.storageAccountName.value')
KEY_VAULT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.keyVaultName.value')

echo "Infrastructure deployment completed"
echo "--------------------------------"
echo "Function App: $FUNCTION_APP_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Key Vault: $KEY_VAULT_NAME"
echo "--------------------------------"

# Deploy Logic Apps
echo "Deploying Logic Apps..."

echo "1. Deploying Master Orchestration Logic App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "master-orchestrator-deployment" \
  --template-file ../src/logic-apps/master-orchestration-workflow.json \
  --parameters workflows_name="$ENVIRONMENT-usv-master-orch" \
              location="$LOCATION" \
              storageName="$STORAGE_ACCOUNT_NAME" \
              functionAppName="$FUNCTION_APP_NAME"

echo "2. Deploying S3 Transfer Logic App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "s3-transfer-deployment" \
  --template-file ../src/logic-apps/s3-transfer-workflow.json \
  --parameters workflows_name="$ENVIRONMENT-usv-s3-transfer" \
              location="$LOCATION" \
              storageName="$STORAGE_ACCOUNT_NAME" \
              functionAppName="$FUNCTION_APP_NAME"

echo "3. Deploying Cleanup Logic App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "cleanup-deployment" \
  --template-file ../src/logic-apps/cleanup-workflow.json \
  --parameters workflows_name="$ENVIRONMENT-usv-cleanup" \
              location="$LOCATION" \
              storageName="$STORAGE_ACCOUNT_NAME" \
              retentionDays=7

echo "Logic Apps deployment completed"

# Deploy Function App code
echo "Deploying Azure Functions..."

# Create a ZIP deployment package
echo "Creating deployment package..."
ROOT_DIR=$(dirname "$(dirname "$0")")
TEMP_DIR=$(mktemp -d)
FUNCTIONS_DIR="$ROOT_DIR/src/functions"
ZIP_FILE="$TEMP_DIR/functions.zip"

# Copy function code to temp directory
mkdir -p "$TEMP_DIR/functions"
cp -R "$FUNCTIONS_DIR"/* "$TEMP_DIR/functions/"

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