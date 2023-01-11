function Export-TeamsProvider {
    <#
    .Description
    Gets the Teams settings that are relevant
    to the SCuBA Teams baselines using the Teams PowerShell Module
    .Functionality
    Internal
    #>
    [CmdletBinding()]

    #$HelperFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "ProviderHelpers"
    #Import-Module (Join-Path -Path $HelperFolderPath -ChildPath "CommandTracker.psm1")
    #$Tracker = Get-CommandTracker

    $TenantInfo = Get-CsTenant
    Write-Output $TenantInfo | ConvertTo-Json
    $MeetingPolicies = Get-CsTeamsMeetingPolicy | ConvertTo-Json
    $FedConfig = Get-CsTenantFederationConfiguration | ConvertTo-Json
    $ClientConfig = Get-CsTeamsClientConfiguration | ConvertTo-Json
    $AppPolicies = Get-CsTeamsAppPermissionPolicy | ConvertTo-Json
    $BroadcastPolicies = Get-CsTeamsMeetingBroadcastPolicy | ConvertTo-Json

    #$TeamsSuccessfulCommands = ConvertTo-Json @($Tracker.GetSuccessfulCommands())
    #$TeamsUnSuccessfulCommands = ConvertTo-Json @($Tracker.GetUnSuccessfulCommands())

    # Note the spacing and the last comma in the json is important
    $json = @"
    "teams_tenant_info": $TenantInfo,
    "meeting_policies": $MeetingPolicies,
    "federation_configuration": $FedConfig,
    "client_configuration": $ClientConfig,
    "app_policies": $AppPolicies,
    "broadcast_policies": $BroadcastPolicies,
    "teams_successful_commands": $TeamsSuccessfulCommands,
    "teams_unsuccessful_commands": $TeamsUnSuccessfulCommands,
"@

    # We need to remove the backslash characters from the
    # json, otherwise rego gets mad.
    $json = $json.replace("\`"", "'")
    $json = $json.replace("\", "")
    $json
}

function Get-TeamsTenantDetail {
    <#
    .Description
    Gets the M365 tenant details using the Teams PowerShell Module
    .Functionality
    Internal
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("commercial", "gcc", "gcchigh", "dod", IgnoreCase = $false)]
        [string]
        $M365Environment
    )
    # Need to explicitly clear or convert these values to strings, otherwise
    # these fields contain values Rego can't parse.
    try {
        $TenantInfo = Get-CsTenant -ErrorAction "Stop"

        $VerifiedDomains = $TenantInfo.VerifiedDomains
        $TenantDomain = "Teams: Domain Unretrievable"
        $TLD = ".com"
        if (($M365Environment -eq "gcchigh") -or ($M365Environment -eq "dod")) {
            $TLD = ".us"
        }
        foreach ($Domain in $VerifiedDomains.GetEnumerator()) {
            $Name = $Domain.Name
            $Status = $Domain.Status
            $DomainChecker = $Name.EndsWith(".onmicrosoft$($TLD)") -and !$Name.EndsWith(".mail.onmicrosoft$($TLD)") -and $Status -eq "Enabled"
            if ($DomainChecker) {
                $TenantDomain = $Name
            }
        }

        $TeamsTenantInfo = @{
            "DisplayName" = $TenantInfo.DisplayName;
            "DomainName" = $TenantDomain;
            "TenantId" = $TenantInfo.TenantId;
            "TeamsAdditionalData" = $TenantInfo;
        }
        $TeamsTenantInfo = ConvertTo-Json @($TeamsTenantInfo) -Depth 4
        $TeamsTenantInfo
    }
    catch {
        Write-Warning "Error retrieving Tenant details using Get-TeamsTenantDetail $($_)"
        $TeamsTenantInfo = @{
            "DisplayName" = "Error retrieving Display name";
            "DomainName" = "Error retrieving Domain name";
            "TenantId" = "Error retrieving Tenant ID";
            "TeamsAdditionalData" = "Error retrieving additional data";
        }
        $TeamsTenantInfo = ConvertTo-Json @($TeamsTenantInfo) -Depth 4
        $TeamsTenantInfo
    }
}


try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
    $token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
    #Write-Output ($token)
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

<#
#Get all ARM resources from all resource groups
$ResourceGroups = Get-AzResourceGroup

foreach ($ResourceGroup in $ResourceGroups)
{    
    Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
    $Resources = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName
    foreach ($Resource in $Resources)
    {
        Write-Output ($Resource.Name + " of type " +  $Resource.ResourceType)
    }
    Write-Output ("")
}
#>

try
{
    $Connection = Get-AutomationConnection -Name AzureRunAsConnection
    #Write-Output ($Connection)
    Connect-MgGraph -ClientID $Connection.ApplicationId -TenantId $Connection.TenantId -CertificateThumbprint $Connection.CertificateThumbprint
    Connect-MicrosoftTeams -CertificateThumbprint $Connection.CertificateThumbprint -ApplicationId $Connection.ApplicationId -TenantId $Connection.TenantId
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Get-AADTenantDetail
Export-TeamsProvider
