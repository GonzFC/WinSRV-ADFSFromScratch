#Requires -Version 5.1
<#
.SYNOPSIS
    Logging Infrastructure for ADFS Setup Wizard

.DESCRIPTION
    Provides transcript and structured logging for troubleshooting.
    Includes log rotation to prevent disk space issues.

.NOTES
    Logs are stored in C:\ADFSFromScratch\Logs\
#>

# Module-level variables
$script:LogDirectory = "C:\ADFSFromScratch\Logs"
$script:MaxLogFiles = 10
$script:CurrentLogFile = $null
$script:TranscriptStarted = $false

function Initialize-LogDirectory {
    <#
    .SYNOPSIS
        Creates the log directory if it doesn't exist.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:LogDirectory)) {
        try {
            New-Item -Path $script:LogDirectory -ItemType Directory -Force | Out-Null
            Write-Verbose "Created log directory: $script:LogDirectory"
        }
        catch {
            Write-Warning "Failed to create log directory: $_"
        }
    }
}

function Start-WizardTranscript {
    <#
    .SYNOPSIS
        Starts a PowerShell transcript for the session.

    .OUTPUTS
        The path to the transcript file.
    #>
    [CmdletBinding()]
    param()

    if ($script:TranscriptStarted) {
        Write-Verbose "Transcript already started"
        return $script:CurrentLogFile
    }

    Initialize-LogDirectory

    # Rotate old logs
    Invoke-LogRotation

    # Create new log file
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CurrentLogFile = Join-Path $script:LogDirectory "wizard-$timestamp.log"

    try {
        Start-Transcript -Path $script:CurrentLogFile -Append | Out-Null
        $script:TranscriptStarted = $true
        Write-Verbose "Started transcript: $script:CurrentLogFile"
        return $script:CurrentLogFile
    }
    catch {
        Write-Warning "Failed to start transcript: $_"
        return $null
    }
}

function Stop-WizardTranscript {
    <#
    .SYNOPSIS
        Stops the PowerShell transcript.
    #>
    [CmdletBinding()]
    param()

    if ($script:TranscriptStarted) {
        try {
            Stop-Transcript | Out-Null
            $script:TranscriptStarted = $false
            Write-Verbose "Stopped transcript"
        }
        catch {
            # Transcript may have already been stopped
            $script:TranscriptStarted = $false
        }
    }
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Removes old log files, keeping only the most recent.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:LogDirectory)) {
        return
    }

    try {
        $logFiles = Get-ChildItem -Path $script:LogDirectory -Filter "wizard-*.log" |
            Sort-Object LastWriteTime -Descending

        if ($logFiles.Count -gt $script:MaxLogFiles) {
            $filesToRemove = $logFiles | Select-Object -Skip $script:MaxLogFiles
            foreach ($file in $filesToRemove) {
                Remove-Item $file.FullName -Force
                Write-Verbose "Removed old log: $($file.Name)"
            }
        }
    }
    catch {
        Write-Warning "Failed to rotate logs: $_"
    }
}

function Write-WizardLog {
    <#
    .SYNOPSIS
        Writes a structured log entry.

    .PARAMETER Level
        Log level: Debug, Info, Warning, Error

    .PARAMETER Message
        The log message.

    .PARAMETER Step
        The wizard step where this log was generated.

    .PARAMETER Data
        Additional data to include in the log.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Step,

        [Parameter()]
        [hashtable]$Data
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level]"

    if ($Step) {
        $logEntry += " [$Step]"
    }

    $logEntry += " $Message"

    if ($Data) {
        $dataString = ($Data.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
        $logEntry += " | $dataString"
    }

    # Write to console with appropriate level
    switch ($Level) {
        'Debug'   { Write-Verbose $logEntry }
        'Info'    { Write-Verbose $logEntry }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
    }

    # Also write to a structured log file if transcript isn't capturing it
    Write-StructuredLog -Entry $logEntry
}

function Write-StructuredLog {
    <#
    .SYNOPSIS
        Writes to a structured log file (in addition to transcript).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Entry
    )

    Initialize-LogDirectory

    $structuredLogFile = Join-Path $script:LogDirectory "wizard-structured.log"

    try {
        Add-Content -Path $structuredLogFile -Value $Entry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail - logging shouldn't break the wizard
    }
}

function Get-LogDirectory {
    <#
    .SYNOPSIS
        Returns the path to the log directory.
    #>
    [CmdletBinding()]
    param()

    return $script:LogDirectory
}

function Get-CurrentLogFile {
    <#
    .SYNOPSIS
        Returns the path to the current log file.
    #>
    [CmdletBinding()]
    param()

    return $script:CurrentLogFile
}

function Get-RecentLogs {
    <#
    .SYNOPSIS
        Gets the most recent log entries.

    .PARAMETER Lines
        Number of lines to return.

    .OUTPUTS
        Array of log lines.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Lines = 50
    )

    if (-not $script:CurrentLogFile -or -not (Test-Path $script:CurrentLogFile)) {
        return @()
    }

    try {
        return Get-Content $script:CurrentLogFile -Tail $Lines
    }
    catch {
        return @()
    }
}

function Write-SecureMask {
    <#
    .SYNOPSIS
        Returns a masked version of sensitive data for logging.

    .PARAMETER Value
        The value to mask.

    .PARAMETER ShowLast
        Number of characters to show at the end.

    .OUTPUTS
        Masked string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter()]
        [int]$ShowLast = 4
    )

    if ($Value.Length -le $ShowLast) {
        return "****"
    }

    $masked = "*" * ($Value.Length - $ShowLast)
    $visible = $Value.Substring($Value.Length - $ShowLast)

    return $masked + $visible
}

function Export-WizardLogs {
    <#
    .SYNOPSIS
        Exports all logs to a zip file for troubleshooting.

    .PARAMETER OutputPath
        The path for the output zip file.

    .OUTPUTS
        Path to the created zip file.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $OutputPath = Join-Path $env:TEMP "ADFSWizardLogs-$timestamp.zip"
    }

    try {
        # Stop transcript temporarily to release file locks
        $wasTranscriptRunning = $script:TranscriptStarted
        if ($wasTranscriptRunning) {
            Stop-WizardTranscript
        }

        Compress-Archive -Path "$script:LogDirectory\*" -DestinationPath $OutputPath -Force

        # Restart transcript
        if ($wasTranscriptRunning) {
            Start-WizardTranscript | Out-Null
        }

        return $OutputPath
    }
    catch {
        Write-Warning "Failed to export logs: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-LogDirectory'
    'Start-WizardTranscript'
    'Stop-WizardTranscript'
    'Invoke-LogRotation'
    'Write-WizardLog'
    'Get-LogDirectory'
    'Get-CurrentLogFile'
    'Get-RecentLogs'
    'Write-SecureMask'
    'Export-WizardLogs'
)
