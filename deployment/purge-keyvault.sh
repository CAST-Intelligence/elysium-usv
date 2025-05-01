#!/bin/bash
set -e

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

echo "Checking for soft-deleted Key Vault: $KEY_VAULT_NAME"

# Check for soft-deleted vault
DELETED_VAULT=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json)
if [ "$(echo $DELETED_VAULT | jq 'length')" -eq "0" ]; then
  echo "No soft-deleted Key Vault found with name: $KEY_VAULT_NAME"
  exit 0
fi

echo "Found soft-deleted Key Vault: $KEY_VAULT_NAME"
echo "Location: $(echo $DELETED_VAULT | jq -r '.[0].properties.location')"
echo "Deletion date: $(echo $DELETED_VAULT | jq -r '.[0].properties.deletionDate')"

# Confirm purge
read -p "WARNING: This will permanently delete the soft-deleted Key Vault '$KEY_VAULT_NAME'. Continue? (y/n): " CONTINUE
if [ "$CONTINUE" != "y" ]; then
  echo "Purge cancelled"
  exit 0
fi

# Purge the deleted vault
echo "Purging soft-deleted Key Vault: $KEY_VAULT_NAME..."
az keyvault purge --name "$KEY_VAULT_NAME"

echo "Key Vault '$KEY_VAULT_NAME' has been purged successfully."
echo "You can now proceed with deployment."