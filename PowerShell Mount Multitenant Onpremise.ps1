

import-module "C:\Program Files\Microsoft Dynamics 365 Business Central\150\Service\NavAdminTool.ps1"

Import-NAVServerLicense -ServerInstance BC150 -LicenseFile C:\Download\LICBC15.flf
Restart-NAVServerInstance BC150 -Force
Export-NAVServerLicenseInformation BC150


Export-NAVApplication -DatabaseServer MVPDOCKER -DatabaseInstance BCDEMO -DatabaseName "Demo Database BC (15-0)" -DestinationDatabaseName "AppDB" -ServiceAccount 'MVPDOCKER\vmadmin' 

Remove-NAVApplication -DatabaseServer MVPDOCKER -DatabaseInstance BCDEMO -DatabaseName "Demo Database BC (15-0)" 


Set-NAVServerConfiguration BC150 -KeyName Multitenant -KeyValue True
Set-NAVServerConfiguration BC150 -KeyName DatabaseName -KeyValue AppDB
Set-NAVServerConfiguration BC150 -KeyName EnableTaskScheduler -KeyValue False
Restart-NAVServerInstance  BC150 -Force



Mount-NAVTenantDatabase BC150 -Id Default -DatabaseServer MVPDOCKER\BCDEMO -DatabaseName "Demo Database BC (15-0)" 
Mount-NAVTenant BC150 -TenantDatabaseId Default -Tenant Default


Sync-NAVTenant BC150 -Tenant Default -Mode Sync
Get-NAVTenant BC150



Mount-NAVTenantDatabase BC150 -Id ONPREM -DatabaseServer MVPDOCKER\BCDEMO -DatabaseName "PRODBSAAS152390600ITA" 
Mount-NAVTenant BC150 -TenantDatabaseId ONPREM -Tenant ONPREM -AllowAppDatabaseWrite -OverwriteTenantIdInDatabase -Force


Sync-NAVTenant BC150 -Tenant ONPREM -Mode Sync
Get-NAVTenant BC150


Import-NAVServerLicense -ServerInstance BC150 -LicenseFile C:\Download\LICBC15.flf -Tenant ONPREM
Restart-NAVServerInstance BC150 -Force
Export-NAVServerLicenseInformation BC150 -tenant ONPREM


Dismount-NAVTenantDatabase BC150 -Id ONPREM 








Export-NAVApplication -DatabaseServer MVPDOCKER -DatabaseInstance BCDEMO -DatabaseName "AppDB" -DestinationDatabaseName "PRODBSAAS152390600ITA" -ServiceAccount 'MVPDOCKER\vmadmin' 

Set-NAVServerConfiguration BC150 -KeyName Multitenant -KeyValue False
Set-NAVServerConfiguration BC150 -KeyName DatabaseName -KeyValue PRODBSAAS152390600ITA
Set-NAVServerConfiguration BC150 -KeyName EnableTaskScheduler -KeyValue False
Restart-NAVServerInstance  BC150 -Force


Sync-NAVTenant BC150 -Tenant Default -Mode Sync
Get-NAVTenant BC150


New-NAVServerUser BC150 -UserName MVPDOCKER\vmadmin -FullName vmadmin 
New-NAVServerUserPermissionSet BC150 -UserName MVPDOCKER\vmadmin -PermissionSetId SUPER



New-NAVServerUser BC150 -WindowsAccount  MVPDOCKER\vmadmin -FullName vmadmin 
New-NAVServerUserPermissionSet BC150 -UserName MVPDOCKER\vmadmin -PermissionSetId SUPER

