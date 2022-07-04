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
$pathtofile = Read-Host "Enter path name where bacpac will be stored" -MaskInput

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

#You should input the SQL script within query quotes before executing the scripts. In this step, you remove the custom users on Azure SQL DB
#so you can safely export it and import it without problems to RDS

Invoke-Sqlcmd -ServerInstance $sqlsvname -Database $copyname -Username $azuresvusername -Password $azuresvpassword `
-query 'delete user [XXXXXXX]'

echo "Starting export of a DB. To do this you should have sqlpackage.exe installed. You can get it from here: https://docs.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-download?view=sql-server-ver16"

cd 'C:\Program Files\Microsoft SQL Server\150\DAC\bin\'

.\sqlpackage.exe /a:Export /tf:$pathtofile /ssn:$sqlsvname /sdn:$copyname /su:$azuresvusername /sp:$azuresvpassword


echo "Importing bacpac of the DB to AWS"


.\sqlpackage.exe /a:Import /sf:$pathtofile /tsn:$awsrdsserver /tdn:$awsrdsdb /tu:$awsrdsusername /tp:$awsrdspass

#You should input the SQL script within query quotes before executing the scripts. You will input script to create application and also other requested
#users to newly transfered DB, so application will work normally in AWS.

Invoke-Sqlcmd -ServerInstance $awsrdsserver -Database $copyname -Username $awsrdsusername -Password $awsrdspass `
-query "CREATE LOGIN XXXXXX"