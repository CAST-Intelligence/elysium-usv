#!/bin/bash
set -e

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOGIC_APP_DIR="$ROOT_DIR/src/logic-apps"

echo "Reinstalling Logic App Templates"
echo "--------------------------------"
echo "Project Root: $ROOT_DIR"
echo "Logic App Dir: $LOGIC_APP_DIR"

# Create Logic App directory if it doesn't exist
mkdir -p "$LOGIC_APP_DIR"

# Copy all Logic App templates
echo "Copying Master Orchestration Logic App template..."
cat > "$LOGIC_APP_DIR/master-orchestration-workflow.json" << 'EOF'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "workflows_name": {
            "defaultValue": "usv-data-orchestrator",
            "type": "String"
        },
        "location": {
            "defaultValue": "australiaeast",
            "type": "String"
        },
        "storageName": {
            "defaultValue": "usvdatastorage",
            "type": "String"
        },
        "functionAppName": {
            "defaultValue": "usv-validation-functions",
            "type": "String"
        }
    },
    "variables": {
        "storageConnectionString": "[concat('DefaultEndpointsProtocol=https;AccountName=', parameters('storageName'), ';EndpointSuffix=core.windows.net')]"
    },
    "resources": [
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "[parameters('workflows_name')]",
            "location": "[parameters('location')]",
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Hour",
                                "interval": 1
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Placeholder": {
                            "runAfter": {},
                            "type": "Response",
                            "inputs": {
                                "statusCode": 200,
                                "body": {
                                    "status": "This is a placeholder Logic App. It will be replaced with the full implementation."
                                }
                            }
                        }
                    },
                    "outputs": {}
                }
            }
        }
    ]
}
EOF

echo "Copying S3 Transfer Logic App template..."
cat > "$LOGIC_APP_DIR/s3-transfer-workflow.json" << 'EOF'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "workflows_name": {
            "defaultValue": "s3-transfer-workflow",
            "type": "String"
        },
        "location": {
            "defaultValue": "australiaeast",
            "type": "String"
        },
        "storageName": {
            "defaultValue": "usvdatastorage",
            "type": "String"
        },
        "functionAppName": {
            "defaultValue": "usv-validation-functions",
            "type": "String"
        }
    },
    "variables": {
        "storageConnectionString": "[concat('DefaultEndpointsProtocol=https;AccountName=', parameters('storageName'), ';EndpointSuffix=core.windows.net')]"
    },
    "resources": [
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "[parameters('workflows_name')]",
            "location": "[parameters('location')]",
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "manual": {
                            "type": "Request",
                            "kind": "Http",
                            "inputs": {
                                "schema": {
                                    "properties": {
                                        "blobName": {
                                            "type": "string"
                                        },
                                        "vesselId": {
                                            "type": "string"
                                        }
                                    },
                                    "type": "object"
                                }
                            }
                        }
                    },
                    "actions": {
                        "Placeholder": {
                            "runAfter": {},
                            "type": "Response",
                            "inputs": {
                                "statusCode": 200,
                                "body": {
                                    "status": "This is a placeholder S3 transfer Logic App. It will be replaced with the full implementation."
                                }
                            }
                        }
                    },
                    "outputs": {}
                }
            }
        }
    ]
}
EOF

echo "Copying Cleanup Logic App template..."
cat > "$LOGIC_APP_DIR/cleanup-workflow.json" << 'EOF'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "workflows_name": {
            "defaultValue": "usv-data-cleanup",
            "type": "String"
        },
        "location": {
            "defaultValue": "australiaeast",
            "type": "String"
        },
        "storageName": {
            "defaultValue": "usvdatastorage",
            "type": "String"
        },
        "functionAppName": {
            "defaultValue": "usv-validation-functions",
            "type": "String"
        },
        "retentionDays": {
            "defaultValue": 7,
            "type": "int"
        }
    },
    "variables": {
        "storageConnectionString": "[concat('DefaultEndpointsProtocol=https;AccountName=', parameters('storageName'), ';EndpointSuffix=core.windows.net')]"
    },
    "resources": [
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "[parameters('workflows_name')]",
            "location": "[parameters('location')]",
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        },
                        "retentionDays": {
                            "defaultValue": "[parameters('retentionDays')]",
                            "type": "Int"
                        }
                    },
                    "triggers": {
                        "Schedule": {
                            "recurrence": {
                                "frequency": "Day",
                                "interval": 1,
                                "schedule": {
                                    "hours": [
                                        "3"
                                    ]
                                },
                                "timeZone": "Australia/Sydney"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Placeholder": {
                            "runAfter": {},
                            "type": "Response",
                            "inputs": {
                                "statusCode": 200,
                                "body": {
                                    "status": "This is a placeholder cleanup Logic App. It will be replaced with the full implementation."
                                }
                            }
                        }
                    },
                    "outputs": {}
                }
            }
        }
    ]
}
EOF

# Verify files were created
echo "Verifying files were created:"
ls -la "$LOGIC_APP_DIR"

echo "--------------------------------"
echo "Logic App Templates installed successfully!"
echo "You can now run the deployment script to deploy the Logic Apps."