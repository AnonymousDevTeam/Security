﻿#>

####################################################

function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

    $tenant = $userUpn.Host


    Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }
    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    if($AadModule.count -gt 1){
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

            # Checking if there are multiple versions of the same module found
            if($AadModule.count -gt 1){
            $aadModule = $AadModule | select -Unique
            }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    else {
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null

    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $clientId = "e0d61854-77b1-48d5-872c-2595ef70b3db"

    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"

    $resourceAppIdURI = "https://graph.microsoft.com"

    $authority = "https://login.microsoftonline.com/$Tenant"

    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        # If the accesstoken is valid then create the authentication header
        if($authResult.AccessToken){

            # Creating header for Authorization token
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $authResult.AccessToken
                'ExpiresOn'=$authResult.ExpiresOn
                }
            return $authHeader
        }
        else {
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
        }
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    }
}

####################################################

Function Get-TopAlerts(){

<#
.SYNOPSIS
This function is used to get the top 1 alert from the Graph Security API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets the top 1 alert from Security API provider
.EXAMPLE
Get-TopAlerts
Returns any top 1 alert from each Security API provider
.NOTES
NAME: Get-TopAlerts
#>

[cmdletbinding()]

    $graphApiVersion = "v1.0"
    $Resource = "security/alerts?`$top=1"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
    } 
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
}

####################################################


Function Get-Alert{

<#
.SYNOPSIS
This function is used to get the alert by ID from the Graph Security API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets an alert by ID from the Microsoft Graph Security API
.EXAMPLE
Get-Alert
Returns the alert from Security API with the provided ID
.NOTES
NAME: Get-Alert
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $ID
)

    $graphApiVersion = "v1.0"
    $Resource = "security/alerts/$ID"
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
    } 
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
}

####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if($TokenExpires -le 0){
        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

        # Defining User Principal Name if not present
        if($User -eq $null -or $User -eq ""){
            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host
        }
        $global:authToken = Get-AuthToken -User $User
    }
}
# Authentication doesn't exist, calling Get-AuthToken function
else {
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }

# Getting the authorization token
$global:authToken = Get-AuthToken -User $User
}

#endregion

####################################################
 

#Teams webhook url
$uri = "https://outlook.office.com/webhook/e411f2b2-2639-48cf-a7b9-eda9e2c8c7d6@b61cf565-d3dc-4af4-b758-6b78b7ff0a27/IncomingWebhook/599167a4b4fb49f3b73b14805b95cd05/12b71bb8-5761-4c6b-83d3-63bdef9a8474"
#Image on the left hand side, here I have a regular user picture
$ItemImage = 'https://img.icons8.com/color/1600/circled-user-male-skin-type-1-2.png'
$SecurityGraph = New-Object 'System.Collections.Generic.List[System.Object]'
$ArrayTable = New-Object 'System.Collections.Generic.List[System.Object]'

Get-TopAlerts |Select-Object title, description, severity, eventdatetime, category, userstates | ForEach-Object{
$obj = [PSCustomObject]@{
'title' = $_.title 
'Description' = $_.description
'severity' = $_.severity
'eventDateTime' = $_.eventDateTime
'category' = $_.category
'userstates' = $_.userstates.accountname

}
$SecurityGraph.Add($obj)
}


$SecurityGraph | ForEach-Object {
$Section = @{
activityTitle = "$($_.Title)"
activityImage = $ItemImage
facts		  = @(
@{
name  = 'Title:'
value = $_.title
},
@{
name  = 'EventDatetime:'
value = $_.eventDateTime
},
@{
name  = 'userStates:'
value = $_.userStates
},
@{
name  = 'Description:'
value = $_.Description
},
@{
name  = 'Category:'
value = $_.Category
},
@{
name  = 'severity:'
value = $_.severity
}
)
}
$ArrayTable.add($section)
}
$body = ConvertTo-Json -Depth 8 @{
title = "Security Notifcations"
text  = "New Alert"
sections = $ArrayTable
}

Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'