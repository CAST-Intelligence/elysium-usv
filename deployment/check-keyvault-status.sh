#!/bin/bash

# Parse command line arguments
ENVIRONMENT="dev"

print_usage() {
  echo "Usage: $0 [-e <environment>]"
  echo "  -e  Environment (dev, test, prod) - default: dev"
  exit 1
}

while getopts ":e:" option; do
  case $option in
    e)
      ENVIRONMENT=$OPTARG
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

# Set Key Vault name
KEY_VAULT_NAME="elysium-usv-${ENVIRONMENT}-kv"

echo "Checking status of Key Vault: $KEY_VAULT_NAME"
echo "-----------------------------------"

# Check for active Key Vault
echo "Checking for active Key Vault..."
ACTIVE_VAULT=$(az keyvault list --query "[?name=='$KEY_VAULT_NAME']" -o json)
if [ "$(echo $ACTIVE_VAULT | jq 'length')" -ne "0" ]; then
  echo "✅ Active Key Vault found with name: $KEY_VAULT_NAME"
  echo "Location: $(echo $ACTIVE_VAULT | jq -r '.[0].location')"
  echo "Resource group: $(echo $ACTIVE_VAULT | jq -r '.[0].resourceGroup')"
  echo "Created on: $(echo $ACTIVE_VAULT | jq -r '.[0].properties.createTime')"
  echo "Status: ACTIVE"
  exit 0
fi

# Check for soft-deleted vault
echo "Checking for soft-deleted Key Vault..."
DELETED_VAULT=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json)
if [ "$(echo $DELETED_VAULT | jq 'length')" -ne "0" ]; then
  echo "⚠️ Soft-deleted Key Vault found with name: $KEY_VAULT_NAME"
  echo "Location: $(echo $DELETED_VAULT | jq -r '.[0].properties.location')"
  echo "Deletion date: $(echo $DELETED_VAULT | jq -r '.[0].properties.deletionDate')"
  echo "Recovery level: $(echo $DELETED_VAULT | jq -r '.[0].properties.recoveryLevel')"
  echo "Scheduled purge date: $(echo $DELETED_VAULT | jq -r '.[0].properties.scheduledPurgeDate')"
  echo "Status: SOFT-DELETED (purge in progress or pending)"
else
  echo "No soft-deleted Key Vault found with name: $KEY_VAULT_NAME"
  echo "Status: PURGED or NEVER EXISTED"
fi

echo "-----------------------------------"
echo "If a purge operation is in progress, it may take several minutes to complete."
echo "You can re-run this script to check the current status."