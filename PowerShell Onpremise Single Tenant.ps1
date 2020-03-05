#Load Admin Tool
import-module "C:\Program Files\Microsoft Dynamics 365 Business Central\150\Service\NavAdminTool.ps1"


#Single-tenant Scenario - 01 - FAST

#Upload license
Import-NAVServerLicense -ServerInstance BC150 -LicenseFile C:\Download\LICBC15.flf
Restart-NAVServerInstance BC150 -Force
Export-NAVServerLicenseInformation BC150

#Export NAVAPP
Export-NAVApplication -DatabaseServer MVPDOCKER -DatabaseInstance BCDEMO -DatabaseName "AppDB" -DestinationDatabaseName "PRODBSAAS152390600ITA" 
-ServiceAccount 'MVPDOCKER\vmadmin' 

#Set Single Tenant
Set-NAVServerConfiguration BC150 -KeyName Multitenant -KeyValue False
Set-NAVServerConfiguration BC150 -KeyName DatabaseName -KeyValue PRODBSAAS152390600ITA
Set-NAVServerConfiguration BC150 -KeyName EnableTaskScheduler -KeyValue False
Restart-NAVServerInstance  BC150 -Force

#Sync tenant
Sync-NAVTenant BC150 -Tenant Default -Mode Sync
Get-NAVTenant BC150

#Create NAV User
New-NAVServerUser BC150 -WindowsAccount  MVPDOCKER\vmadmin -FullName vmadmin 
New-NAVServerUserPermissionSet BC150 -UserName MVPDOCKER\vmadmin -PermissionSetId SUPER



#Dismount-NAVTenantDatabase BC150 -Id ONPREM 