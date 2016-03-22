Set-ExecutionPolicy Unrestricted

$PSScriptRootV2 = "d:\Cert\Initialize\"
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Stop'

. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. ("d:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
Import-Module "d:\Cert\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
. (Join-Path $PSScriptRootV2 'New-SelfSignedCertificateEx.ps1')

$CustomSettingsConfigFile = 'd:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$NavServiceUser = Get-UserInput -Id NavAdminUser -Text "NAV Service Login" -Default "NT AUTHORITY\SERVIZIO DI RETE"

do
{
    $err = $false
    $CloudServiceName = Get-UserInput -Id CloudServiceName -Text "What is the name of your Cloud-Service" -Default "$env:COMPUTERNAME.nexus.local"
#    try
#    {
#        $myIP = Get-MyIp
#        $dnsrecord = Resolve-DnsName $CloudServiceName -ErrorAction SilentlyContinue -Type A
#        if (!($dnsrecord) -or ($dnsrecord.Type -ne "A") -or ($dnsrecord.IPAddress -ne $myIP)) {
#            Write-Host -ForegroundColor Red "That is NOT your Cloud Service Name (Did you name your Cloud Service something different from the Virtual Machine?)"
#            Write-Host -ForegroundColor Red "Please find the correct Cloud Service Name in the Azure Management Portal."
#            $err = $true
#        }
#    } 
#    catch {}
} while ($err)

# Create http directory
$httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
new-item -Path $httpWebSiteDirectory -ItemType Directory -Force

. (Join-Path $PSScriptRootV2 'Certificate.ps1')

# Grant Access to certificate to user running Service Tier
Grant-AccountAccessToCertificatePrivateKey -CertificateThumbprint $thumbprint -ServiceAccountName $NavServiceUser 


# Change configuration
Set-NAVServerConfiguration $serverInstance -KeyName "ServicesCertificateThumbprint" -KeyValue $thumbprint
#Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesSSLEnabled" -KeyValue 'true'
#Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesEnabled" -KeyValue 'true'
#Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesSSLEnabled" -KeyValue 'true'
#Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesEnabled" -KeyValue 'true'
#Set-NAVServerConfiguration $serverInstance -KeyName "PublicODataBaseUrl" -KeyValue ('https://' +$PublicMachineName + ':7048/' + $serverInstance + '/OData/')
#Set-NAVServerConfiguration $serverInstance -KeyName "PublicSOAPBaseUrl" -KeyValue ('https://' + $PublicMachineName + ':7047/' + $serverInstance + '/WS/')
Set-NAVServerConfiguration $serverInstance -KeyName "PublicWebBaseUrl" -KeyValue ('https://' + $PublicMachineName + '/' + $serverInstance + '/WebClient/')
#Set-NAVServerConfiguration $serverInstance -KeyName "PublicWinBaseUrl" -KeyValue ('DynamicsNAV://' + $PublicMachineName + ':7046/' + $serverInstance + '/')
#Set-NAVServerConfiguration $serverInstance -KeyName "ClientServicesCredentialType" -KeyValue "Windows"
#Set-NAVServerConfiguration $serverInstance -KeyName "ServicesDefaultCompany" -KeyValue $Company

# Restart NAV Service Tier
Set-NAVServerInstance -ServerInstance $serverInstance -Restart

# Add firewall rules for SOAP and OData
#netsh advfirewall firewall add rule name="Microsoft Dynamics NAV SOAP Services" dir=in action=allow protocol=tcp localport=7047 remoteport=any
#netsh advfirewall firewall add rule name="Microsoft Dynamics NAV OData Services" dir=in action=allow protocol=tcp localport=7048 remoteport=any
netsh advfirewall firewall add rule name="Microsoft Dynamics NAV Web Client SSL" dir=in action=allow protocol=tcp localport=443 remoteport=any

# Remove the default IIS WebSite
Remove-DefaultWebSite -ErrorAction SilentlyContinue

# Remove bindings from Web Client
Get-WebBinding -Name "Microsoft Dynamics NAV 2015 Web Client" | Remove-WebBinding

# Add SSL binding to Web Client
New-SSLWebBinding -Name "Microsoft Dynamics NAV 2015 Web Client" -Thumbprint $thumbprint

# Create HTTP site
if (!(Get-Website -Name http)) {
    # Create the web site
    Write-Verbose "Creating Web Site"
    New-Website -Name http -IPAddress * -Port 80 -PhysicalPath $httpWebSiteDirectory -Force
}
Copy-Item (Join-Path $PSScriptRootV2 'Default.aspx') "$httpWebSiteDirectory\Default.aspx" 
Copy-Item (Join-Path $PSScriptRootV2 'web.config') "$httpWebSiteDirectory\web.config" 

Write-Verbose "Opening Firewall"
New-FirewallPortAllowRule -RuleName "HTTP access" -Port 80

# Change Web.config
$WebConfigFile = "C:\inetpub\wwwroot\$serverInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
#$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='HelpServer']").value="$PublicMachineName"
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='DnsIdentity']").value=$dnsidentity
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='ClientServicesCredentialType']").value="Windows"
#$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='Company']").value=$Company
$WebConfig.Save($WebConfigFile)

# Turn off IE Enhanced Security Configuration
#Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74