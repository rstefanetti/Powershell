#MULTI APPS INSTALL - BC18

$ServicePath = 'C:\Program Files\Microsoft Dynamics 365 Business Central\180\Service\'
$ServiceName = 'BC180'
$Publisher = 'RS'

$ErrorActionPreference = "Stop"
$BaseApppath = "$($PSScriptRoot)\"

#Requires -RunAsAdministrator
Import-Module ($ServicePath + 'Microsoft.Dynamics.Nav.Management.dll') -ErrorVariable errorVariable -WarningAction SilentlyContinue | Out-Null
Import-Module ($ServicePath + 'Microsoft.Dynamics.Nav.Model.Tools.dll') -ErrorVariable errorVariable -WarningAction SilentlyContinue | Out-Null
Import-Module ($ServicePath + 'Microsoft.Dynamics.Nav.Apps.Management.dll') -ErrorVariable errorVariable -WarningAction SilentlyContinue | Out-Null

function Remove ($_AppVersion)
{
    if ($_AppVersion) {
        $ExtensionsToRemove = Get-NAVAppInfo -ServerInstance $ServiceName | where {($_.Name -eq "$AppName") -and ($_.Version -eq $_AppVersion)}
    } else {
        $ExtensionsToRemove = Get-NAVAppInfo -ServerInstance $ServiceName | where {($_.Name -eq "$AppName")}
    }
    if ($ExtensionsToRemove) {
        foreach ($ExtensionToRemove in $ExtensionsToRemove) {
            Write-Host Uninstalling app "$AppName" version $ExtensionToRemove.version ...
            Uninstall-NAVApp -ServerInstance $ServiceName -Name $AppName -Version $ExtensionToRemove.version
            Unpublish-NAVApp -ServerInstance $ServiceName -Name $AppName -Version $ExtensionToRemove.version
        }
    } else {Write-Host $AppName not found, skipping...}
}

function RemoveDependencies ($_Dependencies)
{
    $tmpAppName = $AppName
    Write-Host Removing dependencies for $AppName : $_Dependencies
    foreach ($Dependency in $_Dependencies){
        $AppName = $Dependency
        Remove
    }
    $AppName = $tmpAppName
}

function Install
{
    Clear-Variable My*
    $NewAppPath = $BaseApppath + $Publisher + '_' + $AppName + '_' + $NewVersion + '.app'
    $MyOldExtensions = Get-NAVAppInfo -ServerInstance $ServiceName | where {($_.Name -eq "$AppName")}
    if ($MyOldExtensions) {
        $m = $MyOldExtensions | measure
        write-host Found $m.Count old versions: $MyOldExtensions.version
        foreach ($MyOldExtension in $MyOldExtensions) {
            Remove $MyOldExtension.version
        }
    }
    Write-Host Publishing $AppName version $NewVersion
    Publish-NAVApp -ServerInstance $ServiceName -Path $NewAppPath -SkipVerification -Force
    Sync-NAVTenant -ServerInstance $ServiceName -Force
    Sync-NAVApp -ServerInstance $ServiceName -Name $AppName -Version $NewVersion -Force

#    Sync-NAVApp -ServerInstance $ServiceName -Name $AppName -Version $NewVersion -Force -Mode ForceSync

    if ($MyOldExtension -and $MyOldExtension.version -ne $NewVersion) {
        Write-Host Upgrading $AppName version $MyOldExtension.version to version $NewVersion
        Start-NAVAppDataUpgrade -ServerInstance $ServiceName -Name $AppName -Version $NewVersion -Force
    }
    Install-NAVApp -ServerInstance $ServiceName -Name $AppName -Version $NewVersion -Force
}


#Esecuzione - esempio installazione di una APP togliendo le dipendenze
$AppName = 'NOME_APP'
$NewVersion = '1.0.0.3'
RemoveDependencies 'DEPENDENTAPP1','DEPENDENTAPP2'
Remove

