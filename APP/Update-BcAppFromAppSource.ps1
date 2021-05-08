#UPDATE APP
function Update-BcAppFromAppSource {
    Param (
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$true)]
        [string] $appId,
        [string] $ToNewAppVersion,
        [string] $languageId,
        [switch] $acceptIsvEula,
        [switch] $installOrUpdateNeededDependencies,
        [switch] $allowInstallationOnProduction
    )
         
    
    #token refresh
    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $environment }
    
    if (!$bcEnvironment) {
        throw "Environment $environment doesn't exist in the current context."
        }
    
    if ($bcEnvironment.Type -eq 'Production' -and !$allowInstallationOnProduction) {
        throw "If you want to install an app in a production environment, you need to specify -allowInstallOnProduction"
        }    
 
    
    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
        
    
    #UPDATE
    $body = @{ "targetversion" = $ToNewAppVersion }
    #$operation = Invoke-RestMethod -Method Post -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.6/applications/BusinessCentral/environments/$environment/apps/$appId/update" -Headers $headers -ContentType "application/json" -Body ($body | ConvertTo-Json)

    if ($appVersion) { $body += @{ "targetVersion" = $appVersion } }
    if ($languageId) { $body += @{ "languageId" = $languageId } }
    #if ($installOrUpdateNeededDependencies) { $body += @{ "installOrUpdateNeededDependencies" = $installOrUpdateNeededDependencies.ToBool() } }
    

    #Updating App
    Write-Host "Updating $appId $appVersion on $($environment)"
    $operation = Invoke-RestMethod -Method Post -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.6/applications/BusinessCentral/environments/$environment/apps/$appId/update" -Headers $headers -ContentType "application/json" -Body ($body | ConvertTo-Json)
  
    Write-Host "Operation ID $($operation.id)"
    $status = $operation.status

    Write-Host -NoNewline "$($status)."
    $completed = $operation.Status -eq "succeeded"
    $errCount = 0         
       
        
}

