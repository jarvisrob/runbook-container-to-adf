# Azure Container Instance to Azure Data Factory

PowerShell script that does the following. Assumes you are already logged into Azure using `Login-AzureRmAccount`.

1. Spins-up one-shot container instance, which stores output file(s) to Azure File storage through volume mounting
2. Kills the container
3. Copies output file(s) to Azure Blob storage, used as a staging area
4. Invokes Azure Data Factory pipeline to manipulate (often ingest) data in output file(s)

Script runs until the Data Factory pipeline is complete. It continuously polls state/status flags during operation, providing feedback on the process as it unfolds.

Requires the following:
- Azure PowerShell installed
- One-shot container image that produces output file(s)
- Storage account with file share and blob storage container ready to go
- Credentials (name and key) for the storage account
- Data Factory pipeline connecting the blob (source) to the destination data sink

To use in Azure Automation as a runbook, you will need to load the `AzureRM.ContainerInstance` PowerShell module.
