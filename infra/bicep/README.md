# Elysium USV Infrastructure as Code

This directory contains the Bicep modules and deployment scripts for the Elysium USV management group structure, RBAC roles, policies, and Lighthouse delegations.

## Structure

- `main.bicep` - Main deployment file that orchestrates all modules
- `modules/` - Contains individual Bicep modules:
  - `management-groups.bicep` - Creates the management group hierarchy
  - `rbac-roles.bicep` - Defines custom RBAC roles for different stakeholders
  - `policies.bicep` - Defines and assigns policies for security and compliance
  - `lighthouse.bicep` - Configures Azure Lighthouse delegations for NZ MSP
  - `scripts/` - Contains deployment and validation scripts:
    - `deploy.sh` - Main deployment script
    - `validate.sh` - Validation script to verify the deployment

## Deployment Flow

1. The main.bicep file deploys in this order:
   - Management group structure
   - Custom RBAC roles
   - Azure policies
   - Lighthouse delegations

2. Resource naming follows a consistent pattern:
   - Prefix-based naming for test/production separation
   - Hierarchical structure for easy identification

## Quick Start

### Test Deployment

To deploy a test environment with isolated resources:

```bash
./modules/scripts/deploy.sh --mode test --prefix "USV-TEST-"
```

### Production Deployment

For production deployment, provide the NZ MSP tenant and principal IDs:

```bash
./modules/scripts/deploy.sh \
  --mode prod \
  --prefix "USV-" \
  --msp-tenant "00000000-0000-0000-0000-000000000000" \
  --msp-infra "11111111-1111-1111-1111-111111111111" \
  --msp-app "22222222-2222-2222-2222-222222222222"
```

### Validation

After deployment, run the validation script to verify everything worked:

```bash
./modules/scripts/validate.sh --prefix "USV-TEST-"
```

## Management Group Structure

```
Root Management Group
├── Elysium-USV-MG (Top-level for all USV resources)
│   ├── USV-Production-MG (Production environment)
│   │   ├── USV-Prod-Infra-MG (Infrastructure components)
│   │   ├── USV-Prod-App-MG (Application components)
│   │   └── USV-Prod-Data-MG (Data components - AU only)
│   │
│   ├── USV-Testing-MG (Test environment)
│   │   ├── USV-Test-Infra-MG (Test infrastructure)
│   │   ├── USV-Test-App-MG (Test applications)
│   │   └── USV-Test-Data-MG (Test data - AU only)
│   │
│   └── USV-Shared-MG (Shared services)
│       ├── USV-Monitoring-MG (Monitoring resources)
│       └── USV-Security-MG (Security resources)
```

## Multi-Stakeholder Access Model

This implementation supports three key stakeholders:

1. **Australian Team (Elysium)** - Full control with data access rights
2. **NZ-based MSP (CAST)** - Infrastructure and application management via Lighthouse
3. **US-based OEM (SeaSats)** - Limited access for ground station configuration

Each stakeholder has tailored RBAC roles with appropriate permissions scoped to specific management groups.

## Key Policies

- **Australia-only Location Policy** - Ensures all data resources are deployed only in Australian regions
- **Test Environment Tagging** - Automatically applies "Environment: Testing" tag to all test resources
- **Storage Security Policy** - Enforces secure configuration for all storage accounts
- **OEM Session Monitoring** - Enhances auditing for US OEM configuration sessions

## Lighthouse Delegations

- **Infrastructure Management** - Allows NZ MSP to manage infrastructure resources
- **Application Management** - Allows NZ MSP to manage application resources
- **Data Protection** - Prevents NZ MSP from accessing data contents

## Rollback Capability

The deployment script automatically backs up the current state before deployment, enabling manual rollback if needed.

## Benefits of This Approach

1. **Human-readable IaC** - Bicep provides a clean, declarative syntax
2. **Modular design** - Easy to update individual components
3. **Tenant-level deployment** - Complete management group hierarchy
4. **What-if analysis** - Preview changes before deployment
5. **Validation built-in** - Automated testing after deployment