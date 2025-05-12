# Project Scope - USV data pipeline
This project is to forward survey data captured by an Unmanned Surface Vehicle (USV) to the client commissioning the survey (Revelare).

Elysium (Australia) is operating a USV / vessel developed by SeaSats (the OEM), and requires CAST to stand up Azure cloud infrastucture to meet the client requirements.  

Rough Client requirements:
1. Direct upload at regular intervals to a per-vessel AWS S3 bucket and prefix we specify
2. Dedicated key/secret per vessel with a limited permission boundary (matching our other vessel upload configurations) which permits S3 PUT commands on the specific prefix only
3. Retention on the vessel until validated in our S3 infrastructure
4. Scheduled removals of validated data
5. Audit at the end of the project to ensure all data on the vessels is destroyed (as we will be required to furnish Defence with a destruction certificate)

Clarifications:
- SeaSats (US based company) transmits data from the USV via StarLink to a groundstation server
- The groundstation server will be in CAST's Azure tenancy
- Data from the server will be transferred to blob storage prior to upload (i.e. there is no direct from vessel upload planned, TBC)
- User access monitoring and geolocking within Azure is required to demonstrate Australia data sovereignty to the client - i.e. Foreign nationals without Australian work rights cannot interact with the data and the data cannot be stored overseas. 
- Elysium Australian Staff will require access to data and to monitor infrastrucuture
