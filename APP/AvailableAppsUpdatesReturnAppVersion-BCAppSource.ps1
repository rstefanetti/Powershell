#Return Available APPS with Updates
function Get-BcAvailableAppsUpdatesReturnAppVersion {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory=$true)]
        [string] $environment
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
    try {
        (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.6/applications/$applicationFamily/environments/$environment/apps/availableUpdates" -Headers $headers).Value
    }
    catch {
        throw (GetExtenedErrorMessage $_.Exception)
    }
}


