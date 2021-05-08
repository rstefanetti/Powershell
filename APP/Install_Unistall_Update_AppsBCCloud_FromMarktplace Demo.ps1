#Based on APIs 2.0 Admin standard statements
#Content-Type: application/json - publish
#POST /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps/{appId}/publish

#Content-Type: application/json - install
#POST /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps/{appId}/install

#Content-Type: application/json -unistall
#POST /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps/{appId}/uninstall

#Content-Type: application/json -update
#POST /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps/{appId}/update

#APP e AGGIORNAMENTO DISPONIBILI
#GET /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps
#GET /admin/v2.6/applications/{applicationFamily}/environments/{environmentName}/apps/availableUpdates


 
# DEMO Unistall\Install\Update an APP on PRODUCTION Env.
#IMPORT MODULE EXTENSION FOR BCCONTAINERHELPER - INSTALL\UPDATE MODULES
Import-Module "C:\Powershell Script\Update-BcAppFromAppSource.ps1"
Import-Module "C:\Powershell Script\Unistall-BcAppFromAppSource.ps1"
Import-Module "C:\Powershell Script\AvailableAppsUpdates-BCAppSource.ps1"


#TOKEN, ENVIRONMENT, APPID E NAME
$authContext = New-BcAuthContext –includeDeviceLogin -verbose   #GET TOKEN
$environment = "Production"
$appId = "12233434545454545"  #GLLOBAL APP
$appName = "APP NAME"

#Read last version for a published APP
$AppName = Get-BcPublishedApps -bcAuthContext $authContext -environment $environment | Where-Object { $_.Name -eq "APP NAME" }  
echo $AppName

#Read last version for an available for uodate APP
$AppName = Get-BcAvailableAppsUpdates -bcAuthContext $authContext -environment $environment | Where-Object { $_.Name -eq "APP NAME" }  
echo $AppName


#Installed APP, ToUpdate APP
$InstalledAppVersion = "2.1.1.0"
$ToUpdateAppVersion = "2.1.1.1"  #TARGET APP


#STATEMENTS
#1) - UPDATE AN APP 
Update-BcAppFromAppSource `
    -appId $appId `
    -bcAuthContext $authContext `
    -environment $environment `
    -acceptIsvEula `
    -allowInstallationOnProduction `
    -ToNewAppVersion $ToUpdateAppVersion `
    -installOrUpdateNeededDependencies `
    -languageId 1040 `
    -verbose
        

#2) - UNISTALL AN APP
Uninstall-BcAppFromAppSource `
    -appId $appId `
    -bcAuthContext $authContext `
    -environment $environment `
    -acceptIsvEula `
    -allowInstallationOnProduction `
    -appVersion $InstalledAppVersion `
    -installOrUpdateNeededDependencies `
    -languageId 1040 `
    -verbose


#3) - INSTALL AN APP
Install-BcAppFromAppSource `
    -appId $appId `
    -bcAuthContext $authContext `
    -environment $environment `
    -acceptIsvEula `
    -allowInstallationOnProduction `
    -appVersion $InstalledAppVersion `
    -installOrUpdateNeededDependencies `
    -languageId 1040 `
    -verbose