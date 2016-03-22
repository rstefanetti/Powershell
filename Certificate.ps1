Set-ExecutionPolicy Unrestricted

# CERTIFICATE MANAGING - "SELF SIGNED" OR VERIFIED
$certificatePfxFile = Get-UserInput -Id CertificatePfxFile -Text "Certificate Pfx File (Empty for using Self Signed Certificate)" 
$selfsigned = (!$certificatePfxFile)
if ($selfsigned) {
    $certificatePfxFile = Join-Path $PSScriptRootV2 'Certificate.pfx'
    $certificatePfxPassword = 'P@ssword1'
    if (!(Test-Path $certificatePfxFile)) {
        New-SelfSignedCertificateEx -Subject "CN=$CloudServiceName" -IsCA $true -Exportable -Path $certificatePfxFile -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force)
    }
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
    $CertificateCerFile = (Join-Path $PSScriptRootV2 "$CloudServiceName.cer")
    Export-Certificate -Cert $cert -FilePath $CertificateCerFile
    Copy-Item $CertificateCerFile -Destination "C:\Users\Public\Desktop\$CloudServiceName.cer"
    Copy-Item $CertificateCerFile -Destination "C:\inetpub\wwwroot\http\Certificate.cer"
    $thumbprint = $cert.Thumbprint
    if (!(Get-Item Cert:\LocalMachine\my\$thumbprint -ErrorAction SilentlyContinue)) {
        Import-PfxFile -PfxFile $certificatePfxFile -PfxPassword (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force)
    }
} else {
    $certificatePfxPassword = Get-UserInput -Id CertificatePfxPassword -Text "Certificate Pfx Password" 
    # Import certificate
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
    $thumbprint = $cert.Thumbprint
    if (!(Get-Item Cert:\LocalMachine\my\$thumbprint -ErrorAction SilentlyContinue)) {
        Import-PfxCertificate -FilePath $certificatePfxFile -CertStoreLocation cert:\localMachine\my -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force)
        
        $certistrusted = $true
        try {
            $certistrusted = Test-Certificate –Cert "cert:\currentuser\my\$thumbprint" -Policy SSL
        } catch {
            $certistrusted = $false
        }
        if (!$certistrusted) {
            # Self signed certificate created on another machine (for load balancing purposes)
            Import-PfxCertificate -FilePath $certificatePfxFile -CertStoreLocation cert:\localMachine\root -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force)
        }
    }
}

$dnsidentity = $cert.GetNameInfo('SimpleName',$false)
if ($dnsidentity.StartsWith('*')) {
    $dnsidentity = $dnsidentity.Substring($dnsidentity.IndexOf('.')+1)
}

if ($selfsigned) {
    $PublicMachineName = $CloudServiceName
} else {
    # Public DNS name
    $PublicMachineName = ($CloudServiceName.Split('.')[0] + ".$dnsidentity")
    $PublicMachineName = Get-UserInput -Id PublicMachineName -Text "What DNS name points to your service" -Default $PublicMachineName
    
    if ($PublicMachineName -ne $CloudServiceName) {
        $dnsrecord = Resolve-DnsName $PublicMachineName -ErrorAction SilentlyContinue -Type CNAME
        if (!($dnsrecord) -or ($dnsrecord.Type -ne "CNAME") -or ($dnsrecord.NameHost -ne $CloudServiceName)) {
            Write-Host -ForegroundColor Red "You need to create a CNAME record for $PublicMachineName that points to $CloudServiceName"
            Start-Sleep -Seconds 30
        }
    }
}
