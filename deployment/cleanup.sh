#!/bin/bash
set -e

# Parse command line arguments
RESOURCE_GROUP="elysium-usv"
CHECK_MANAGED=false

print_usage() {
  echo "Usage: $0 -g <resource_group> [-m]"
  echo "  -g  Resource group name (required)"
  echo "  -m  Check for managed resource groups too"
  exit 1
}

while getopts ":g:m" option; do
  case $option in
    g)
      RESOURCE_GROUP=$OPTARG
      ;;
    m)
      CHECK_MANAGED=true
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

# Check if resource group exists
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")
if [ "$RG_EXISTS" = "false" ]; then
  echo "Resource group $RESOURCE_GROUP does not exist"
  exit 0
fi

# Print information about resources to be deleted
echo "Resource group to delete:"
echo "- $RESOURCE_GROUP"

# Check for managed resource groups
if [ "$CHECK_MANAGED" = "true" ]; then
  echo "Checking for managed resource groups..."
  MANAGED_RGS=$(az group list --query "[?starts_with(name, 'managed-$RESOURCE_GROUP')].name" -o tsv)
  
  if [ -n "$MANAGED_RGS" ]; then
    echo "The following managed resource groups will also be deleted:"
    while read -r MANAGED_RG; do
      echo "- $MANAGED_RG"
    done <<< "$MANAGED_RGS"
  else
    echo "No managed resource groups found."
  fi
fi

# Confirm deletion
read -p "WARNING: This will delete ALL resources in the specified resource group(s). Continue? (y/n): " CONTINUE
if [ "$CONTINUE" != "y" ]; then
  echo "Deletion cancelled"
  exit 0
fi

# Delete the resource group
echo "Deleting resource group $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

# Delete managed resource groups if requested
if [ "$CHECK_MANAGED" = "true" ] && [ -n "$MANAGED_RGS" ]; then
  while read -r MANAGED_RG; do
    echo "Deleting managed resource group $MANAGED_RG..."
    az group delete --name "$MANAGED_RG" --yes --no-wait
  done <<< "$MANAGED_RGS"
fi

echo "Deletion initiated. Resources will be deleted in the background."
echo "You can check the status with: az group list --query \"[?contains(name,'$RESOURCE_GROUP')].name\" -o tsv"