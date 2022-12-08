﻿# KALI Style - Cloud Data Migration APIs E2E (END TO END) - RS mod. 04/12/2022

# **  PRE-REQUIREMENTS ** 


# ** INSTALL ALL MODULES **
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

#Install MSAL.PS (experimental ps)
Install-Module -Name MSAL.PS  # command on the first run, unless you have installed MSAL.PS. This function is used to obtain the token
Import-Module "MSAL.PS"

#Path test CASE
$statusTextHelperPath = "C:\CloudMigrationStatusText.psm1"

#$statusTextHelperPath = Join-Path (Split-Path -Path ($MyInvocation.MyCommand.Path) -Parent) "C:\CloudMigrationStatusText.psm1"
Import-Module $statusTextHelperPath #running texr comments


#unclocK unsigned file
Unblock-File -Path "C:\CloudMigrationStatusText.psm1" 
Import-Module  "C:\CloudMigrationStatusText.psm1" 


#BC Container Helper
#install-module BCcontainerhelper -force
#Docker Access, may be usefull



# ** CLOUD MIGRATION CONFIG-PARAMETERS **
# Global Parameters - Update to fit the tenant
$script:AADTenantID =     "98ba312a"         # e.g. 12asdeaaa"
$script:CurrentUserName = "rcom"   # update to users credentials
$script:CurrentPassword = "UJ-8f"
$script:EnvironmentName = "CloudMigration"
$script:MainCompanyId =   "59e8e554a"         # E.g. 'a42119b9-15ab-ec11-bb8d-000d3a2b992c - Cronus SaaS Id or other company that is registered and not cloud migrated'


#OAuth2 App parameters - Register your app and update to match
#ClientID + User\Password
$script:ClientId = "f09b596"  #RS - TENANT DEMO CLIENT ID APP - registered in Azure Portal+BC remote Client ID APP
$script:RedirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"  #redirect URI
#$script:RedirectUri = "https://localhost"

#Authority URI
$script:BaseAuthorityUri = "https://login.microsoftonline.com"
$script:BcAppIdUri = "https://api.businesscentral.dynamics.com"
$script:BcScopes = @("$BcAppIdUri/user_impersonation", "$BcAppIdUri/Financials.ReadWrite.All" )
$script:AuthorityUri = "$BaseAuthorityUri/$AadTenantId"


#Settings
$script:GetStatusRetryAttempts = 10;
$script:GetReplicationRetryAttempt = 3;
$script:GetStatusSleepSeconds = 120;
$script:GetCreateCompanySleepSeconds = 120;

# This parameter can be 10 if there are not many tables added to the solution. Otherwise select the lower number.
$script:MaxNumberOfCompaniesToMoveAtOnce = 10;
$script:GetReplicationRetryAttempts = 10;
$script:IntegrationRuntimeInstallationPath = 'C:\Program Files\Microsoft Integration Runtime\5.0\PowerShellScript\RegisterIntegrationRuntime.ps1'

#Other parameters - TOKEN Expiration date
$script:TokenExpirationTime = (Get-Date)
$script:apiBaseUrl = "https://api.businesscentral.dynamics.com/v2.0/"  + $script:AADTenantID + "/" + $script:EnvironmentName + "/api/microsoft/cloudMigration/v1.0/"    




# **  CLOUD MIGRATION FUNCTIONS **

<# Run-CloudMigrationE2E
It will move the tenant and run the data upgrade
#>
function Run-CloudMigrationE2E
(
    [string] $UserName = $script:CurrentUserName, 
    [string] $Password = $script:CurrentPassword,
    [ValidateSet("DynamicsBCLast","DynamicsBC","DynamicsGP")]
    [string] $ProductId = "DynamicsBCLast",
    [ValidateSet("SQLServer","AzureSQL")]
    [string] $SqlServerType = 'SQLServer',
    [switch] $SkipSetup,
    [switch] $SetupAutomatically,
    [string] $SqlConnectionString,
    [System.Collections.ArrayList] $ExcludedCompanies = [System.Collections.ArrayList]::new(),
    [string] $Version = "v1.0"
)
{
    if(-not $SkipSetup)
    {
        Setup-CloudMigration -UserName $UserName -Password $Password -ProductId $ProductId -SqlServerType $SqlServerType -SetupAutomatically:$d -SqlConnectionString $SqlConnectionString -Version $Version
    }

    #write Status Text
    Write-CreatingCompaniesStatusText -StatusTextColor "Yellow"
    Create-CompaniesInBatches -UserName $UserName -Password $Password -ExcludedCompanies $ExcludedCompanies -Version $Version
    
    Write-RunningDataReplicationStatusText -StatusTextColor "White"
    $replicationSuccessful = Move-CompaniesInBatches -UserName $UserName -Password $Password -ExcludedCompanies $ExcludedCompanies -Version $Version

    if(-not $replicationSuccessful)
    {
        Write-Host "Replication was not succesfull, script will stop at this step" -ForegroundColor Red
        return
    }

    if($ProductId -ne "DynamicsBC")
    {
        Write-RunningDataUpgradeStatusText -StatusTextColor "White"
        Run-DataUpgrade -UserName $UserName -Password $Password -Version $Version
        Wait-ForUpgradeToComplete -UserName $UserName -Password $Password -Version $Version
        Write-Host ([datetime]::Now) "Data Upgrade Completed Succesfully" -ForegroundColor Green
    }

    Write-DisablingCloudMigrationStatusText -StatusTextColor "Green"
    Disable-CloudMigration -UserName $UserName -Password $Password -Version $Version
}


<# Setup the cloud migration
This function sets up and enables the cloud migration.
It is an automation of the Cloud Migration wizard page. 
#>
function Setup-CloudMigration
(
    [string] $UserName = $script:CurrentUserName, 
    [string] $Password = $script:CurrentPassword,
    [ValidateSet("DynamicsBCLast","DynamicsBC","DynamicsGP")]
    [string] $ProductId = "DynamicsBCLast",
    [ValidateSet("SQLServer","AzureSQL")]
    [string] $SqlServerType = 'SQLServer',
    [switch] $SetupAutomatically,
    [string] $SqlConnectionString,
    [string] $Version = "v1.0"
)
{
    #Write
    Write-StartingSetupStatusText -StatusTextColor "Yellow"

    $response = Setup-CloudMigration -UserName $UserName -Password $Password -ProductId $ProductId -SqlServerType $SqlServerType -SqlConnectionString $SqlConnectionString -Version $Version 
    Write-Host "Recieved integration runtime key"
    
    if((-not $response) -or (-not $response.runtimeKey))
    {
        Write-ErrorStatusText
        Write-Host 'Failed to setup cloud migration' -ForegroundColor Red
        return
    }

    if(-not $SetupAutomatically)
    {
        while(($inputCharacter -ne 'y') -and ($inputCharacter -ne 'n'))
        {    
            $inputCharacter = Read-Host -Prompt ('Setup Integration Runtime with following key: ' + $response.runtimeKey + ' Press y to coninue, n to abort')
            $inputCharacter = $inputCharacter.ToLower();
        }

        if($input -eq 'n')
        {
            return
        }
    }
    else
    {
        Write-ConfiguringIntegrationRuntimeStatusText -StatusTextColor "Yellow"
        Sleep -Seconds 2
        Write-Host "Updating integraiton runtime with new setup key"
        
        & $script:IntegrationRuntimeInstallationPath -gatewayKey ($response.runtimeKey)
        Sleep -Seconds 120
    }
    
    Write-Host ([datetime]::Now) "Completing the setup of Cloud Migration" -ForegroundColor Green
    Setup-CloudMigration -UserName $UserName -Password $Password -ProductId $ProductId -SqlServerType $SqlServerType -SqlConnectionString $SqlConnectionString -Version $Version -RuntimeName $response.runtimeName
    Complete-CloudMigrationSetup -UserName $UserName -Password $Password -Version $Version

    Write-Host ([datetime]::Now) "Completed the Setup"
}


<#
This function creates the OnPrem companies in the SaaS environment. 
This automation allows you to create companies in batches.
Batches are needed if there is more than 5-10 companies to be migrated. 
You can specify $ExcludedCompanies. 
#>
function Create-CompaniesInBatches
(
    [int] $BatchSize = $script:MaxNumberOfCompaniesToMoveAtOnce,
    [string] $UserName,
    [string] $Password,
    [System.Collections.ArrayList] $CompaniesToCreate = [System.Collections.ArrayList]::new(),
    [System.Collections.ArrayList] $ExcludedCompanies = [System.Collections.ArrayList]::new(),
    [string] $Version = "v1.0"
)
{
    $response =  Get-OnPremCompanies -UserName $UserName -Password $Password -Version $Version
    $onPremCompanies = $response.value
    
    $i = 0;
    $batchCount = 0;
    $batchNumber = 1;

    while($i -lt $onPremCompanies.Count)
    {   
        if($batchCount -eq 0)
        {
            Mark-CompaniesForReplication -UserName $UserName -Password $Password -Replicate $false -Version $Version
        }

        if($onPremCompanies[$i].status -ne 'Completed')
        {
            $excludeCompany = $ExcludedCompanies.Contains($onPremCompanies[$i].name)
            if(-not $excludeCompany)
            {
                if($CompaniesToCreate.Count -gt 0)
                {
                    $excludeCompany = -not ($CompaniesToCreate.Contains($onPremCompanies[$i].name))
                }
            }

            if (-not $excludeCompany)
            {
                Update-ReplicatePropertyForCompany -Id $onPremCompanies[$i].id -Replicate $true
                $batchCount++;
            }
        }
        else
        {
            Write-Host ([datetime]::Now) "Company $($onPremCompanies[$i].name) is created"
        }

        $i++
        if(($batchCount -eq $BatchSize) -or ($i -eq $onPremCompanies.Count))
        {
             Create-CreateCompaniesMarkedForReplication -UserName $UserName -Password $Password -Version $Version
             Wait-ForCompaniesToBeCreated -UserName $UserName -Password $Password -ExcludedCompanies $ExcludedCompanies -Version $Version
             if($batchCount -gt 0)
             {
                Write-Host ([datetime]::Now) "Processed Batch $batchNumber" -ForegroundColor Green
             }
             
             $batchCount = 0;
             $BatchNumber += 1;
        }
    }

    Mark-CompaniesForReplication -UserName $UserName -Password $Password -Replicate $false -Version $Version        
}



<# DATA REPLICATION
#function Move-CompaniesInBatches
This function will replicate the data from the the OnPrem companies to companies in the SaaS environment. 
#>

function Move-CompaniesInBatches
(
    [int] $BatchSize = $script:MaxNumberOfCompaniesToMoveAtOnce,
    [string] $UserName,
    [string] $Password,
    [System.Collections.ArrayList] $CompaniesToMove = [System.Collections.ArrayList]::new(),
    [System.Collections.ArrayList] $ExcludedCompanies = [System.Collections.ArrayList]::new(),
    [string] $Version = "v1.0"
)
{
    $response = Get-OnPremCompanies -UserName $UserName -Password $Password -Version $Version
    $onPremCompanies = $response.value

    $i = 0;
    $batchCount = 0;
    $batchNumber = 1;
    
    while($i -lt $onPremCompanies.Count)
    {
        if($batchCount -eq 0)
        {
            Mark-CompaniesForReplication -UserName $UserName -Password $Password -Replicate $false -Version $Version
        }

        $excludeCompany = $ExcludedCompanies.Contains($onPremCompanies[$i].name)
        if(-not $excludeCompany)
        {
            if($CompaniesToMove.Count -gt 0)
            {
                $excludeCompany = -not ($CompaniesToMove.Contains($onPremCompanies[$i].name))
            }
        }

        if (-not $excludeCompany)
        {
            Update-ReplicatePropertyForCompany -Id $onPremCompanies[$i].id -Replicate $true
            $batchCount++;
        }

        $i++
        $replicationSucessful = $false
        $numberOfAttempts = 1   
        
        if(($batchCount -eq $BatchSize) -or ($i -eq $onPremCompanies.Count))
        {
            while((-not $replicationSucessful) -and ($numberOfAttempts -lt $script:GetReplicationRetryAttempts))
            {
                try
                {
                    Write-Host ([datetime]::Now) "Moving batch $batchNumber"                    
                    Run-Replication -UserName $UserName -Password $Password -Version $Version
                    $result = Wait-ForReplicationToComplete -UserName $UserName -Password $Password -Version $Version
                    if(($result.status -eq 'Failed') -or ($result.tablesFailed -gt 0))
                    {
                        $numberOfAttempts++
                        $replicationSucessful = $false

                        Write-ErrorStatusText 
                        Write-Host ([datetime]::Now) "The replication has failed" -ForegroundColor Red

                        if($result.details -ne '')
                        {
                            Write-Host "Additoional details: $($result.details)"
                        }

                        if ($result.tablesFailed -gt 0)
                        { 
                            Write-Host "There were $($result.tablesFailed) failed tables in the run" -ForegroundColor Red
                        }

                        if($numberOfAttempts -lt $script:GetReplicationRetryAttempt)
                        {
                            Write-Host "Replication will be run again for this batch in the attempt to fix the errors" -ForegroundColor Red
                        }
                        else
                        {
                            Write-Host "Batch has failed. Script will attempt to process other batches" -ForegroundColor Red
                            $batchFailed = $true
                        }
                    }
                    else
                    {
                        $batchCount = 0;
                        $batchNumber += 1;
                        $replicationSucessful = $true
                    } 
                }
                catch
                {
                    Write-ErrorStatusText
                    Write-Error $Error[0]
                    if($numberOfAttempts -lt $script:GetReplicationRetryAttempt)
                    {
                        Write-Host "Replication will be run again for this batch in the attempt to fix the errors" -ForegroundColor Red
                    }
                    else
                    {
                        Write-Host "Batch has failed. Script will attempt to process other batches" -ForegroundColor Red
                        $batchFailed = $true
                    }

                    $numberOfAttempts++
                }
            }
        }
    }

    return (-not $batchFailed)
}


<# DATA UPGRADE 
function Run-DataUpgrade
This function will start the data upgrade. UI Equivalent is Run Data Upgrade Now action from Cloud Migration Management page.
#>
function Run-DataUpgrade
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 

    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    if($response.status -ne 'Upgrade Pending')
    {
        throw ("Status must be Upgrade Pending. Current status is: " + $response.status)
    }

    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    return (Invoke-RunDataUpgradeAction -Token $Token -Id $response.id)
}


<# DISABLE CLOUD MIGRATION
function Disable-CloudMigration
This function will Disable the cloud migration. UI Equivalent is Disable Cloud Migration action on the Cloud Migration Management page.
#>

function Disable-CloudMigration
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 
    
    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    Invoke-DisableCloudMigrationAction -Token $Token -Id $response.id
    Write-Host ([datetime]::Now) "Disabled Cloud Migration"
}


<# WAIT FOR COMPLETITION
function Wait-ForUpgradeToComplete
This function will wait for the upgrade to complete.
#>
function Wait-ForUpgradeToComplete
(
    [string] $UserName,
    [string] $Password,
    [string] $PreviousRequestId,
    [string] $Version = "v1.0"
)
{
    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version

    while(($response.status -eq 'Upgrade in Progress') -or ($response.status -eq 'Upgrade Pending'))
    {
        Write-Host ([datetime]::Now) "Waiting for Upgrade to complete"
        sleep -Seconds $script:GetStatusSleepSeconds
        $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
        Invoke-RefreshStatusAction -Token $Token -Id $response.id
        $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    }

    return $response
}


#mark companies replcation
#function Mark-CompaniesForReplication
function Mark-CompaniesForReplication
(
    [string] $UserName,
    [string] $Password,
    [boolean] $Replicate = $true,
    [System.Collections.ArrayList] $ExcludedCompanies = [System.Collections.ArrayList]::new(),
    [string] $Version = "v1.0"
)
{
    Setup-EnvironmentVariables -UserName $UserName -Password $Password
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    
    $response = Invoke-GetMethod -Uri $script:CloudMigrationCompanyURL -Token $Token
    for($i=0; $i -lt $response.value.count; $i++)
    {
        if (!$ExcludedCompanies.Contains($response.value[$i].name))
        {
            if($Replicate -ne $response.value[$i].replicate)
            {
                Update-ReplicatePropertyForCompany -Id $response.value[$i].id -Replicate $Replicate
            }
        }
    }
}

#create compnanies marked for replication
#function Create-CreateCompaniesMarkedForReplication
function Create-CreateCompaniesMarkedForReplication
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    Setup-EnvironmentVariables -UserName $UserName -Password $Password
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    $response = Invoke-GetMethod -Uri $script:CloudMigrationCompanyURL -Token $Token

    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Invoke-CreateCompaniesMarkedForReplication -Token $Token -Id $response.value[0].id
}


function Wait-ForCompaniesToBeCreated
(
    [string] $UserName,
    [string] $Password,
    [System.Collections.ArrayList] $ExcludedCompanies = [System.Collections.ArrayList]::new(),
    [string] $Version = "v1.0"
)
{
    $creationCompaniesSuccessful = $true
    Setup-EnvironmentVariables -UserName $UserName -Password $Password
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    
    $response = Invoke-GetMethod -Uri $script:CloudMigrationCompanyURL -Token $Token
    for($i=0; $i -lt $response.value.count; $i++)
    {
        if($response.value[$i].replicate)
        {
            while((!$response.value[$i].status) -or ($response.value[$i].status -eq " ") -or ($response.value[$i].status -eq "In Progress"))
            {
                $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
                $response = Invoke-GetMethod -Uri $script:CloudMigrationCompanyURL -Token $Token
                if ($response.value[$i].status -ne 'Completed')
                {
                    Write-Host ([datetime]::Now) "Waiting for the" $response.value[$i].name "company to be created, current status is:"  $response.value[$i].status
                    sleep -Seconds $script:GetCreateCompanySleepSeconds
                }
            }

            if ($response.value[$i].status -ne 'Completed')
            {
                Write-Host ([datetime]::Now) 'Company ' $response.value[$i].name 'was not successful. Status: ' $response.value[$i].status
                $creationCompaniesSuccessful = $false
            }
        }
    }

    return $creationCompaniesSucced
}


# properties
#function Update-ReplicatePropertyForCompany
function Update-ReplicatePropertyForCompany
(
    [string] $Id,
    [boolean] $Replicate,
    [string] $Etag = "*"
)
{
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
                
     $requestBody = @{
        replicate = $Replicate;
    }

    $result = Invoke-PatchMethod -Uri "$script:CloudMigrationCompanyURL($id)" -Token $Token -Etag $Etag -Body $requestBody
    if($result.name)
    {
        if($result.replicate)
        {
            Write-Host ([datetime]::Now) "Included $($result.name) company in replication"
        }
        else
        {
            Write-Host ([datetime]::Now) "Excluded $($result.name) company from replication"
        }
    }   
}

#setup cloud-migration
#function Setup-CloudMigration
function Setup-CloudMigration
(
    [string] $UserName,
    [string] $Password,
    [ValidateSet("DynamicsBCLast","DynamicsBC","DynamicsGP")]
    [string] $ProductId = "DynamicsBCLast",
    [ValidateSet("SQLServer","AzureSQL")]
    [string] $SqlServerType = 'SQLServer',
    [string] $SqlConnectionString,
    [string] $Version = "v1.0",
    [string] $RuntimeName = ''
)
{
    Setup-EnvironmentVariables -UserName $UserName -Password $Password
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    $exisitngSetup = Invoke-GetMethod $script:SetupCloudMigrationURL -Token $Token
    $requestBody = @{
        productId = $ProductId;
        sqlServerType = $SqlServerType;
        sqlConnectionString = $SqlConnectionString;
        runtimeName = $RuntimeName;
    }

    if($exisitngSetup.value)
    {
        $response = Invoke-PatchMethod -Uri (($script:SetupCloudMigrationURL) + "(" + ($exisitngSetup.value.id) + ")") -Token $Token -Etag "*" -Body $requestBody 
    }
    else
    {
        $response = Invoke-PostMethod -Uri $script:SetupCloudMigrationURL -Token $Token -Body $requestBody 
    }

    return $response
}


#complete cloud-migratsion setup
#function Complete-CloudMigrationSetup
function Complete-CloudMigrationSetup
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    Write-Host ([datetime]::Now) "Invoking complete setup action"
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 
    
    $exisitngSetup = Invoke-GetMethod $script:SetupCloudMigrationURL -Token $Token
    Invoke-CompleteSetupAction -Token $Token -Id $exisitngSetup.value.id
}


#wait for replication completition
#Wait-ForReplicationToComplete
function Wait-ForReplicationToComplete
(
    [string] $UserName,
    [string] $Password,
    [string] $PreviousRequestId,
    [string] $Version = "v1.0"
)
{
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 

    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    while($response.id -eq $PreviousRequestId)
    {
        $attepmts += 1;
        sleep -Seconds $script:GetStatusSleepSeconds
        $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    }

    while(($response.status -ne 'Completed') -and ($response.status -ne 'Failed') -and ($response.status -ne 'Upgrade Pending'))
    {
        sleep -Seconds $script:GetStatusSleepSeconds
        $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
        Invoke-RefreshStatusAction -Token $Token -Id $response.id
        $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
        Write-Host ([datetime]::Now) "Replication Status is $($response.status). Tables Remaining: $($response.tablesRemaining). Tables succesful: $($response.tablesSuccessful). Tables failed: $($response.tablesFailed)"
    }

    return $response
}



# *** RS,  Run replication changed
#function Run-Replication
function Run-Replication
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 

    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
    if($response.status -eq 'In Progress')
    {
      Write-Host  ([datetime]::Now)  'Replication is already in progress' -ForegroundColor Yellow
	  return $response
    }

    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Invoke-RunReplicationAction -Token $Token -Id $response.id
    $response = Get-LastStatusRecord -UserName $UserName -Password $Password -Version $Version
}



#function Get-OnPremCompanies
function Get-OnPremCompanies
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    Setup-EnvironmentVariables -UserName $UserName -Password $Password
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    return Invoke-GetMethod -Uri $script:CloudMigrationCompanyURL -Token $Token
}

function Get-LastStatusRecord
(
    [string] $UserName,
    [string] $Password,
    [string] $Version = "v1.0"
)
{
    $Token = Get-AADToken -UserName $UserName -Password $Password -Version $Version
    Setup-EnvironmentVariables -UserName $UserName -Password $Password 

    $response = Invoke-GetMethod -Token $Token -Uri ($script:CloudMigrationStatusURL + '?$orderby=startTime%20desc&$top=1') 
    return ($response.value)
}

#function Get-Companies
function Get-Companies
(
    [string] $UserName,
    [string] $Password
)
{
    $token = Get-AADToken -UserName $UserName -Password $Password
    return Invoke-GetMethod -Uri $script:companiesAPI -Token $token
}

function Invoke-InstalledIntegrationRuntime
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:SetupCloudMigrationURL($Id)/Microsoft.NAV.installedIntegrationRuntime" -Token $Token
}

function Invoke-CompleteSetupAction
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:SetupCloudMigrationURL($Id)/Microsoft.NAV.completeSetup" -Token $Token
}

function Invoke-RunReplicationAction
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationStatusURL($Id)/Microsoft.NAV.runReplication" -Token $Token
}


function Invoke-CreateCompaniesMarkedForReplication
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationCompanyURL($Id)/Microsoft.NAV.createCompaniesMarkedForReplication" -Token $Token
}


function Invoke-CreateCompny
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationStatusURL($Id)/Microsoft.NAV.createCompany" -Token $Token
}

function Invoke-RefreshStatusAction
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationStatusURL($Id)/Microsoft.NAV.refreshStatus" -Token $Token
}

function Invoke-RunDataUpgradeAction
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationStatusURL($Id)/Microsoft.NAV.runDataUpgrade" -Token $Token
}

function Invoke-DisableCloudMigrationAction
(
[string] $Token,
[string] $Id
)
{
    return Invoke-BoundAction -Uri "$script:CloudMigrationStatusURL($Id)/Microsoft.NAV.disableReplication" -Token $Token
}

function Setup-EnvironmentVariables
(
    [string] $UserName,
    [string] $Password,
    [string] $CompanyName = 'CRONUS'
)
{
    $token = Get-AADToken -UserName $UserName -Password $Password
    Set-APIURLs -Token $token -CompanyName $CompanyName
}


#
#function Set-APIURLs
function Set-APIURLs
(
[string] $Token,
[string] $CompanyName
)
{
    $script:CompaniesAPI = $script:ApiBaseUrl + "companies"

    if(-not $script:MainCompanyId)
    {
        $Response = Invoke-GetMethod -Uri ($script:CompaniesAPI + "/?`$filter=name%20eq%20'" + $CompanyName + "*'") -Token $Token
        if (@($Response.value).Count -le 1)
        {
            $script:MainCompanyId = $Response.value.id
        }
        else
        {
            $script:MainCompanyId = $Response.value[0].id
        }
    }

    Update-ApiUrls -CompanyId $script:MainCompanyId
}

function Update-ApiUrls
(
[string] $CompanyId
)
{
    $script:CloudMigrationURL = $script:ApiBaseUrl + "companies(" + $CompanyId + ")"
    $script:CloudMigrationCompanyURL = "$script:CloudMigrationURL/cloudMigrationCompanies"
    $script:CloudMigrationStatusURL = "$script:CloudMigrationURL/cloudMigrationStatus"
    $script:SetupCloudMigrationURL = "$script:CloudMigrationURL/setupCloudMigration"
}

function Get-AADToken 
(
[string] $UserName = $script:CurrentUserName,
[string] $Password = $script:CurrentPassword,
[string] $AADTenantID = $script:AADTenantID,
[string] $Version = "v1.0"
)
{
    if($script:TokenExpirationTime)
    {
        if ($script:TokenExpirationTime -gt (Get-Date))
        {
            return $script:CurrentToken
        }
    }

    try
    {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $UserCredential = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)
        $AuthenticationResult = Get-MsalToken -ClientId $script:ClientId -RedirectUri $script:RedirectUri -TenantId $AADTenantID -Authority $script:AuthorityUri -UserCredential $UserCredential -Scopes $script:BcScopes
    }
    catch {
       $AuthenticationResult =  Get-MsalToken -ClientId $script:ClientId -RedirectUri $script:RedirectUri -TenantId $AADTenantID -Authority $script:AuthorityUri -Prompt SelectAccount -Scopes $script:BcScopes
    }

    $script:CurrentToken =  $AuthenticationResult.AccessToken;
    
    $script:TokenExpirationTime = ($AuthenticationResult.ExpiresOn - (New-TimeSpan -Minutes 3))
    return $AuthenticationResult.AccessToken;
}


#Invoke API
function Invoke-GetMethod
(
[string] $Uri,
[string] $Token
)
{
    try
    {
        $response = Invoke-RestMethod -Method GET -Uri $Uri -Headers (Create-AuthorizationHeader -Token $Token)
    }
    catch
    {
        Write-APIError -Uri $Uri -ExceptionObject $_.Exception
    }

    return $response
}

#Invoke Invoke BoundAction
function Invoke-BoundAction
(
[string] $Uri,
[string] $Token,
[int] $TimeoutSec = 60*10
)
{
    $headers = Create-AuthorizationHeader -Token $Token;
    try
    {
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $headers -ContentType "" -TimeoutSec $TimeoutSec
    }
    catch
    {
        Write-APIError -Uri $Uri -ExceptionObject $_.Exception
    }

    return $response
}

#Invoke Post
function Invoke-PostMethod
(
[string] $Uri,
[string] $Token,
$Body, 
[int] $TimeoutSec = 60 * 10
)
{
    $headers = Create-AuthorizationHeader -Token $Token;

    try
    {
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $headers -Body (convertto-json $Body) -ContentType "application/json" -TimeoutSec $TimeoutSec
    }
    catch
    {
        Write-APIError -Uri $Uri -ExceptionObject $_.Exception
    }

    return $response
}

function Invoke-PatchMethod
(
[string] $Uri,
[string] $Token,
[string] $Etag = '*',
[int] $TimeoutSec = 60 * 10,
$Body
)
{
    $headers = Create-AuthorizationHeader -Token $Token;
    $headers['If-Match'] = $Etag;
    try
    {
        $response = Invoke-RestMethod -Method PATCH -Uri $Uri -Headers $headers -Body (convertto-json $Body) -ContentType "application/json" -TimeoutSec $TimeoutSec
    }
    catch
    {
        Write-APIError -Uri $Uri -ExceptionObject $_.Exception
    }

    return $response
}


#Invoke Delete
function Invoke-DeleteMethod
(
[string] $Uri,
[string] $Token,
[string] $Etag = '*',
$Body
)
{
    $headers = Create-AuthorizationHeader -Token $Token;
    $headers['If-Match'] = $Etag;
    
    try
    {
        $response = Invoke-RestMethod -Method DELETE -Uri $Uri -Headers $headers -Body (convertto-json $Body) -ContentType "application/json";
    }
    catch
    {
        Write-APIError -Uri $Uri -ExceptionObject $_.Exception
    }

    return $response
}


#Write API error
function Write-APIError
(
    [string] $Uri,
    $ExceptionObject
)
{
        Write-ErrorStatusText 
        Write-Host ([datetime]::Now) "Failed:" $Uri -ForegroundColor Red
        Write-Host "StatusCode:" $ExceptionObject.Response.StatusCode.value__  -ForegroundColor Red
        $responseStream = $ExceptionObject.Response.GetResponseStream()
        $responseStream.Position = 0;
        $streamReader = New-Object System.IO.StreamReader($responseStream)
        $errorMessage = $streamReader.ReadToEnd()
        $streamReader.Close()
        $responseStream.Close()

        Write-Host "Message: $errorMessage" -ForegroundColor Red
}


#CREATE AUTH CODE - OAUTH2.0 BEARER
function Create-AuthorizationHeader
(
[string] $Token
)
{
     return @{"Authorization"="Bearer " + $Token;}
}





# *************************************
# ***  LAUNCH CLOUD DATA MIGRATION  ***
# *************************************


# Chiamata a Cloud MIgration E2E - esempio da Cronus Local
Run-CloudMigrationE2E -SqlConnectionString "Server=BC22V2ITA\SQLEXPRESS;Database=CRONUS;UID=admin;PWD=P@ssw0rd;".





