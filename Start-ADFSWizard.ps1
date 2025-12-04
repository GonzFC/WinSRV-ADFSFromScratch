#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ADFS From Scratch - Setup Wizard

.DESCRIPTION
    Interactive wizard to configure Active Directory Federation Services
    on a Windows Server 2019+ member server.

    Run directly from GitHub:
    iex (irm 'https://raw.githubusercontent.com/GonzFC/WinSRV-ADFSFromScratch/main/Start-ADFSWizard.ps1')

.PARAMETER Resume
    Automatically resume from previous session without prompting.

.PARAMETER SkipPrerequisites
    Skip prerequisites check (not recommended).

.PARAMETER Reset
    Reset wizard state and start fresh.

.EXAMPLE
    .\Start-ADFSWizard.ps1
    Starts the wizard normally.

.EXAMPLE
    .\Start-ADFSWizard.ps1 -Resume
    Resumes a previous session.

.NOTES
    Author: ADFS From Scratch Project
    Version: 1.0.0
    Repository: https://github.com/GonzFC/WinSRV-ADFSFromScratch
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Resume,

    [Parameter()]
    [switch]$SkipPrerequisites,

    [Parameter()]
    [switch]$Reset
)

# Script-level configuration
$script:WizardVersion = "1.0.0"
$script:GitHubBaseUrl = "https://raw.githubusercontent.com/GonzFC/WinSRV-ADFSFromScratch/main"
$script:LocalModulePath = "C:\ADFSFromScratch\Modules"
$script:ModulesLoaded = $false

#region Module Loading

function Get-ModuleContent {
    <#
    .SYNOPSIS
        Downloads or reads a module from local/remote source.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $localPath = Join-Path $PSScriptRoot "modules\$ModuleName.psm1"
    $cachedPath = Join-Path $script:LocalModulePath "$ModuleName.psm1"
    $remoteUrl = "$script:GitHubBaseUrl/modules/$ModuleName.psm1"

    # Try local first (development)
    if (Test-Path $localPath) {
        return Get-Content $localPath -Raw
    }

    # Try cached modules
    if (Test-Path $cachedPath) {
        return Get-Content $cachedPath -Raw
    }

    # Download from GitHub
    try {
        $content = (Invoke-WebRequest -Uri $remoteUrl -UseBasicParsing -ErrorAction Stop).Content

        # Cache for future use
        if (-not (Test-Path $script:LocalModulePath)) {
            New-Item -Path $script:LocalModulePath -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path $cachedPath -Value $content -Force

        return $content
    }
    catch {
        throw "Failed to load module $ModuleName from $remoteUrl : $_"
    }
}

function Import-WizardModules {
    <#
    .SYNOPSIS
        Loads all required wizard modules.
    #>
    [CmdletBinding()]
    param()

    if ($script:ModulesLoaded) {
        return
    }

    $modules = @(
        'Menu'
        'State'
        'Logging'
        'Prerequisites'
    )

    foreach ($module in $modules) {
        try {
            $content = Get-ModuleContent -ModuleName $module

            # Create a temporary module file
            $tempPath = Join-Path $env:TEMP "ADFSWizard_$module.psm1"
            Set-Content -Path $tempPath -Value $content -Force

            # Import the module
            Import-Module $tempPath -Force -Global -ErrorAction Stop

            Write-Verbose "Loaded module: $module"
        }
        catch {
            Write-Error "Failed to load module $module : $_"
            throw
        }
    }

    $script:ModulesLoaded = $true
}

#endregion

#region Wizard Steps

function Invoke-WelcomeScreen {
    <#
    .SYNOPSIS
        Shows the welcome screen and disclaimer.
    #>
    [CmdletBinding()]
    param()

    Show-WizardBanner -Subtitle "v$script:WizardVersion"

    Write-Host ""
    Write-WizardStatus -Message "Welcome to the ADFS Setup Wizard!" -Type Info
    Write-Host ""
    Write-Host "  This wizard will help you configure Active Directory Federation Services" -ForegroundColor White
    Write-Host "  on this Windows Server. You will need:" -ForegroundColor White
    Write-Host ""
    Write-Host "    - Domain Admin credentials" -ForegroundColor Gray
    Write-Host "    - Your federation service FQDN (e.g., adfs.yourdomain.com)" -ForegroundColor Gray
    Write-Host "    - SSL certificate (or wizard can use Let's Encrypt)" -ForegroundColor Gray
    Write-Host "    - External DNS configured to point to your server" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  ============================================================" -ForegroundColor DarkYellow
    Write-Host "  DISCLAIMER: This wizard makes changes to your server and" -ForegroundColor Yellow
    Write-Host "  Active Directory. Ensure you have backups before proceeding." -ForegroundColor Yellow
    Write-Host "  ============================================================" -ForegroundColor DarkYellow
    Write-Host ""

    if (-not (Show-WizardConfirmation -Message "Do you want to continue?" -Default $true)) {
        Write-WizardStatus -Message "Wizard cancelled by user" -Type Warning
        return $false
    }

    return $true
}

function Invoke-ResumeCheck {
    <#
    .SYNOPSIS
        Checks for previous session and offers to resume.
    #>
    [CmdletBinding()]
    param()

    if (Test-HasPreviousSession) {
        Write-Host ""
        Write-WizardStatus -Message "Previous session detected" -Type Info

        $state = Get-WizardState
        $completedCount = ($state.completedSteps.PSObject.Properties.Value | Where-Object { $_.completed }).Count
        $totalSteps = $state.completedSteps.PSObject.Properties.Count

        Write-Host "  Progress: $completedCount/$totalSteps steps completed" -ForegroundColor Gray
        Write-Host "  Last updated: $($state.lastUpdated)" -ForegroundColor Gray
        Write-Host ""

        $resume = Show-WizardConfirmation -Message "Resume previous session?" -Default $true

        if ($resume) {
            return $true
        }
        else {
            $reset = Show-WizardConfirmation -Message "Start fresh? (Previous state will be backed up)" -Default $false
            if ($reset) {
                Reset-WizardState -Force
                return $false
            }
        }
    }

    return $false
}

function Invoke-PrerequisitesStep {
    <#
    .SYNOPSIS
        Runs the prerequisites check step.
    #>
    [CmdletBinding()]
    param()

    Set-CurrentStep -StepName 'prerequisites'

    Show-WizardBanner -Subtitle "Step 1: Prerequisites Check"
    Write-Host ""
    Write-WizardStatus -Message "Checking prerequisites..." -Type Info
    Write-Host ""

    # Run checks
    $results = Invoke-PrerequisitesCheck

    # Display results
    $items = Format-PrerequisitesResults -Results $results
    Show-WizardChecklist -Items $items -Title "Prerequisites"

    Write-Host ""

    if (-not $results.CanProceed) {
        Write-WizardError -Message "Critical prerequisites not met" `
            -Details ($results.CriticalFailures -join ", ") `
            -Remediation "Fix the above issues and run the wizard again"

        Add-WizardError -Step 'prerequisites' -Message "Critical prerequisites failed" -Details ($results.CriticalFailures -join ", ")

        Wait-WizardKeyPress
        return $false
    }

    # Handle non-critical issues
    if (-not $results.AllPassed) {
        Write-WizardStatus -Message "Some optional checks failed. You can proceed, but some features may not work." -Type Warning

        if (-not (Show-WizardConfirmation -Message "Continue anyway?" -Default $true)) {
            return $false
        }
    }

    # Handle KDS Root Key
    if ($results.Results['KDSRootKey'] -and -not $results.Results['KDSRootKey'].Success) {
        Write-Host ""
        Write-WizardStatus -Message "KDS Root Key is required for gMSA (Group Managed Service Account)" -Type Warning
        Write-Host ""
        Write-Host "  gMSA is the recommended service account for ADFS. The KDS Root Key" -ForegroundColor Gray
        Write-Host "  enables automatic password management by Active Directory." -ForegroundColor Gray
        Write-Host ""

        if (Show-WizardConfirmation -Message "Create KDS Root Key now?" -Default $true) {
            Write-Host ""
            Write-Host "  For LAB environments: Key is effective immediately" -ForegroundColor Gray
            Write-Host "  For PRODUCTION: Key may take up to 10 hours to replicate" -ForegroundColor Gray
            Write-Host ""

            $isLab = Show-WizardConfirmation -Message "Is this a LAB environment?" -Default $false

            $kdsResult = New-KDSRootKeyIfMissing -EffectiveImmediately:$isLab

            if ($kdsResult.Success) {
                Write-WizardStatus -Message $kdsResult.Message -Type Success
            }
            else {
                Write-WizardStatus -Message $kdsResult.Message -Type Error
                Wait-WizardKeyPress
                return $false
            }
        }
    }

    # Install required features if missing
    if ($results.Results['RequiredModules'] -and -not $results.Results['RequiredModules'].Success) {
        Write-Host ""
        Write-WizardStatus -Message "Installing required Windows features..." -Type Info

        $featuresResult = Install-RequiredFeatures

        if ($featuresResult.Success) {
            Write-WizardStatus -Message $featuresResult.Message -Type Success
        }
        else {
            Write-WizardStatus -Message $featuresResult.Message -Type Error
            Show-WizardTable -Data $featuresResult.Results -Title "Feature Installation Results"
        }
    }

    # Save domain info to state
    if ($results.Results['DomainJoined'].Success) {
        Set-WizardStateValue -Name 'domainName' -Value $results.Results['DomainJoined'].DomainName
    }

    Set-StepComplete -StepName 'prerequisites' -Details "All prerequisites met"
    Write-Host ""
    Write-WizardSuccess -Message "Prerequisites check passed!"

    Wait-WizardKeyPress
    return $true
}

function Invoke-NetworkStep {
    <#
    .SYNOPSIS
        Configures network settings and validates DNS.
    #>
    [CmdletBinding()]
    param()

    Set-CurrentStep -StepName 'network'

    Show-WizardBanner -Subtitle "Step 2: Network & DNS Configuration"
    Write-Host ""

    # Show current network config
    Write-WizardStatus -Message "Current Network Configuration:" -Type Info
    $netConfig = Get-NetworkConfiguration
    if ($netConfig) {
        Show-WizardTable -Data $netConfig
    }

    Write-Host ""

    # Get federation service name
    $currentFsName = Get-WizardStateValue -Name 'federationServiceName'
    $defaultFsName = if ($currentFsName) { $currentFsName } else { "adfs." + (Get-WizardStateValue -Name 'domainName') }

    $fsName = Read-WizardInput -Prompt "Federation Service Name (FQDN)" `
        -Default $defaultFsName `
        -Required `
        -Validator { param($v) $v -match '^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$' } `
        -ValidationMessage "Enter a valid FQDN (e.g., adfs.contoso.com)"

    Set-WizardStateValue -Name 'federationServiceName' -Value $fsName

    # Get display name
    $displayName = Read-WizardInput -Prompt "Federation Service Display Name" `
        -Default "ADFS Sign-In" `
        -Required

    Set-WizardStateValue -Name 'federationServiceDisplayName' -Value $displayName

    Write-Host ""
    Write-WizardStatus -Message "Testing DNS resolution for $fsName..." -Type Info

    # Test internal DNS
    try {
        $internalResolution = Resolve-DnsName -Name $fsName -DnsOnly -ErrorAction Stop
        Write-WizardStatus -Message "Internal DNS: $fsName resolves to $($internalResolution.IPAddress -join ', ')" -Type Success
    }
    catch {
        Write-WizardStatus -Message "Internal DNS: $fsName does not resolve" -Type Warning
        Write-Host "  You will need to create a DNS record for $fsName" -ForegroundColor Gray
    }

    Set-StepComplete -StepName 'network' -Details "Federation service: $fsName"
    Write-Host ""
    Write-WizardSuccess -Message "Network configuration complete!"

    Wait-WizardKeyPress
    return $true
}

function Invoke-CertificatesStep {
    <#
    .SYNOPSIS
        Handles SSL certificate configuration.
    #>
    [CmdletBinding()]
    param()

    Set-CurrentStep -StepName 'certificates'

    Show-WizardBanner -Subtitle "Step 3: Certificate Management"
    Write-Host ""

    $fsName = Get-WizardStateValue -Name 'federationServiceName'

    Write-WizardStatus -Message "ADFS requires an SSL certificate for: $fsName" -Type Info
    Write-Host ""

    $certOptions = @(
        @{ Key = '1'; Label = "Use Let's Encrypt (recommended for public access)" }
        @{ Key = '2'; Label = "Import existing PFX certificate" }
        @{ Key = '3'; Label = "Generate self-signed certificate (testing only)" }
        @{ Key = '4'; Label = "Skip (certificate already installed)" }
    )

    $choice = Show-WizardMenu -Title "Certificate Options" -MenuItems $certOptions

    switch ($choice) {
        '1' {
            Write-Host ""
            Write-WizardStatus -Message "Let's Encrypt integration will be implemented in a future update." -Type Warning
            Write-WizardStatus -Message "For now, please use option 2 or 3." -Type Info
            Wait-WizardKeyPress
            return Invoke-CertificatesStep  # Recurse to menu
        }
        '2' {
            Write-Host ""
            $pfxPath = Read-WizardInput -Prompt "Path to PFX file" -Required
            if (-not (Test-Path $pfxPath)) {
                Write-WizardStatus -Message "File not found: $pfxPath" -Type Error
                Wait-WizardKeyPress
                return Invoke-CertificatesStep
            }

            $pfxPassword = Read-WizardSecureInput -Prompt "PFX Password"

            try {
                $cert = Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $pfxPassword -ErrorAction Stop
                Set-WizardStateValue -Name 'certificateThumbprint' -Value $cert.Thumbprint
                Set-WizardStateValue -Name 'certificateSubject' -Value $cert.Subject
                Write-WizardStatus -Message "Certificate imported: $($cert.Subject)" -Type Success
            }
            catch {
                Write-WizardStatus -Message "Failed to import certificate: $_" -Type Error
                Wait-WizardKeyPress
                return Invoke-CertificatesStep
            }
        }
        '3' {
            Write-Host ""
            Write-WizardStatus -Message "Generating self-signed certificate..." -Type Info

            try {
                $cert = New-SelfSignedCertificate `
                    -DnsName $fsName, "localhost", $env:COMPUTERNAME `
                    -CertStoreLocation Cert:\LocalMachine\My `
                    -KeySpec KeyExchange `
                    -KeyLength 2048 `
                    -NotAfter (Get-Date).AddYears(1) `
                    -ErrorAction Stop

                Set-WizardStateValue -Name 'certificateThumbprint' -Value $cert.Thumbprint
                Set-WizardStateValue -Name 'certificateSubject' -Value $cert.Subject

                Write-WizardStatus -Message "Self-signed certificate created" -Type Success
                Write-WizardStatus -Message "WARNING: Self-signed certificates are not trusted by default!" -Type Warning
            }
            catch {
                Write-WizardStatus -Message "Failed to create certificate: $_" -Type Error
                Wait-WizardKeyPress
                return Invoke-CertificatesStep
            }
        }
        '4' {
            Write-Host ""
            Write-WizardStatus -Message "Looking for existing certificates for $fsName..." -Type Info

            $certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
                $_.Subject -match $fsName -or $_.DnsNameList.Unicode -contains $fsName
            }

            if ($certs) {
                Write-Host ""
                Write-Host "  Found certificates:" -ForegroundColor Cyan
                $certs | ForEach-Object {
                    Write-Host "    - $($_.Subject) (Expires: $($_.NotAfter))" -ForegroundColor Gray
                }
                Write-Host ""

                $thumbprint = Read-WizardInput -Prompt "Enter certificate thumbprint to use" -Required
                $selectedCert = $certs | Where-Object { $_.Thumbprint -eq $thumbprint }

                if ($selectedCert) {
                    Set-WizardStateValue -Name 'certificateThumbprint' -Value $selectedCert.Thumbprint
                    Set-WizardStateValue -Name 'certificateSubject' -Value $selectedCert.Subject
                    Write-WizardStatus -Message "Certificate selected: $($selectedCert.Subject)" -Type Success
                }
                else {
                    Write-WizardStatus -Message "Certificate not found" -Type Error
                    Wait-WizardKeyPress
                    return Invoke-CertificatesStep
                }
            }
            else {
                Write-WizardStatus -Message "No matching certificates found. Please import or create one." -Type Error
                Wait-WizardKeyPress
                return Invoke-CertificatesStep
            }
        }
    }

    Set-StepComplete -StepName 'certificates' -Details "Certificate configured"
    Write-Host ""
    Write-WizardSuccess -Message "Certificate configuration complete!"

    Wait-WizardKeyPress
    return $true
}

function Invoke-NotImplementedStep {
    <#
    .SYNOPSIS
        Placeholder for steps not yet implemented.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string]$StepNumber,

        [Parameter(Mandatory)]
        [string]$StepTitle
    )

    Show-WizardBanner -Subtitle "Step $StepNumber : $StepTitle"
    Write-Host ""
    Write-WizardStatus -Message "This step is not yet implemented." -Type Warning
    Write-WizardStatus -Message "Coming soon in a future update!" -Type Info
    Write-Host ""

    Wait-WizardKeyPress
    return $true
}

#endregion

#region Main Menu

function Show-MainMenu {
    <#
    .SYNOPSIS
        Shows the main wizard menu and handles navigation.
    #>
    [CmdletBinding()]
    param()

    while ($true) {
        Show-WizardBanner -Subtitle "Main Menu"

        $statuses = Get-AllStepStatuses

        $choice = Show-WizardStepMenu -StepStatus $statuses

        switch ($choice) {
            '1' {
                if (-not (Invoke-PrerequisitesStep)) {
                    # Prerequisites failed, don't block menu
                }
            }
            '2' {
                if (Test-StepComplete -StepName 'prerequisites') {
                    Invoke-NetworkStep | Out-Null
                }
                else {
                    Write-WizardStatus -Message "Complete Prerequisites first" -Type Warning
                    Wait-WizardKeyPress
                }
            }
            '3' {
                if (Test-StepComplete -StepName 'network') {
                    Invoke-CertificatesStep | Out-Null
                }
                else {
                    Write-WizardStatus -Message "Complete Network Configuration first" -Type Warning
                    Wait-WizardKeyPress
                }
            }
            '4' {
                Invoke-NotImplementedStep -StepName 'ports' -StepNumber '4' -StepTitle 'Port Forwarding Test' | Out-Null
            }
            '5' {
                Invoke-NotImplementedStep -StepName 'adfs-install' -StepNumber '5' -StepTitle 'ADFS Installation' | Out-Null
            }
            '6' {
                Invoke-NotImplementedStep -StepName 'adfs-config' -StepNumber '6' -StepTitle 'ADFS Configuration' | Out-Null
            }
            '7' {
                Invoke-NotImplementedStep -StepName 'applications' -StepNumber '7' -StepTitle 'Application Registration' | Out-Null
            }
            '8' {
                Invoke-NotImplementedStep -StepName 'validation' -StepNumber '8' -StepTitle 'Validation & Testing' | Out-Null
            }
            'H' {
                Show-WizardBanner -Subtitle "Help"
                Write-Host ""
                Write-Host "  ADFS From Scratch Setup Wizard" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  This wizard guides you through setting up Active Directory" -ForegroundColor White
                Write-Host "  Federation Services (ADFS) on Windows Server." -ForegroundColor White
                Write-Host ""
                Write-Host "  Steps must be completed in order. Each step builds on the previous." -ForegroundColor Gray
                Write-Host ""
                Write-Host "  For more help, visit:" -ForegroundColor White
                Write-Host "  https://github.com/GonzFC/WinSRV-ADFSFromScratch" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  Log files: $(Get-LogDirectory)" -ForegroundColor Gray
                Write-Host "  State file: $(Get-StateFilePath)" -ForegroundColor Gray
                Write-Host ""
                Wait-WizardKeyPress
            }
            'Q' {
                Write-Host ""
                if (Show-WizardConfirmation -Message "Are you sure you want to quit?" -Default $false) {
                    Write-WizardStatus -Message "Wizard state saved. Run again to resume." -Type Info
                    return
                }
            }
        }
    }
}

#endregion

#region Main Entry Point

function Start-Wizard {
    <#
    .SYNOPSIS
        Main entry point for the wizard.
    #>
    [CmdletBinding()]
    param()

    try {
        # Load modules
        Import-WizardModules

        # Acquire lock
        New-WizardLock

        # Start logging
        $logFile = Start-WizardTranscript
        Write-WizardLog -Level Info -Message "Wizard started" -Data @{
            Version  = $script:WizardVersion
            Computer = $env:COMPUTERNAME
            User     = $env:USERNAME
        }

        # Handle reset
        if ($Reset) {
            Reset-WizardState -Force
            Write-WizardStatus -Message "Wizard state reset" -Type Success
        }

        # Show welcome
        if (-not (Invoke-WelcomeScreen)) {
            return
        }

        # Check for resume
        if ($Resume -or (Invoke-ResumeCheck)) {
            Write-WizardStatus -Message "Resuming previous session..." -Type Info
            Start-Sleep -Seconds 1
        }

        # Main menu loop
        Show-MainMenu

    }
    catch {
        Write-WizardLog -Level Error -Message "Wizard error: $_" -Data @{
            Exception = $_.Exception.Message
            Line      = $_.InvocationInfo.ScriptLineNumber
        }
        Write-Host ""
        Write-Host "  FATAL ERROR: $_" -ForegroundColor Red
        Write-Host "  Check logs at: $(Get-LogDirectory)" -ForegroundColor Gray
        Write-Host ""
    }
    finally {
        # Cleanup
        Set-CurrentStep -StepName $null
        Stop-WizardTranscript
        Remove-WizardLock

        Write-Host ""
        Write-Host "  Thank you for using ADFS From Scratch!" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Run the wizard
Start-Wizard
