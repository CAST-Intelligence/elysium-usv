#!/bin/bash
set -e

# Parse command line arguments
ENVIRONMENT="dev"
RESOURCE_GROUP="elysium-usv"
MAX_ATTEMPTS=12
SLEEP_SECONDS=30

print_usage() {
  echo "Usage: $0 [-e <environment>] [-g <resource_group>] [-a <max_attempts>] [-s <sleep_seconds>]"
  echo "  -e  Environment (dev, test, prod) - default: dev"
  echo "  -g  Resource group name - default: elysium-usv"
  echo "  -a  Maximum check attempts - default: 12"
  echo "  -s  Seconds between attempts - default: 30"
  exit 1
}

while getopts ":e:g:a:s:" option; do
  case $option in
    e)
      ENVIRONMENT=$OPTARG
      ;;
    g)
      RESOURCE_GROUP=$OPTARG
      ;;
    a)
      MAX_ATTEMPTS=$OPTARG
      ;;
    s)
      SLEEP_SECONDS=$OPTARG
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

# Set Key Vault name and script directory
KEY_VAULT_NAME="elysium-usv-${ENVIRONMENT}-kv"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Waiting for Key Vault purge to complete: $KEY_VAULT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Maximum attempts: $MAX_ATTEMPTS"
echo "Seconds between attempts: $SLEEP_SECONDS"
echo "-----------------------------------"

# Wait for Key Vault to be purged
ATTEMPTS=1
while [ $ATTEMPTS -le $MAX_ATTEMPTS ]; do
  echo "Attempt $ATTEMPTS/$MAX_ATTEMPTS: Checking Key Vault status..."
  
  # Check for soft-deleted vault
  DELETED_VAULT=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json)
  if [ "$(echo $DELETED_VAULT | jq 'length')" -eq "0" ]; then
    echo "✅ Key Vault has been purged successfully!"
    break
  fi
  
  echo "Key Vault is still in soft-deleted state. Waiting $SLEEP_SECONDS seconds..."
  ATTEMPTS=$((ATTEMPTS+1))
  
  if [ $ATTEMPTS -gt $MAX_ATTEMPTS ]; then
    echo "❌ Maximum attempts reached. Key Vault is still in soft-deleted state."
    echo "You have two options:"
    echo "1. Wait longer and try again later"
    echo "2. Use a different environment name with: -e <environment>"
    exit 1
  fi
  
  sleep $SLEEP_SECONDS
done

# Deploy the solution
echo "-----------------------------------"
echo "Starting deployment..."
$SCRIPT_DIR/deploy.sh -g $RESOURCE_GROUP -e $ENVIRONMENT -n "elysium-usv-deployment" -y