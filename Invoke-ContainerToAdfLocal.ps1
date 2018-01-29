Param(
    [string] $ContainerImage,
    [string] $ContainerResourceGroup,
    [string] $ContainerName,
    [string] $ContainerVolumeMountPath,
    [string] $StorageAccountResourceGroup,
    [string] $StorageAccountName,
    [SecureString] $StorageAccountKey,
    [string] $FileShareName,
    [string] $BlobContainerName
)


# ./Invoke-ContainerToAdfLocal.ps1 -ContainerImage jarvisrob/scrapereiv -ContainerResourceGroup rob-real-estate-test -ContainerName scrapereiv -ContainerVolumeMountPath /out -StorageAccountResourceGroup rob-re-store -StorageAccountName robrestore -StorageAccountKey $secpass -FileShareName scrape -BlobContainerName adf-test-blob

# Connection to Azure account
# Login-AzureRmAccount

# Naming the file produced
$y = Get-Date -UFormat %Y
$m = Get-Date -UFormat %m
$d = Get-Date -UFormat %d
$OutFileName = "scrape_$y-$m-$d.csv"

# Create storage credential
$StorageAccountCredential = New-Object System.Management.Automation.PSCredential ($StorageAccountName, $StorageAccountKey)

# Spin-up the container
Write-Output "Spinning up container"
New-AzureRmContainerGroup -ResourceGroupName $ContainerResourceGroup -Name $ContainerName -Image $ContainerImage -RestartPolicy Never -AzureFileVolumeShareName $FileShareName -AzureFileVolumeAccountCredential $StorageAccountCredential -AzureFileVolumeMountPath $ContainerVolumeMountPath -Command "python /app/scrapereiv.py $OutFileName"

# Poll the container, waiting for it to finish running, and kill once finished
$ContainerInfo = Get-AzureRmContainerGroup -ResourceGroupName $ContainerResourceGroup -Name $ContainerName
While (-NOT ($ContainerInfo.State -eq "Succeeded")) {
    Write-Output "Waiting ... Container state: $($ContainerInfo.State)"
    Start-Sleep -Seconds 10
    $ContainerInfo = Get-AzureRmContainerGroup -ResourceGroupName $ContainerResourceGroup -Name $ContainerName
}
Write-Output "Container finished. Final instance log:"
Get-AzureRmContainerInstanceLog -ResourceGroupName $ContainerResourceGroup -ContainerGroupName $ContainerName -Tail 20
Write-Output "Killing container"
Remove-AzureRmContainerGroup -ResourceGroupName $ContainerResourceGroup -Name $ContainerName

# Copy file(s) from file storage to blob
Write-Output "Copying file(s) to staging blob ..."
Set-AzureRmCurrentStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name  $StorageAccountName
Start-AzureStorageBlobCopy -SrcShareName $FileShareName -SrcFilePath "/$OutFileName" -DestContainer $BlobContainerName
$BlobCopyState = Get-AzureStorageBlobCopyState -Blob $OutFileName -Container $BlobContainerName
While (-NOT ($BlobCopyState.Status -eq "Success")) {
    Write-Output "Waiting ... Blob copy status: $($BlobCopyState.Status)"
    Start-Sleep -Seconds 2
    $BlobCopyState = Get-AzureStorageBlobCopyState -Blob $OutFileName -Container $BlobContainerName
}
Write-Output "Copy complete"

# Invoke the Data Factory pipeline
Write-Output "Invoking the ADF pipeline. Once invoked, this script is complete."
#Invoke-AzureRmDataFactoryV2Pipeline

Write-Output "Completed"
