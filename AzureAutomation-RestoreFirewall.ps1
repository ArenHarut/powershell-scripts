<#
.SYNOPSIS
	This Azure Automation runbook automates Azure Firewall restore from Blob storage.
.DESCRIPTION
	You should use this Runbook if you want to restore a backup which had been taken to Azure blob storage.
.PARAMETER StorageAccountName
	Specifies the name of the storage account where backup is stored
	
.PARAMETER ContainerName
	Specifies the name of the container where blob file of Azure firewall backup is stored
	
.PARAMETER BlobName
	Specifies the name of the file of the firewall backup that needs to be restored
.PARAMETER StorageAccountKey
	Specifies the storage key of the storage account
.PARAMETER FirewallResourceGroupName
	Specifies the name of the the resource group where firewall is
.OUTPUTS
	Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.
.NOTES
    AUTHOR: Aren Harutyunyan
    LASTEDIT: Jan 31, 2023 
    VERSION: 1.0
#>

param(
    [parameter(Mandatory=$true)]
	[String] $StorageAccountName,
    [parameter(Mandatory=$true)]
	[String] $ContainerName,
    [parameter(Mandatory=$true)]
    [String]$BlobName,
    [parameter(Mandatory=$true)]
    [String]$StorageAccountKey,
	[parameter(Mandatory=$true)]
    [string]$FirewallResourceGroupName
)

$ErrorActionPreference = 'stop'

function Login() {
	try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} 

}

$LocalFilePath = ($env:TEMP + "\" + $BlobName)
$TemplateFile = $LocalFilePath
$DeploymentName = "RestoreAzureFirewall"

# Connect to the storage account
$Context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

# Download the firewall backup JSON file
Get-AzStorageBlobContent -Blob $BlobName -Container $ContainerName -Destination $LocalFilePath -Context $Context -Force

Login
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $FirewallResourceGroupName -TemplateFile $TemplateFile

Write-Verbose "Azure Firewall backup script finished." -Verbose