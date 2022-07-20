[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Please enter the full PVWA Address IE: https://tenantname.privilegecloud.cyberark.cloud")]
    [string]$pvwaAddress,
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Please enter the account credentials for the tenant administrator or installer user.")]
    [PSCredential]$tinaCreds,
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Please enter the Safe to save the domain accounts in, By default it is PSM")]
    [String]$safe = "PSM"    
)

Function Check-UM {
    <#
    .SYNOPSIS
    Checks to see if tenant is UM or not (from the connector server)
    .DESCRIPTION
    Checks to see if tenant is UM or not (from the connector server)
    .PARAMETER psmRootInstallLocation
    PSM Folder
    #>
    param (
        [Parameter(Mandatory = $true)]
        $psmRootInstallLocation
    )
    $psmBasicPSMContent = Get-Content -Path $psmRootInstallLocation\basic_psm.ini 
    $validation = $psmBasicPSMContent -match "IdentityUM.*=.*Yes"
    return ("" -ne $validation) 
}

Function Get-ServiceInstallPath {
    <#
    .SYNOPSIS
    Get the installation path of a service
    .DESCRIPTION
    The function receive the service name and return the path or returns NULL if not found
    .EXAMPLE
    (Get-ServiceInstallPath $<ServiceName>) -ne $NULL
    .PARAMETER ServiceName
    The service name to query. Just one.
    #>
    param ($ServiceName)
    Begin {
        
    }
    Process {
        $retInstallPath = $null
        try {
            Set-Variable -Name m_ServiceList -Value $(Get-ChildItem "HKLM:\System\CurrentControlSet\Services" | ForEach-Object { Get-ItemProperty $_.pspath }) -Scope Script
            $regPath = $m_ServiceList | Where-Object { $_.PSChildName -eq $ServiceName }
            If ($Null -ne $regPath) {
                $retInstallPath = $regPath.ImagePath.Substring($regPath.ImagePath.IndexOf('"'), $regPath.ImagePath.LastIndexOf('"') + 1)
            }
        }
        catch {
            Throw $(New-Object System.Exception ("Cannot get Service Install path for $ServiceName", $_.Exception))
        }
        
        return $retInstallPath
    }
    End {
        
    }
}

Function Get-PvwaAddress {
    <#
    .SYNOPSIS
    Backs up PSMConfig ps1 scripts
    .DESCRIPTION
    Copies PSM config items to -backup.ps1
    .PARAMETER psmRootInstallLocation
    PSM root installation folder
    #>
    param (
        [Parameter(Mandatory = $true)]
        $psmRootInstallLocation
    )
    try {
        $VaultIni = Get-Content "$psmRootInstallLocation\vault\vault.ini"
        $VaultIniAddressesLine = $VaultIni | Select-String "^Addresses"
        $null = $VaultIniAddressesLine -match "(https://[0-9a-zA-Z][\.\-0-9a-zA-Z]*)"
        $Address = $Matches[0]
        If (!($Address)) {
            Throw
        }
        return $Address
    }
    catch {
        Write-Host "Unable to detect PVWA address automatically. Please rerun script and provide it using the -PvwaAddress parameter."
        exit 1
    }
}

Function New-ConnectionToRestAPI {
    <#
    .SYNOPSIS
    Get the installation path of a service
    .DESCRIPTION
    The function receive the service name and return the path or returns NULL if not found
    .EXAMPLE
    (Get-ServiceInstallPath $<ServiceName>) -ne $NULL
    .PARAMETER pvwaAddress
    The PVWA server address (e.g. https://subdomain.privilegecloud.cyberark.cloud)
    .PARAMETER tinaCreds
    Tenant administrator/installer user credentials
    #>
    # Get PVWA and login informatioN
    param (
        [Parameter(Mandatory = $true)]
        $pvwaAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$tinaCreds        
    )
    $url = $pvwaAddress + "/PasswordVault/API/auth/Cyberark/Logon"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tinaCreds.Password)
    
    $headerPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $body = @{
        username = $tinaCreds.UserName
        password = $headerPass
    }
    $json = $body | ConvertTo-Json
    Try {
        $pvwaToken = Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -ContentType 'application/json'
    }
    Catch {
        Write-Host "Failed to retrieve token. Response received:"
        Write-Host $_.Exception.Message
        exit 1
    }
    if ($pvwaToken -match "[0-9a-zA-Z]{200,256}") {
        return $pvwaToken
    }
    else {
        Write-Host "Failed to retrieve token. Response received:"
        Write-Host $_.Exception.Message
        exit 1
    }
}

Function Set-SafePermissionsFull {
    <#
    .SYNOPSIS
    Adds safe permission to a specific safe
    .DESCRIPTION
    Adds safe permission to a specific safe
    .PARAMETER pvwaAddress
    PVWA address to run API commands on
    .PARAMETER pvwaToken
    Token to authenticate into the PVWA
    .PARAMETER safe
    Which Safe to give permission to (Default PSM)
    .PARAMETER SafeMember
    Which Member to give the safe permission
    .PARAMETER memberType
    What type of member to give permission to (group,role,user)    
    #>
    param (
        [Parameter(Mandatory = $true)]
        $pvwaAddress,
        [Parameter(Mandatory = $true)]
        $pvwaToken,
        [Parameter(Mandatory = $false)]
        $safe = "PSM",
        [Parameter(Mandatory = $false)]
        $SafeMember = "Vault Admins",
        [Parameter(Mandatory = $false)]
        $memberType = "Group"   
    )
    try {
        $url = $pvwaAddress + "/PasswordVault/api/Safes/$safe/members"
        $body = @{ 
            memberName  = $SafeMember
            memberType  = $memberType
            permissions = @{
                useAccounts                            = $True 
                retrieveAccounts                       = $True
                listAccounts                           = $True
                addAccounts                            = $True 
                updateAccountContent                   = $True
                updateAccountProperties                = $True
                initiateCPMAccountManagementOperations = $True
                specifyNextAccountContent              = $True
                renameAccounts                         = $True
                deleteAccounts                         = $True
                unlockAccounts                         = $True
                manageSafe                             = $True
                manageSafeMembers                      = $True
                backupSafe                             = $True
                viewAuditLog                           = $True
                viewSafeMembers                        = $True
                accessWithoutConfirmation              = $True
                createFolders                          = $True
                deleteFolders                          = $True
                moveAccountsAndFolders                 = $True
                requestsAuthorizationLevel1            = $True 
                requestsAuthorizationLevel2            = $False
            }
        }
        $json = $body | ConvertTo-Json
        $null = Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $pvwaToken } -ContentType 'application/json'
    }
    catch {
        Write-Host $_.ErrorDetails.Message 
    }
}

Function Test-PvwaToken {
    <#
    .SYNOPSIS
    Test a PVWA token to ensure it is valid
    .DESCRIPTION
    The function receive the service name and return the path or returns NULL if not found
    .EXAMPLE
    Test-PvwaToken -Token $Token -PvwaAddress https://subdomain.privilegecloud.cyberark.cloud
    .PARAMETER pvwaAddress
    The PVWA server address (e.g. https://subdomain.privilegecloud.cyberark.cloud)
    .PARAMETER Token
    PVWA Token
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$pvwaAddress,
        [Parameter(Mandatory = $true)]
        [string]$Token        
    )
    $url = $pvwaAddress + "/PasswordVault/API/Accounts?limit=1"
    $Headers = @{
        Authorization = $Token
    }
    $testToken = Invoke-RestMethod -Method 'Get' -Uri $url -Headers $Headers -ContentType 'application/json'
    if ($testToken) {
        return $true
    }
    else {
        return $false
    }
}


$REGKEY_PSMSERVICE = "Cyber-Ark Privileged Session Manager"
$psmRootInstallLocation = ($(Get-ServiceInstallPath $REGKEY_PSMSERVICE)).Replace("CAPSM.exe", "").Replace('"', "").Trim()


If (Check-UM -psmRootInstallLocation $psmRootInstallLocation) {
    $UM = $true
}
else { 
    $UM = $false
}

if ($null -eq $tinaCreds) {
    if ($UM) {
        $TinaUserType = "installer user"
    }
    else {
        $TinaUserType = "tenant administrator"
    }
    $tinaCreds = Get-Credential -Message ("Please enter {0} credentials" -f $TinaUserType)
    if (!($tinaCreds)) {
        Write-Error "No credentials provided. Exiting."
        exit 1
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get-Variables
if (!($pvwaAddress)) {
    Write-Host "Getting PVWA address"
    $pvwaAddress = Get-PvwaAddress -psmRootInstallLocation $psmRootInstallLocation
}

Write-Host "Logging in to CyberArk"
$pvwaToken = New-ConnectionToRestAPI -pvwaAddress $pvwaAddress -tinaCreds $tinaCreds
if (Test-PvwaToken -Token $pvwaToken -pvwaAddress $pvwaAddress) {
    Write-Host "Successfully logged in"
}
else {
    Write-Host "Error logging in to CyberArk"
    exit 1
}

# Giving Permission on the safe if we are using UM, The below will give full permission to vault admins
If ($UM) {
    Write-Host "Granting administrators access to PSM safe"
    Set-SafePermissionsFull -pvwaAddress $pvwaAddress -pvwaToken $pvwaToken -safe $safe
}
