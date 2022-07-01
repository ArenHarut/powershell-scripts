#Before the start make sure that servers and epools exist. For the sake of speed, create a separate Elastic pool with several vcores so bacpac generation won't stuck for hours


echo "Setting envrionment variables and creds"

$subid = Read-Host "Enter Azure Subscription ID"
$rgname = Read-Host "Enter Azure Resource group name"
$sourceserver = Read-Host "Enter Azure Source SQL server. Means name without .databas.windows.net"
$dbname = Read-Host "Enter Azure SQL DB name need to be copied"
$targetserver = Read-Host "Enter Azure SQL Server name where you want to restore the copy. Means name without .databas.windows.net"
$copyname = Read-Host "Enter Azure SQL copy DB name"
$epoolname = Read-Host "Enter Azure SQL Epool name which needs to be created before this script runs"
$azuresvusername = Read-Host "Enter Azure SQL Server admin username"
$azuresvpassword = Read-Host "Enter Azure SQL Server password" -AsSecureString
$azuresvpassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($azuresvpassword))
$sqlsvname = Read-Host "Enter Azure SQL Server full dns name"
$awsrdsserver = Read-Host "Enter AWS RDS server dns name"
$awsrdsdb = Read-Host "Enter AWS RDS db name"
$awsrdsusername = Read-Host "Enter AWS RDS username" -MaskInput
$awsrdspass = Read-Host "Enter AWS RDS server password" -AsSecureString
$awsrdspass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($awsrdspass))
$azuresqlsvfqdn = "brit-rb-production-sql-01.database.windows.net"
$pathtofile = "D:\Users\I29655\Documents\Brit-Rulebook-2-4-Prod-Primary.bacpac"

echo "Installing dependencies"

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet



Install-Module Az
Import-Module Az.Accounts
Connect-AzAccount -Subscription $subid

echo "Checking if Epool exists. If not create one"

$epool = Get-AzSqlElasticPool -ResourceGroupName $rgname -ServerName $sourceserver -ElasticPoolName $epoolname -ErrorAction SilentlyContinue

if($epool -eq $null){
    $epoolcreate =  New-AzSqlElasticPool -ResourceGroupName $rgname -ServerName $sourceserver -ElasticPoolName $epoolname -Edition "Standard" -Dtu 800
}
else{
    Write-Host "$epoolname already exist"
}

echo "Copying Azure original DB"


New-AzSqlDatabaseCopy -ResourceGroupName $rgname -ServerName $sourceserver -DatabaseName $dbname `
    -CopyResourceGroupName $rgname -ElasticPoolName $epoolname -CopyServerName $targetserver -CopyDatabaseName $copyname


Install-Module -Name SQLServer
Import-Module -Name SQLServer

echo "Deleting Custom users in copied DB"

#You should input the SQL script within query quotes before executing the scripts. Just replace usernames that you see in closed brackets with actual usernames
#that you notice in Original DB

Invoke-Sqlcmd -ServerInstance $azuresqlsvfqdn -Database $copyname -Username $azuresvusername -Password $azuresvpassword `
-query Read-Host "Delete users script"

echo "Starting export of a DB. To do this you should have sqlpackage.exe installed. You can get it from here: https://docs.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-download?view=sql-server-ver16"

cd 'C:\Program Files\Microsoft SQL Server\150\DAC\bin\'

.\sqlpackage.exe /a:Export /tf:$pathtofile /ssn:$sqlsvname /sdn:$copyname /su:$azuresvusername /sp:$azuresvpassword


echo "Importing bacpac of the DB to AWS"


.\sqlpackage.exe /a:Import /sf:$pathtofile /tsn:$awsrdsserver /tdn:$awsrdsdb /tu:$awsrdsusername /tp:$awsrdspass