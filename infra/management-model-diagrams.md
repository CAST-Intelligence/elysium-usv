# USV Pipeline Management Model Diagrams

The following diagrams illustrate the comprehensive management model for the Elysium USV Data Pipeline, showing the management group hierarchy, stakeholder access model, and workflow patterns.

## Management Group Hierarchy

```mermaid
%%{init: {'theme': 'neutral', 'flowchart': {'curve': 'linear'}}}%%
flowchart TD
    Root("Root Management Group")
    EUSV("Elysium-USV-MG")
    
    Root --> EUSV
    
    subgraph "Production Environment"
        PROD("USV-Production-MG")
        PROD-INF("USV-Prod-Infra-MG")
        PROD-APP("USV-Prod-App-MG")
        PROD-DATA("USV-Prod-Data-MG")
        
        PROD --> PROD-INF
        PROD --> PROD-APP
        PROD --> PROD-DATA
    end
    
    subgraph "Test Environment"
        TEST("USV-Testing-MG")
        TEST-INF("USV-Test-Infra-MG")
        TEST-APP("USV-Test-App-MG")
        TEST-DATA("USV-Test-Data-MG")
        
        TEST --> TEST-INF
        TEST --> TEST-APP
        TEST --> TEST-DATA
    end
    
    subgraph "Shared Services"
        SHARED("USV-Shared-MG")
        MONITOR("USV-Monitoring-MG")
        SECURITY("USV-Security-MG")
        
        SHARED --> MONITOR
        SHARED --> SECURITY
    end
    
    EUSV --> PROD
    EUSV --> TEST
    EUSV --> SHARED
    
    classDef prod fill:#c4e3f3,stroke:#337ab7,stroke-width:2px
    classDef test fill:#fcf8e3,stroke:#f0ad4e,stroke-width:2px
    classDef shared fill:#dff0d8,stroke:#5cb85c,stroke-width:2px
    classDef data fill:#f2dede,stroke:#d9534f,stroke-width:2px
    
    class PROD,PROD-INF,PROD-APP,PROD-DATA prod
    class TEST,TEST-INF,TEST-APP,TEST-DATA test
    class SHARED,MONITOR,SECURITY shared
    class PROD-DATA,TEST-DATA data
```

## Multi-Stakeholder Access Model

```mermaid
%%{init: {'theme': 'neutral', 'flowchart': {'curve': 'stepAfter'}}}%%
flowchart LR
    subgraph "Stakeholders"
        AU["Australian Team (Elysium)"]
        NZ["NZ-based MSP (CAST)"]
        US["US-based OEM (SeaSats)"]
    end
    
    subgraph "Access Level"
        AU -->|"Full Access"| all[All Resources]
        
        NZ -->|"Infrastructure Management"| inf[Infrastructure Resources]
        NZ -->|"Application Management"| app[Application Resources]
        NZ -.-x|"No Access"| data[Data Resources]
        
        US -->|"Temporary Config Access"| gs[Ground Station VMs]
        US -.-x|"No Access"| other[All Other Resources]
    end
    
    subgraph "Authentication"
        all --> auAD[Australian AAD]
        inf --> light[Lighthouse Delegation]
        app --> light
        gs --> pim[Privileged Identity Management]
    end
    
    subgraph "Geographic Control"
        auAD -->|"AU Location"| auGeo[Australia Only]
        light -->|"NZ Location"| nzGeo[Infrastructure Only]
        pim -->|"US Location + AU Approval"| usGeo[Ground Station Only]
    end
    
    classDef stakeholder fill:#e6f3ff,stroke:#0275d8,stroke-width:2px
    classDef access fill:#f5f5f5,stroke:#5bc0de,stroke-width:1px
    classDef auth fill:#dff0d8,stroke:#5cb85c,stroke-width:1px
    classDef geo fill:#f2dede,stroke:#d9534f,stroke-width:1px
    
    class AU,NZ,US stakeholder
    class all,inf,app,data,gs,other access
    class auAD,light,pim auth
    class auGeo,nzGeo,usGeo geo
```

## Resource Type Access by Role

```mermaid
%%{init: {'theme': 'neutral'}}%%
graph TD
    subgraph "Resource Types"
        VM["Virtual Machines"]
        APP["App Services"]
        STORAGE["Storage Accounts"]
        NETWORK["Networking"]
        KV["Key Vault"]
        MONITOR["Monitoring"]
    end
    
    subgraph "Stakeholder Roles"
        AU_ADMIN["AU Admin"]
        NZ_INFRA["NZ Infrastructure Admin"]
        NZ_APP["NZ App Admin"]
        US_GROUND["US Ground Station Admin"]
    end
    
    AU_ADMIN -->|"Full Access"| VM
    AU_ADMIN -->|"Full Access"| APP
    AU_ADMIN -->|"Full Access"| STORAGE
    AU_ADMIN -->|"Full Access"| NETWORK
    AU_ADMIN -->|"Full Access"| KV
    AU_ADMIN -->|"Full Access"| MONITOR
    
    NZ_INFRA -->|"Manage Only"| VM
    NZ_INFRA -->|"Manage Only"| NETWORK
    NZ_INFRA -->|"Read Only"| MONITOR
    NZ_INFRA -.-x|"No Access"| STORAGE
    NZ_INFRA -.-x|"No Access"| KV
    
    NZ_APP -->|"Manage Only"| APP
    NZ_APP -->|"Read Only"| MONITOR
    NZ_APP -.-x|"No Access"| VM
    NZ_APP -.-x|"No Access"| STORAGE
    NZ_APP -.-x|"No Access"| NETWORK
    NZ_APP -.-x|"No Access"| KV
    
    US_GROUND -->|"Temporary Access"| VM
    US_GROUND -.-x|"No Access"| APP
    US_GROUND -.-x|"No Access"| STORAGE
    US_GROUND -->|"Limited Access"| NETWORK
    US_GROUND -.-x|"No Access"| KV
    US_GROUND -.-x|"No Access"| MONITOR
    
    classDef resource fill:#f5f5f5,stroke:#5bc0de,stroke-width:1px
    classDef role fill:#e6f3ff,stroke:#0275d8,stroke-width:2px
    
    class VM,APP,STORAGE,NETWORK,KV,MONITOR resource
    class AU_ADMIN,NZ_INFRA,NZ_APP,US_GROUND role
```

## Test vs. Production Environment

```mermaid
%%{init: {'theme': 'neutral', 'flowchart': {'curve': 'basis'}}}%%
flowchart TD
    subgraph "Test Environment"
        direction LR
        TEST_VM["Ground Station VM"]
        TEST_APP["Data Pipeline App"]
        TEST_STORAGE["Storage Account"]
        
        TEST_VM -->|"Process"| TEST_APP
        TEST_APP -->|"Store"| TEST_STORAGE
    end
    
    subgraph "Production Environment"
        direction LR
        PROD_VM["Ground Station VM"]
        PROD_APP["Data Pipeline App"]
        PROD_STORAGE["Storage Account"]
        
        PROD_VM -->|"Process"| PROD_APP
        PROD_APP -->|"Store"| PROD_STORAGE
    end
    
    AU["Australian\nTeam"] -.->|"Full Access"| TEST_VM
    AU -.->|"Full Access"| TEST_APP
    AU -.->|"Full Access"| TEST_STORAGE
    AU -.->|"Full Access"| PROD_VM
    AU -.->|"Full Access"| PROD_APP
    AU -.->|"Full Access"| PROD_STORAGE
    
    NZ["NZ MSP\nTeam"] -.->|"Full Access"| TEST_VM
    NZ -.->|"Full Access"| TEST_APP
    NZ -.->|"No Access"| TEST_STORAGE
    NZ -.->|"Limited Access"| PROD_VM
    NZ -.->|"Limited Access"| PROD_APP
    NZ -.->|"No Access"| PROD_STORAGE
    
    US["US OEM\nTeam"] -.->|"Config Access"| TEST_VM
    US -.->|"No Access"| TEST_APP
    US -.->|"No Access"| TEST_STORAGE
    US -.->|"No Access"| PROD_VM
    US -.->|"No Access"| PROD_APP
    US -.->|"No Access"| PROD_STORAGE
    
    classDef test fill:#fcf8e3,stroke:#f0ad4e,stroke-width:1px
    classDef prod fill:#c4e3f3,stroke:#337ab7,stroke-width:1px
    classDef stake fill:#e6f3ff,stroke:#0275d8,stroke-width:2px
    
    class TEST_VM,TEST_APP,TEST_STORAGE test
    class PROD_VM,PROD_APP,PROD_STORAGE prod
    class AU,NZ,US stake
```

## Data Sovereignty and Geo-Protection

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TD
    subgraph "Data Flow"
        USV["USV (At Sea)"]
        GS["Ground Station\n(Australia)"]
        BLOB["Azure Blob Storage\n(Australia)"]
        PIPE["Data Pipeline\n(Australia)"]
        S3["AWS S3\n(Australia)"]
        
        USV -->|"Data Collection"| GS
        GS -->|"Processing"| BLOB
        BLOB -->|"Transfer"| PIPE
        PIPE -->|"Upload"| S3
    end
    
    subgraph "Geographic Controls"
        AU_GEO["Australia-Only\nData Access"]
        AU_VMS["AU-Hosted\nVirtual Machines"]
        AU_POLICY["Data Sovereignty\nPolicy"]
        AU_NET["Geographic\nNetwork Restrictions"]
        
        AU_GEO -->|"Enforces"| BLOB
        AU_VMS -->|"Hosts"| GS
        AU_VMS -->|"Hosts"| PIPE
        AU_POLICY -->|"Controls"| BLOB
        AU_POLICY -->|"Controls"| PIPE
        AU_NET -->|"Protects"| BLOB
        AU_NET -->|"Protects"| S3
    end
    
    subgraph "Access Patterns"
        AU_ACCESS["AU Admin\n(Full Access)"]
        NZ_ACCESS["NZ MSP\n(Infrastructure Only)"]
        US_ACCESS["US OEM\n(Ground Station Config)"]
        
        AU_ACCESS -->|"Manages"| GS
        AU_ACCESS -->|"Manages"| BLOB
        AU_ACCESS -->|"Manages"| PIPE
        AU_ACCESS -->|"Manages"| S3
        
        NZ_ACCESS -->|"Manages"| GS
        NZ_ACCESS -->|"Manages"| PIPE
        NZ_ACCESS -.-x|"No Access"| BLOB
        NZ_ACCESS -.-x|"No Access"| S3
        
        US_ACCESS -->|"Configures"| GS
        US_ACCESS -.-x|"No Access"| BLOB
        US_ACCESS -.-x|"No Access"| PIPE
        US_ACCESS -.-x|"No Access"| S3
    end
    
    classDef flow fill:#dff0d8,stroke:#5cb85c,stroke-width:1px
    classDef geo fill:#f2dede,stroke:#d9534f,stroke-width:1px
    classDef access fill:#e6f3ff,stroke:#0275d8,stroke-width:1px
    
    class USV,GS,BLOB,PIPE,S3 flow
    class AU_GEO,AU_VMS,AU_POLICY,AU_NET geo
    class AU_ACCESS,NZ_ACCESS,US_ACCESS access
```

## Lighthouse Implementation

```mermaid
%%{init: {'theme': 'neutral', 'flowchart': {'curve': 'linear'}}}%%
flowchart TD
    subgraph "Azure Tenants"
        AU_TENANT["Australian Tenant\n(Elysium)"]
        NZ_TENANT["NZ Tenant\n(CAST MSP)"]
    end
    
    subgraph "Lighthouse Delegation"
        LH_REG["Registration Definition"]
        LH_ASSIGN["Registration Assignment"]
        LH_ROLES["Role Assignments"]
        
        LH_REG -->|"References"| LH_ROLES
        LH_ASSIGN -->|"Uses"| LH_REG
    end
    
    subgraph "Delegation Scope"
        MG_INFRA["USV-Prod-Infra-MG"]
        MG_APP["USV-Prod-App-MG"]
        
        LH_ASSIGN -->|"Targets"| MG_INFRA
        LH_ASSIGN -->|"Targets"| MG_APP
    end
    
    AU_TENANT -->|"Hosts"| LH_REG
    AU_TENANT -->|"Hosts"| LH_ASSIGN
    AU_TENANT -->|"Controls"| MG_INFRA
    AU_TENANT -->|"Controls"| MG_APP
    
    NZ_TENANT -->|"Projects Into"| MG_INFRA
    NZ_TENANT -->|"Projects Into"| MG_APP
    
    classDef tenant fill:#e6f3ff,stroke:#0275d8,stroke-width:2px
    classDef lighthouse fill:#dff0d8,stroke:#5cb85c,stroke-width:1px
    classDef target fill:#fcf8e3,stroke:#f0ad4e,stroke-width:1px
    
    class AU_TENANT,NZ_TENANT tenant
    class LH_REG,LH_ASSIGN,LH_ROLES lighthouse
    class MG_INFRA,MG_APP target
```

## US OEM Temporary Access Pattern

```mermaid
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    autonumber
    actor US_OEM as US OEM Admin
    actor AU_ADMIN as AU Admin
    participant PIM as Privileged Identity Management
    participant VM as Ground Station VM
    participant AUDIT as Audit System
    
    US_OEM->>PIM: Request access to configure Ground Station
    PIM->>AU_ADMIN: Notify of access request
    AU_ADMIN->>PIM: Approve request with time limit (8 hours)
    PIM->>US_OEM: Grant temporary access
    PIM->>AUDIT: Log access approval
    
    US_OEM->>VM: Connect to VM using JIT access
    VM->>AUDIT: Record session start
    VM->>VM: Enable enhanced monitoring
    
    US_OEM->>VM: Configure ground station software
    VM->>AUDIT: Record all configuration actions
    
    US_OEM->>VM: Complete configuration
    VM->>AUDIT: Record session end
    PIM->>US_OEM: Revoke access after time expiration
    PIM->>AUDIT: Log access revocation
    
    AU_ADMIN->>AUDIT: Review session recordings and logs
    AUDIT->>AU_ADMIN: Provide compliance documentation
```

These diagrams provide a visual representation of the comprehensive management model, making it easier for stakeholders to understand:

1. How the management group hierarchy is structured
2. What access each stakeholder has
3. How resources are organized between test and production
4. How data sovereignty is enforced
5. How Lighthouse delegations are implemented
6. How temporary access for US OEM works

The diagrams use consistent color coding and styling to highlight relationships and access patterns across the different components of the system.