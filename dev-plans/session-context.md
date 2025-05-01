# Elysium USV Project - Session Context

## 1. Primary Request and Intent
The project involves designing a detailed architecture for a data pipeline to transfer survey data from Unmanned Surface Vehicles (USVs) to a client named Revelare. The data is captured from SeaSats USVs via Starlink, processed in an Azure environment in Australia (meeting data sovereignty requirements), and transferred to AWS S3 buckets. The goal is to build a secure, auditable pipeline that ensures data integrity, proper validation, and compliance with Australian defense requirements.

## 2. Key Technical Concepts
- USV data collection and transmission via Starlink satellite communication
- Ground Station server in Azure Australia region for initial data receipt
- Azure Blob Storage for temporary data storage with encryption
- Data validation with checksum verification at multiple stages
- Secure transfer to client-specific AWS S3 buckets using vessel-specific credentials
- Geo-locking and access controls for Australian data sovereignty
- Audit logging and compliance reporting
- Azure Functions and Logic Apps for implementing the pipeline components
- Mock testing infrastructure while ground station is under development
- MinIO or alternative S3-compatible test environments

## 3. Files and Code Sections
- **README.md**: Contains system architecture diagram and data flow sequence diagram in Mermaid format, along with key components and requirements
- **revalare-requirements.md**: Original client requirements and project scope
- **dev-plan.md**: Four-phase development plan with timelines and resources
- **azure-services-comparison.md**: Detailed comparison of Azure Functions vs Logic Apps for implementation
- GitHub repository: CAST-Intelligence/elysium-usv created to host the project

## 4. Problem Solving
- Designed architecture meeting strict data sovereignty and security requirements
- Created visualization of complex data flow using Mermaid diagrams
- Modified diagrams for improved readability (adding margins, using rounded corners)
- Added checksum verification sequence for ensuring data integrity
- Developed phased approach to enable development while ground station is unavailable
- Evaluated Azure service options, recommending a hybrid approach of Functions and Logic Apps

## 5. Pending Tasks
- Select specific Azure service implementation approach
- Choose mock S3 implementation strategy (MinIO, Azure Blob with S3 API, or AWS test account)
- Define data formats and sample files based on expected USV output
- Set up initial Azure environment with Infrastructure as Code
- Implement mock data generator for testing
- Develop core pipeline components (validation, transfer, tracking)

## 6. Current Work
The most recent focus was comparing Azure Functions and Logic Apps for the pipeline implementation. A hybrid approach was recommended where Logic Apps handle orchestration and Azure Functions handle performance-critical components like data validation and checksum verification. The document analyzes strengths and limitations of each service and provides implementation considerations including security, compliance, maintenance, and cost factors.

## 7. Next Step Recommendation
The logical next step would be to evaluate and select a mock S3 implementation strategy (step 2 in the "Next Steps" section of dev-plan.md). This would involve comparing MinIO, Azure Blob with S3-compatible API, and a separate AWS test account, considering factors such as development simplicity, fidelity to production environment, and cost. After selecting the strategy, create a document outlining the implementation approach and requirements.