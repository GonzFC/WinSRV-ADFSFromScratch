#Requires -Version 5.1
<#
.SYNOPSIS
    Prerequisites Validation for ADFS Setup Wizard

.DESCRIPTION
    Validates all prerequisites required for ADFS installation:
    - Operating system requirements
    - Domain membership
    - Administrative privileges
    - Network connectivity
    - Active Directory requirements (gMSA support, KDS root key)

.NOTES
    This module blocks progression if critical checks fail.
#>

#region Operating System Checks

function Test-IsServerCore {
    <#
    .SYNOPSIS
        Detects if running on Windows Server Core.

    .OUTPUTS
        $true if Server Core, $false if Desktop Experience.
    #>
    [CmdletBinding()]
    param()

    try {
        # Check for Server Core by looking for explorer.exe
        $explorer = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name Shell -ErrorAction SilentlyContinue
        if ($explorer.Shell -eq "explorer.exe") {
            return $false
        }

        # Alternative: check for ServerCore installation
        $installationType = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name InstallationType -ErrorAction SilentlyContinue).InstallationType
        return $installationType -eq "Server Core"
    }
    catch {
        return $false
    }
}

function Test-IsDomainJoined {
    <#
    .SYNOPSIS
        Checks if the computer is joined to a domain.

    .OUTPUTS
        PSCustomObject with Success, DomainName, and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $isDomainJoined = $computerSystem.PartOfDomain

        if ($isDomainJoined) {
            return [PSCustomObject]@{
                Success    = $true
                DomainName = $computerSystem.Domain
                Message    = "Joined to domain: $($computerSystem.Domain)"
            }
        }
        else {
            return [PSCustomObject]@{
                Success    = $false
                DomainName = $null
                Message    = "Computer is not domain-joined"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success    = $false
            DomainName = $null
            Message    = "Failed to check domain membership: $_"
        }
    }
}

function Test-IsNotDomainController {
    <#
    .SYNOPSIS
        Ensures this is NOT a Domain Controller.

    .DESCRIPTION
        ADFS should never be installed on a Domain Controller.
        This check is critical for security.

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $isDC = $computerSystem.DomainRole -ge 4  # 4 = Backup DC, 5 = Primary DC

        if ($isDC) {
            return [PSCustomObject]@{
                Success = $false
                Message = "This is a Domain Controller. ADFS must be installed on a member server, not a DC."
            }
        }
        else {
            $roleDescription = switch ($computerSystem.DomainRole) {
                0 { "Standalone Workstation" }
                1 { "Member Workstation" }
                2 { "Standalone Server" }
                3 { "Member Server" }
                default { "Unknown" }
            }
            return [PSCustomObject]@{
                Success = $true
                Message = "Server role: $roleDescription"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Failed to check server role: $_"
        }
    }
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Checks if running with administrative privileges.

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        return [PSCustomObject]@{
            Success = $true
            Message = "Running with administrative privileges"
        }
    }
    else {
        return [PSCustomObject]@{
            Success = $false
            Message = "Must run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
        }
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Checks PowerShell version.

    .OUTPUTS
        PSCustomObject with Success, Version, and Message properties.
    #>
    [CmdletBinding()]
    param()

    $version = $PSVersionTable.PSVersion
    $requiredMajor = 5
    $requiredMinor = 1

    if ($version.Major -gt $requiredMajor -or
        ($version.Major -eq $requiredMajor -and $version.Minor -ge $requiredMinor)) {
        return [PSCustomObject]@{
            Success = $true
            Version = $version.ToString()
            Message = "PowerShell $($version.ToString())"
        }
    }
    else {
        return [PSCustomObject]@{
            Success = $false
            Version = $version.ToString()
            Message = "PowerShell $requiredMajor.$requiredMinor or higher required. Current: $($version.ToString())"
        }
    }
}

function Test-WindowsVersion {
    <#
    .SYNOPSIS
        Checks Windows Server version.

    .OUTPUTS
        PSCustomObject with Success, Version, and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $caption = $os.Caption
        $version = $os.Version
        $buildNumber = $os.BuildNumber

        # Check for Windows Server 2019 (build 17763) or later
        $minBuild = 17763

        if ([int]$buildNumber -ge $minBuild) {
            return [PSCustomObject]@{
                Success = $true
                Version = $caption
                Build   = $buildNumber
                Message = "$caption (Build $buildNumber)"
            }
        }
        else {
            return [PSCustomObject]@{
                Success = $false
                Version = $caption
                Build   = $buildNumber
                Message = "Windows Server 2019 or later required. Current: $caption"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Version = "Unknown"
            Build   = "0"
            Message = "Failed to detect Windows version: $_"
        }
    }
}

#endregion

#region Network Checks

function Test-DomainControllerConnectivity {
    <#
    .SYNOPSIS
        Tests connectivity to a Domain Controller.

    .OUTPUTS
        PSCustomObject with Success, DCName, and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        # Get the logon server (current DC)
        $logonServer = $env:LOGONSERVER -replace '\\\\', ''

        if (-not $logonServer) {
            # Try to find a DC using DNS
            $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            $dcs = Resolve-DnsName -Name $domain -Type SRV -DnsOnly -ErrorAction Stop |
                Where-Object { $_.QueryType -eq 'SRV' }

            if ($dcs) {
                $logonServer = $dcs[0].NameTarget
            }
        }

        if (-not $logonServer) {
            return [PSCustomObject]@{
                Success = $false
                DCName  = $null
                Message = "Cannot locate a Domain Controller"
            }
        }

        # Test LDAP connectivity (port 389)
        $ldapTest = Test-NetConnection -ComputerName $logonServer -Port 389 -WarningAction SilentlyContinue

        if ($ldapTest.TcpTestSucceeded) {
            return [PSCustomObject]@{
                Success = $true
                DCName  = $logonServer
                Message = "Connected to DC: $logonServer"
            }
        }
        else {
            return [PSCustomObject]@{
                Success = $false
                DCName  = $logonServer
                Message = "Cannot connect to DC $logonServer on LDAP port 389"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            DCName  = $null
            Message = "Failed to test DC connectivity: $_"
        }
    }
}

function Test-DNSResolution {
    <#
    .SYNOPSIS
        Tests DNS resolution for the domain.

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain

        if (-not $domain) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Cannot determine domain name"
            }
        }

        $resolution = Resolve-DnsName -Name $domain -Type A -DnsOnly -ErrorAction Stop

        if ($resolution) {
            return [PSCustomObject]@{
                Success = $true
                Message = "DNS resolution working for $domain"
            }
        }
        else {
            return [PSCustomObject]@{
                Success = $false
                Message = "DNS resolution failed for $domain"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "DNS resolution error: $_"
        }
    }
}

function Test-InternetConnectivity {
    <#
    .SYNOPSIS
        Tests internet connectivity (needed for Let's Encrypt).

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        # Test connectivity to common endpoints
        $endpoints = @(
            @{ Name = "Microsoft"; Host = "www.microsoft.com"; Port = 443 }
            @{ Name = "Let's Encrypt"; Host = "acme-v02.api.letsencrypt.org"; Port = 443 }
        )

        $results = @()

        foreach ($endpoint in $endpoints) {
            $test = Test-NetConnection -ComputerName $endpoint.Host -Port $endpoint.Port -WarningAction SilentlyContinue
            $results += [PSCustomObject]@{
                Name    = $endpoint.Name
                Success = $test.TcpTestSucceeded
            }
        }

        $allSuccess = ($results | Where-Object { $_.Success }).Count -eq $results.Count

        if ($allSuccess) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Internet connectivity confirmed"
            }
        }
        else {
            $failed = ($results | Where-Object { -not $_.Success }).Name -join ", "
            return [PSCustomObject]@{
                Success = $false
                Message = "Cannot reach: $failed (Let's Encrypt may not work)"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Internet connectivity test failed: $_"
        }
    }
}

function Get-NetworkConfiguration {
    <#
    .SYNOPSIS
        Gets current network configuration.

    .OUTPUTS
        Network configuration object.
    #>
    [CmdletBinding()]
    param()

    try {
        $adapters = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }

        $config = @()
        foreach ($adapter in $adapters) {
            $config += [PSCustomObject]@{
                InterfaceName = $adapter.InterfaceAlias
                IPv4Address   = ($adapter.IPv4Address.IPAddress -join ", ")
                Gateway       = ($adapter.IPv4DefaultGateway.NextHop -join ", ")
                DNSServers    = ($adapter.DNSServer.ServerAddresses -join ", ")
            }
        }

        return $config
    }
    catch {
        return $null
    }
}

#endregion

#region Active Directory Checks

function Test-ADForestFunctionalLevel {
    <#
    .SYNOPSIS
        Checks the AD forest functional level.

    .DESCRIPTION
        gMSA requires forest functional level of 2012 or higher.

    .OUTPUTS
        PSCustomObject with Success, Level, and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $forest = Get-ADForest
        $level = $forest.ForestMode

        # 2012 and higher support gMSA
        $supported = @(
            'Windows2012Forest',
            'Windows2012R2Forest',
            'Windows2016Forest',
            'Windows2019Forest',
            'Windows2022Forest',
            'Windows2025Forest'
        )

        if ($level -in $supported -or $level -match '201[2-9]|202[0-9]') {
            return [PSCustomObject]@{
                Success = $true
                Level   = $level
                Message = "Forest functional level: $level"
            }
        }
        else {
            return [PSCustomObject]@{
                Success = $false
                Level   = $level
                Message = "Forest functional level $level does not support gMSA. Requires 2012 or higher."
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Level   = "Unknown"
            Message = "Cannot determine forest functional level: $_"
        }
    }
}

function Test-KDSRootKey {
    <#
    .SYNOPSIS
        Checks if a KDS Root Key exists for gMSA support.

    .OUTPUTS
        PSCustomObject with Success, KeyExists, and Message properties.
    #>
    [CmdletBinding()]
    param()

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $keys = Get-KdsRootKey -ErrorAction Stop

        if ($keys) {
            # Check if any key is effective (created more than 10 hours ago for replication)
            $effectiveKey = $keys | Where-Object {
                $_.EffectiveTime -lt (Get-Date)
            }

            if ($effectiveKey) {
                return [PSCustomObject]@{
                    Success   = $true
                    KeyExists = $true
                    Message   = "KDS Root Key exists and is effective"
                }
            }
            else {
                return [PSCustomObject]@{
                    Success   = $false
                    KeyExists = $true
                    Message   = "KDS Root Key exists but is not yet effective. Wait for replication or create with -EffectiveImmediately."
                }
            }
        }
        else {
            return [PSCustomObject]@{
                Success   = $false
                KeyExists = $false
                Message   = "No KDS Root Key found. Required for gMSA. Wizard can create one."
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success   = $false
            KeyExists = $false
            Message   = "Cannot check KDS Root Key: $_"
        }
    }
}

function New-KDSRootKeyIfMissing {
    <#
    .SYNOPSIS
        Creates a KDS Root Key if one doesn't exist.

    .PARAMETER EffectiveImmediately
        If set, creates the key with immediate effect (for lab environments).

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$EffectiveImmediately
    )

    $kdsCheck = Test-KDSRootKey

    if ($kdsCheck.Success) {
        return [PSCustomObject]@{
            Success = $true
            Message = "KDS Root Key already exists"
        }
    }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        if ($EffectiveImmediately) {
            # For lab environments - effective immediately (bypasses 10-hour wait)
            Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) -ErrorAction Stop
            return [PSCustomObject]@{
                Success = $true
                Message = "KDS Root Key created with immediate effect (lab mode)"
            }
        }
        else {
            # Production - normal creation with replication wait
            Add-KdsRootKey -EffectiveImmediately -ErrorAction Stop
            return [PSCustomObject]@{
                Success = $true
                Message = "KDS Root Key created. May need to wait up to 10 hours for replication."
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Failed to create KDS Root Key: $_"
        }
    }
}

function Test-ADFSServiceAccountExists {
    <#
    .SYNOPSIS
        Checks if the ADFS gMSA service account already exists.

    .PARAMETER AccountName
        The name of the gMSA to check (without $).

    .OUTPUTS
        PSCustomObject with Success, Exists, and Message properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AccountName = "svc_adfs"
    )

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $account = Get-ADServiceAccount -Identity $AccountName -ErrorAction SilentlyContinue

        if ($account) {
            return [PSCustomObject]@{
                Success = $true
                Exists  = $true
                Message = "gMSA '$AccountName' already exists"
            }
        }
        else {
            return [PSCustomObject]@{
                Success = $true
                Exists  = $false
                Message = "gMSA '$AccountName' does not exist (will be created)"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Exists  = $false
            Message = "Cannot check for gMSA: $_"
        }
    }
}

#endregion

#region Required Modules Check

function Test-RequiredModules {
    <#
    .SYNOPSIS
        Checks if required PowerShell modules are available.

    .OUTPUTS
        PSCustomObject with Success, MissingModules, and Message properties.
    #>
    [CmdletBinding()]
    param()

    $required = @(
        @{ Name = "ActiveDirectory"; Feature = "RSAT-AD-PowerShell" }
        @{ Name = "ServerManager"; Feature = $null }
    )

    $missing = @()

    foreach ($module in $required) {
        $available = Get-Module -ListAvailable -Name $module.Name -ErrorAction SilentlyContinue
        if (-not $available) {
            $missing += $module.Name
        }
    }

    if ($missing.Count -eq 0) {
        return [PSCustomObject]@{
            Success        = $true
            MissingModules = @()
            Message        = "All required PowerShell modules available"
        }
    }
    else {
        return [PSCustomObject]@{
            Success        = $false
            MissingModules = $missing
            Message        = "Missing modules: $($missing -join ', '). Install RSAT tools."
        }
    }
}

function Install-RequiredFeatures {
    <#
    .SYNOPSIS
        Installs required Windows features.

    .OUTPUTS
        PSCustomObject with Success and Message properties.
    #>
    [CmdletBinding()]
    param()

    $features = @(
        "RSAT-AD-PowerShell"
        "RSAT-ADFS-Tools"
    )

    $results = @()

    foreach ($feature in $features) {
        try {
            $installed = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
            if ($installed.Installed) {
                $results += [PSCustomObject]@{
                    Feature = $feature
                    Status  = "Already installed"
                }
            }
            else {
                Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop | Out-Null
                $results += [PSCustomObject]@{
                    Feature = $feature
                    Status  = "Installed"
                }
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Feature = $feature
                Status  = "Failed: $_"
            }
        }
    }

    $allSuccess = ($results | Where-Object { $_.Status -notmatch "Failed" }).Count -eq $results.Count

    return [PSCustomObject]@{
        Success = $allSuccess
        Results = $results
        Message = if ($allSuccess) { "All required features installed" } else { "Some features failed to install" }
    }
}

#endregion

#region Main Prerequisites Check

function Invoke-PrerequisitesCheck {
    <#
    .SYNOPSIS
        Runs all prerequisite checks and returns results.

    .PARAMETER SkipInternetCheck
        Skips the internet connectivity check.

    .OUTPUTS
        PSCustomObject with all check results.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SkipInternetCheck
    )

    $results = [ordered]@{}

    # Critical checks (must pass)
    $results['AdminPrivileges'] = Test-AdminPrivileges
    $results['NotDomainController'] = Test-IsNotDomainController
    $results['DomainJoined'] = Test-IsDomainJoined
    $results['PowerShellVersion'] = Test-PowerShellVersion
    $results['WindowsVersion'] = Test-WindowsVersion

    # Network checks
    $results['DCConnectivity'] = Test-DomainControllerConnectivity
    $results['DNSResolution'] = Test-DNSResolution

    if (-not $SkipInternetCheck) {
        $results['InternetConnectivity'] = Test-InternetConnectivity
    }

    # AD checks (may fail if AD modules not installed yet)
    try {
        $results['RequiredModules'] = Test-RequiredModules
        if ($results['RequiredModules'].Success) {
            $results['ForestLevel'] = Test-ADForestFunctionalLevel
            $results['KDSRootKey'] = Test-KDSRootKey
        }
    }
    catch {
        $results['RequiredModules'] = [PSCustomObject]@{
            Success = $false
            Message = "Cannot check AD requirements: $_"
        }
    }

    # Determine overall status
    $criticalChecks = @('AdminPrivileges', 'NotDomainController', 'DomainJoined', 'DCConnectivity')
    $criticalFailures = $criticalChecks | Where-Object { -not $results[$_].Success }

    $allPassed = ($results.Values | Where-Object { -not $_.Success } | Measure-Object).Count -eq 0

    return [PSCustomObject]@{
        Results          = $results
        AllPassed        = $allPassed
        CriticalFailures = $criticalFailures
        CanProceed       = $criticalFailures.Count -eq 0
    }
}

function Format-PrerequisitesResults {
    <#
    .SYNOPSIS
        Formats prerequisite results for display.

    .PARAMETER Results
        The results from Invoke-PrerequisitesCheck.

    .OUTPUTS
        Array of formatted items for Show-WizardChecklist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Results
    )

    $checkNames = @{
        'AdminPrivileges'      = 'Administrator Privileges'
        'NotDomainController'  = 'Not a Domain Controller'
        'DomainJoined'         = 'Domain Membership'
        'PowerShellVersion'    = 'PowerShell Version'
        'WindowsVersion'       = 'Windows Server Version'
        'DCConnectivity'       = 'Domain Controller Connectivity'
        'DNSResolution'        = 'DNS Resolution'
        'InternetConnectivity' = 'Internet Connectivity'
        'RequiredModules'      = 'Required PowerShell Modules'
        'ForestLevel'          = 'AD Forest Functional Level'
        'KDSRootKey'           = 'KDS Root Key (gMSA Support)'
    }

    $items = @()

    foreach ($key in $Results.Results.Keys) {
        $result = $Results.Results[$key]
        $items += [PSCustomObject]@{
            Name    = $checkNames[$key] ?? $key
            Status  = if ($result.Success) { 'Pass' } else { 'Fail' }
            Message = $result.Message
        }
    }

    return $items
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Test-IsServerCore'
    'Test-IsDomainJoined'
    'Test-IsNotDomainController'
    'Test-AdminPrivileges'
    'Test-PowerShellVersion'
    'Test-WindowsVersion'
    'Test-DomainControllerConnectivity'
    'Test-DNSResolution'
    'Test-InternetConnectivity'
    'Get-NetworkConfiguration'
    'Test-ADForestFunctionalLevel'
    'Test-KDSRootKey'
    'New-KDSRootKeyIfMissing'
    'Test-ADFSServiceAccountExists'
    'Test-RequiredModules'
    'Install-RequiredFeatures'
    'Invoke-PrerequisitesCheck'
    'Format-PrerequisitesResults'
)
