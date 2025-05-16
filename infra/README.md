# Management Group Structure Testing

This directory contains scripts to test the management group structure and security controls in a safe, isolated environment within the CAST tenant.

## Prerequisites

- Azure CLI installed and configured
- Access to CAST tenant with Contributor permissions
- Personal tenant configured for Lighthouse testing

## Testing Process

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/elysium-usv.git
   cd elysium-usv/infra/scripts
   ```

2. Run the master test script:
   ```bash
   chmod +x run-all-tests.sh
   ./run-all-tests.sh
   ```

3. Alternatively, run each script individually:
   ```bash
   # Step 1: Create management group structure
   ./create-mg-structure.sh
   
   # Step 2: Create RBAC roles
   ./create-test-roles.sh
   
   # Step 3: Create policies
   ./create-test-policies.sh
   
   # Step 4: Set up Lighthouse delegation
   ./setup-lighthouse-test.sh
   
   # Step 5: Validate controls
   ./validate-controls.sh
   ```

## What Gets Tested

The testing suite validates:

1. Management group hierarchy creation
2. Resource group organization
3. Custom RBAC role implementation
4. Geographic restriction policies (Australia-only)
5. Storage security policies
6. Tag enforcement
7. Lighthouse delegation at management group level
8. Access controls between different stakeholders

## Test Results

After running the validation script, you'll see a summary of all test results. This helps identify any controls that are not functioning as expected.

## Cleanup

The validation script includes an option to clean up all test resources. If you choose not to clean up during validation, you can run cleanup manually:

```bash
./cleanup-test-resources.sh
```

## Key Test Components

### 1. Management Group Structure
The test creates a standalone hierarchy with the prefix "USV-TEST-" to avoid conflicts:

```
USV-TEST-ROOT
└── USV-TEST-ELYSIUM
    ├── USV-TEST-PROD
    │   ├── USV-TEST-PROD-INFRA
    │   ├── USV-TEST-PROD-APP
    │   └── USV-TEST-PROD-DATA
    ├── USV-TEST-TEST
    │   ├── USV-TEST-TEST-INFRA
    │   ├── USV-TEST-TEST-APP
    │   └── USV-TEST-TEST-DATA
    └── USV-TEST-SHARED
        ├── USV-TEST-MONITOR
        └── USV-TEST-SECURITY
```

### 2. Custom RBAC Roles
Creates three roles to test access control:
- NZ MSP Infrastructure Admin - For NZ-based management
- US OEM Ground Station Admin - For US-based OEM configuration
- AU Data Admin - For Australian data access

### 3. Azure Policies
Creates and tests policy enforcement:
- Australia-only Location - Ensures resources stay in Australian regions
- Environment Tagging - Automatically adds tags to resources
- Storage Security - Enforces secure storage configuration

### 4. Lighthouse Delegation
Tests management group-scoped Lighthouse delegation to allow your personal tenant to access resources in the CAST tenant with appropriate permissions.

## Troubleshooting

- **Management Group Creation Issues**: Ensure you have the right permissions at the tenant level
- **Policy Assignment Failures**: Check if you have Owner role at subscription level
- **Lighthouse Delegation Issues**: Verify that your personal tenant ID and principal ID are correct
- **VM Creation Timeouts**: Some tests involving VM creation might time out in resource-constrained environments

## Further Documentation

For detailed information on the management group structure and testing approach, see `mg-structure-validation-plan.md` in this directory.