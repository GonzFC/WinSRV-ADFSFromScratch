#Requires -Version 5.1
<#
.SYNOPSIS
    State Management for ADFS Setup Wizard

.DESCRIPTION
    Handles persistence of wizard state to enable resume capability.
    State is stored as JSON in a local file.

.NOTES
    Never stores secrets (passwords, keys) in state file.
#>

# Module-level variables
$script:StateVersion = "1.0.0"
$script:StateDirectory = "C:\ADFSFromScratch\State"
$script:StateFile = Join-Path $script:StateDirectory "wizard-state.json"
$script:LockFile = Join-Path $script:StateDirectory "wizard.lock"
$script:CurrentState = $null

function Initialize-StateDirectory {
    <#
    .SYNOPSIS
        Creates the state directory if it doesn't exist.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:StateDirectory)) {
        try {
            New-Item -Path $script:StateDirectory -ItemType Directory -Force | Out-Null
            Write-Verbose "Created state directory: $script:StateDirectory"
        }
        catch {
            throw "Failed to create state directory: $_"
        }
    }
}

function Get-DefaultState {
    <#
    .SYNOPSIS
        Returns a new default state object.
    #>
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        version         = $script:StateVersion
        wizardStarted   = (Get-Date).ToUniversalTime().ToString("o")
        lastUpdated     = (Get-Date).ToUniversalTime().ToString("o")
        currentStep     = $null
        configuration   = [PSCustomObject]@{
            federationServiceName    = $null
            federationServiceDisplayName = $null
            gmsaAccountName          = $null
            certificateThumbprint    = $null
            certificateSubject       = $null
            internalDnsName          = $null
            externalDnsName          = $null
            domainName               = $null
            domainNetbiosName        = $null
        }
        completedSteps  = [PSCustomObject]@{
            prerequisites    = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            network          = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            certificates     = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            ports            = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            'adfs-install'   = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            'adfs-config'    = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            applications     = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
            validation       = [PSCustomObject]@{ completed = $false; timestamp = $null; details = $null }
        }
        registeredApps  = @()
        errors          = @()
    }
}

function Test-WizardLock {
    <#
    .SYNOPSIS
        Checks if another wizard instance is running.

    .OUTPUTS
        Returns $true if locked, $false if not.
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:LockFile) {
        try {
            $lockContent = Get-Content $script:LockFile -Raw | ConvertFrom-Json
            $lockTime = [DateTime]::Parse($lockContent.timestamp)
            $lockPid = $lockContent.processId

            # Check if the process is still running
            $process = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
            if ($process) {
                # Lock is valid - another instance is running
                return $true
            }

            # Process not running - stale lock, remove it
            Remove-Item $script:LockFile -Force
            return $false
        }
        catch {
            # Corrupted lock file - remove it
            Remove-Item $script:LockFile -Force -ErrorAction SilentlyContinue
            return $false
        }
    }

    return $false
}

function New-WizardLock {
    <#
    .SYNOPSIS
        Creates a lock file to prevent concurrent execution.
    #>
    [CmdletBinding()]
    param()

    Initialize-StateDirectory

    if (Test-WizardLock) {
        throw "Another wizard instance is already running. Only one instance can run at a time."
    }

    $lockContent = @{
        processId = $PID
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        hostname  = $env:COMPUTERNAME
    }

    $lockContent | ConvertTo-Json | Set-Content $script:LockFile -Force
}

function Remove-WizardLock {
    <#
    .SYNOPSIS
        Removes the wizard lock file.
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:LockFile) {
        Remove-Item $script:LockFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-WizardState {
    <#
    .SYNOPSIS
        Loads the wizard state from disk.

    .PARAMETER Force
        Forces reload from disk even if already loaded.

    .OUTPUTS
        The current state object.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    # Return cached state if available
    if ($script:CurrentState -and -not $Force) {
        return $script:CurrentState
    }

    # Try to load from disk
    if (Test-Path $script:StateFile) {
        try {
            $stateJson = Get-Content $script:StateFile -Raw
            $state = $stateJson | ConvertFrom-Json

            # Version migration if needed
            if ($state.version -ne $script:StateVersion) {
                $state = Update-StateVersion -OldState $state
            }

            $script:CurrentState = $state
            return $state
        }
        catch {
            Write-Warning "Failed to load state file, starting fresh: $_"
        }
    }

    # Return default state
    $script:CurrentState = Get-DefaultState
    return $script:CurrentState
}

function Save-WizardState {
    <#
    .SYNOPSIS
        Saves the current wizard state to disk.

    .PARAMETER State
        The state object to save. If not provided, saves the current state.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSObject]$State
    )

    Initialize-StateDirectory

    if (-not $State) {
        $State = $script:CurrentState
    }

    if (-not $State) {
        throw "No state to save"
    }

    # Update timestamp
    $State.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")

    # Save to disk
    try {
        $State | ConvertTo-Json -Depth 10 | Set-Content $script:StateFile -Force
        $script:CurrentState = $State
    }
    catch {
        throw "Failed to save state: $_"
    }
}

function Set-WizardStateValue {
    <#
    .SYNOPSIS
        Sets a value in the wizard state configuration.

    .PARAMETER Name
        The configuration property name.

    .PARAMETER Value
        The value to set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Value
    )

    $state = Get-WizardState

    if ($state.configuration.PSObject.Properties.Name -contains $Name) {
        $state.configuration.$Name = $Value
    }
    else {
        # Add new property
        $state.configuration | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    }

    Save-WizardState -State $state
}

function Get-WizardStateValue {
    <#
    .SYNOPSIS
        Gets a value from the wizard state configuration.

    .PARAMETER Name
        The configuration property name.

    .OUTPUTS
        The value, or $null if not set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $state = Get-WizardState

    if ($state.configuration.PSObject.Properties.Name -contains $Name) {
        return $state.configuration.$Name
    }

    return $null
}

function Set-StepComplete {
    <#
    .SYNOPSIS
        Marks a wizard step as complete.

    .PARAMETER StepName
        The name of the step to mark complete.

    .PARAMETER Details
        Optional details about the completion.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('prerequisites', 'network', 'certificates', 'ports', 'adfs-install', 'adfs-config', 'applications', 'validation')]
        [string]$StepName,

        [Parameter()]
        [string]$Details
    )

    $state = Get-WizardState

    $state.completedSteps.$StepName.completed = $true
    $state.completedSteps.$StepName.timestamp = (Get-Date).ToUniversalTime().ToString("o")
    $state.completedSteps.$StepName.details = $Details

    Save-WizardState -State $state
}

function Set-StepIncomplete {
    <#
    .SYNOPSIS
        Marks a wizard step as incomplete.

    .PARAMETER StepName
        The name of the step to mark incomplete.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('prerequisites', 'network', 'certificates', 'ports', 'adfs-install', 'adfs-config', 'applications', 'validation')]
        [string]$StepName
    )

    $state = Get-WizardState

    $state.completedSteps.$StepName.completed = $false
    $state.completedSteps.$StepName.timestamp = $null
    $state.completedSteps.$StepName.details = $null

    Save-WizardState -State $state
}

function Test-StepComplete {
    <#
    .SYNOPSIS
        Tests if a wizard step is complete.

    .PARAMETER StepName
        The name of the step to check.

    .OUTPUTS
        $true if the step is complete, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('prerequisites', 'network', 'certificates', 'ports', 'adfs-install', 'adfs-config', 'applications', 'validation')]
        [string]$StepName
    )

    $state = Get-WizardState

    return $state.completedSteps.$StepName.completed -eq $true
}

function Get-StepStatus {
    <#
    .SYNOPSIS
        Gets the status string for a step (for menu display).

    .PARAMETER StepName
        The name of the step.

    .OUTPUTS
        Status string: 'Complete', 'Pending', 'InProgress', or 'Failed'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName
    )

    $state = Get-WizardState

    if ($state.completedSteps.PSObject.Properties.Name -contains $StepName) {
        if ($state.completedSteps.$StepName.completed) {
            return 'Complete'
        }
    }

    if ($state.currentStep -eq $StepName) {
        return 'InProgress'
    }

    return 'Pending'
}

function Get-AllStepStatuses {
    <#
    .SYNOPSIS
        Gets status for all steps (for menu display).

    .OUTPUTS
        Hashtable of step names to status strings.
    #>
    [CmdletBinding()]
    param()

    $steps = @('prerequisites', 'network', 'certificates', 'ports', 'adfs-install', 'adfs-config', 'applications', 'validation')
    $statuses = @{}

    foreach ($step in $steps) {
        $statuses[$step] = Get-StepStatus -StepName $step
    }

    return $statuses
}

function Set-CurrentStep {
    <#
    .SYNOPSIS
        Sets the currently active step.

    .PARAMETER StepName
        The name of the current step.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [string]$StepName
    )

    $state = Get-WizardState
    $state.currentStep = $StepName
    Save-WizardState -State $state
}

function Add-WizardError {
    <#
    .SYNOPSIS
        Records an error in the wizard state.

    .PARAMETER Step
        The step where the error occurred.

    .PARAMETER Message
        The error message.

    .PARAMETER Details
        Additional error details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Step,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Details
    )

    $state = Get-WizardState

    $error = [PSCustomObject]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        step      = $Step
        message   = $Message
        details   = $Details
    }

    $state.errors += $error
    Save-WizardState -State $state
}

function Add-RegisteredApp {
    <#
    .SYNOPSIS
        Records a registered application in the wizard state.

    .PARAMETER Name
        The application name.

    .PARAMETER Type
        The application type (OIDC, SAML, WSFed).

    .PARAMETER ClientId
        The client identifier.

    .PARAMETER Details
        Additional application details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('OIDC', 'SAML', 'WSFed')]
        [string]$Type,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [hashtable]$Details
    )

    $state = Get-WizardState

    $app = [PSCustomObject]@{
        name       = $Name
        type       = $Type
        clientId   = $ClientId
        registered = (Get-Date).ToUniversalTime().ToString("o")
        details    = $Details
    }

    $state.registeredApps += $app
    Save-WizardState -State $state
}

function Test-HasPreviousSession {
    <#
    .SYNOPSIS
        Tests if there's a previous session that can be resumed.

    .OUTPUTS
        $true if a previous session exists, $false otherwise.
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:StateFile) {
        try {
            $state = Get-Content $script:StateFile -Raw | ConvertFrom-Json
            # Has previous session if any step has been started
            return ($null -ne $state.currentStep) -or
                   ($state.completedSteps.PSObject.Properties.Value | Where-Object { $_.completed } | Measure-Object).Count -gt 0
        }
        catch {
            return $false
        }
    }

    return $false
}

function Reset-WizardState {
    <#
    .SYNOPSIS
        Resets the wizard state to default.

    .PARAMETER Confirm
        Requires confirmation before reset.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    if (-not $Force) {
        throw "Use -Force to confirm state reset"
    }

    if (Test-Path $script:StateFile) {
        # Backup old state
        $backupPath = $script:StateFile + ".backup." + (Get-Date -Format "yyyyMMddHHmmss")
        Copy-Item $script:StateFile $backupPath -Force
        Remove-Item $script:StateFile -Force
    }

    $script:CurrentState = $null
}

function Update-StateVersion {
    <#
    .SYNOPSIS
        Migrates state from an older version.

    .PARAMETER OldState
        The state object from an older version.

    .OUTPUTS
        Updated state object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$OldState
    )

    # For now, just update version and return
    # Add migration logic here as versions change
    $OldState.version = $script:StateVersion
    return $OldState
}

function Get-StateFilePath {
    <#
    .SYNOPSIS
        Returns the path to the state file.
    #>
    [CmdletBinding()]
    param()

    return $script:StateFile
}

function Get-StateDirectory {
    <#
    .SYNOPSIS
        Returns the path to the state directory.
    #>
    [CmdletBinding()]
    param()

    return $script:StateDirectory
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-StateDirectory'
    'Get-WizardState'
    'Save-WizardState'
    'Set-WizardStateValue'
    'Get-WizardStateValue'
    'Set-StepComplete'
    'Set-StepIncomplete'
    'Test-StepComplete'
    'Get-StepStatus'
    'Get-AllStepStatuses'
    'Set-CurrentStep'
    'Add-WizardError'
    'Add-RegisteredApp'
    'Test-HasPreviousSession'
    'Reset-WizardState'
    'Test-WizardLock'
    'New-WizardLock'
    'Remove-WizardLock'
    'Get-StateFilePath'
    'Get-StateDirectory'
)
