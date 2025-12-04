#Requires -Version 5.1
<#
.SYNOPSIS
    TUI Menu System for ADFS Setup Wizard

.DESCRIPTION
    Provides console-based menu navigation, input handling, and display
    functions optimized for Windows Server Core environments.

.NOTES
    No GUI dependencies. Works over SSH and remote PowerShell.
#>

# Module-level variables
$script:WizardName = "ADFS FROM SCRATCH"
$script:WizardVersion = "1.0.0"

# Color scheme
$script:Colors = @{
    Title      = 'Cyan'
    Border     = 'DarkCyan'
    Success    = 'Green'
    Warning    = 'Yellow'
    Error      = 'Red'
    Info       = 'Cyan'
    Prompt     = 'White'
    Muted      = 'DarkGray'
    Highlight  = 'White'
    Selected   = 'Black'
    SelectedBg = 'Cyan'
}

# Box drawing characters (ASCII compatible for all terminals)
$script:Box = @{
    TopLeft     = '+'
    TopRight    = '+'
    BottomLeft  = '+'
    BottomRight = '+'
    Horizontal  = '-'
    Vertical    = '|'
    Cross       = '+'
}

function Clear-WizardScreen {
    <#
    .SYNOPSIS
        Clears the console screen.
    #>
    [CmdletBinding()]
    param()

    Clear-Host
}

function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Gets the current console width, with fallback.
    #>
    [CmdletBinding()]
    param()

    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -lt 60) { $width = 80 }
        return $width
    }
    catch {
        return 80
    }
}

function Write-CenteredText {
    <#
    .SYNOPSIS
        Writes text centered in the console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter()]
        [ConsoleColor]$ForegroundColor = 'White',

        [Parameter()]
        [int]$Width = 0
    )

    if ($Width -eq 0) {
        $Width = Get-ConsoleWidth
    }

    $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    $paddedText = (' ' * $padding) + $Text

    Write-Host $paddedText -ForegroundColor $ForegroundColor
}

function Write-BoxedHeader {
    <#
    .SYNOPSIS
        Writes a boxed header for the wizard.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = $script:WizardName,

        [Parameter()]
        [string]$Subtitle = "",

        [Parameter()]
        [int]$Width = 76
    )

    $b = $script:Box
    $innerWidth = $Width - 2

    # Top border
    Write-Host ($b.TopLeft + ($b.Horizontal * $innerWidth) + $b.TopRight) -ForegroundColor $script:Colors.Border

    # Title line
    $titlePadding = [Math]::Max(0, [Math]::Floor(($innerWidth - $Title.Length) / 2))
    $titleLine = $b.Vertical + (' ' * $titlePadding) + $Title + (' ' * ($innerWidth - $titlePadding - $Title.Length)) + $b.Vertical
    Write-Host $titleLine -ForegroundColor $script:Colors.Title

    # Subtitle if provided
    if ($Subtitle) {
        $subtitleText = "v$script:WizardVersion - $Subtitle"
        $subtitlePadding = [Math]::Max(0, [Math]::Floor(($innerWidth - $subtitleText.Length) / 2))
        $subtitleLine = $b.Vertical + (' ' * $subtitlePadding) + $subtitleText + (' ' * ($innerWidth - $subtitlePadding - $subtitleText.Length)) + $b.Vertical
        Write-Host $subtitleLine -ForegroundColor $script:Colors.Muted
    }

    # Bottom border
    Write-Host ($b.BottomLeft + ($b.Horizontal * $innerWidth) + $b.BottomRight) -ForegroundColor $script:Colors.Border
}

function Show-WizardBanner {
    <#
    .SYNOPSIS
        Displays the wizard banner with ASCII art.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Subtitle = "Setup Wizard"
    )

    Clear-WizardScreen
    Write-Host ""

    # ASCII Art Banner
    $banner = @"
     _    ____  _____ ____    _____ ____   ___  __  __   ____   ____ ____      _  _____ ____ _   _
    / \  |  _ \|  ___/ ___|  |  ___|  _ \ / _ \|  \/  | / ___| / ___|  _ \    / \|_   _/ ___| | | |
   / _ \ | | | | |_  \___ \  | |_  | |_) | | | | |\/| | \___ \| |   | |_) |  / _ \ | || |   | |_| |
  / ___ \| |_| |  _|  ___) | |  _| |  _ <| |_| | |  | |  ___) | |___|  _ <  / ___ \| || |___|  _  |
 /_/   \_\____/|_|   |____/  |_|   |_| \_\\___/|_|  |_| |____/ \____|_| \_\/_/   \_\_| \____|_| |_|
"@

    Write-Host $banner -ForegroundColor $script:Colors.Title
    Write-Host ""
    Write-BoxedHeader -Title "Windows Server ADFS Configuration Wizard" -Subtitle $Subtitle
    Write-Host ""
}

function Show-WizardMenu {
    <#
    .SYNOPSIS
        Displays an interactive menu with keyboard navigation.

    .PARAMETER Title
        The menu title.

    .PARAMETER MenuItems
        Array of menu items. Each item should have 'Key', 'Label', and optionally 'Status'.

    .PARAMETER AllowQuit
        Whether to show the Quit option.

    .OUTPUTS
        The selected menu item key.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Main Menu",

        [Parameter(Mandatory)]
        [array]$MenuItems,

        [Parameter()]
        [switch]$AllowQuit,

        [Parameter()]
        [switch]$AllowResume,

        [Parameter()]
        [switch]$AllowHelp
    )

    $selectedIndex = 0
    $maxIndex = $MenuItems.Count - 1

    # Add special options
    $specialOptions = @()
    if ($AllowResume) { $specialOptions += @{ Key = 'R'; Label = 'Resume Previous Session' } }
    if ($AllowHelp) { $specialOptions += @{ Key = 'H'; Label = 'Help' } }
    if ($AllowQuit) { $specialOptions += @{ Key = 'Q'; Label = 'Quit' } }

    while ($true) {
        # Redraw menu
        $cursorTop = [Console]::CursorTop

        Write-Host ""
        Write-Host "  $Title" -ForegroundColor $script:Colors.Title
        Write-Host "  $('-' * $Title.Length)" -ForegroundColor $script:Colors.Border
        Write-Host ""

        # Draw menu items
        for ($i = 0; $i -lt $MenuItems.Count; $i++) {
            $item = $MenuItems[$i]
            $prefix = if ($i -eq $selectedIndex) { " >" } else { "  " }
            $number = "[$($item.Key)]"

            # Status indicator
            $status = ""
            $statusColor = $script:Colors.Muted
            switch ($item.Status) {
                'Complete'    { $status = "[DONE]"; $statusColor = $script:Colors.Success }
                'InProgress'  { $status = "[...]"; $statusColor = $script:Colors.Warning }
                'Pending'     { $status = "[    ]"; $statusColor = $script:Colors.Muted }
                'Failed'      { $status = "[FAIL]"; $statusColor = $script:Colors.Error }
                default       { $status = "" }
            }

            if ($i -eq $selectedIndex) {
                Write-Host "$prefix " -NoNewline -ForegroundColor $script:Colors.Highlight
                Write-Host "$number $($item.Label) " -NoNewline -ForegroundColor $script:Colors.SelectedBg -BackgroundColor $script:Colors.Selected
                Write-Host " $status" -ForegroundColor $statusColor
            }
            else {
                Write-Host "$prefix $number " -NoNewline -ForegroundColor $script:Colors.Muted
                Write-Host "$($item.Label) " -NoNewline -ForegroundColor $script:Colors.Prompt
                Write-Host "$status" -ForegroundColor $statusColor
            }
        }

        # Special options
        if ($specialOptions.Count -gt 0) {
            Write-Host ""
            $optionLine = "  "
            foreach ($opt in $specialOptions) {
                $optionLine += "[$($opt.Key)] $($opt.Label)  "
            }
            Write-Host $optionLine -ForegroundColor $script:Colors.Muted
        }

        Write-Host ""
        Write-Host "  Use " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host "[UP/DOWN]" -NoNewline -ForegroundColor $script:Colors.Highlight
        Write-Host " arrows, " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host "[NUMBER]" -NoNewline -ForegroundColor $script:Colors.Highlight
        Write-Host " keys, or " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host "[ENTER]" -NoNewline -ForegroundColor $script:Colors.Highlight
        Write-Host " to select" -ForegroundColor $script:Colors.Muted

        # Read key
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $maxIndex }
            }
            40 { # Down arrow
                $selectedIndex = if ($selectedIndex -lt $maxIndex) { $selectedIndex + 1 } else { 0 }
            }
            13 { # Enter
                return $MenuItems[$selectedIndex].Key
            }
            default {
                # Check for number/letter keys
                $char = $key.Character.ToString().ToUpper()

                # Check menu items
                $matchedItem = $MenuItems | Where-Object { $_.Key -eq $char }
                if ($matchedItem) {
                    return $matchedItem.Key
                }

                # Check special options
                $matchedSpecial = $specialOptions | Where-Object { $_.Key -eq $char }
                if ($matchedSpecial) {
                    return $matchedSpecial.Key
                }
            }
        }

        # Move cursor back to redraw
        try {
            $linesToClear = $MenuItems.Count + 10
            [Console]::SetCursorPosition(0, [Math]::Max(0, $cursorTop))
            for ($i = 0; $i -lt $linesToClear; $i++) {
                Write-Host (' ' * (Get-ConsoleWidth))
            }
            [Console]::SetCursorPosition(0, $cursorTop)
        }
        catch {
            Clear-WizardScreen
            Show-WizardBanner
        }
    }
}

function Show-WizardStepMenu {
    <#
    .SYNOPSIS
        Shows the main wizard step menu with status indicators.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StepStatus
    )

    $menuItems = @(
        @{ Key = '1'; Label = 'Prerequisites Check'; Status = $StepStatus['prerequisites'] }
        @{ Key = '2'; Label = 'Network & DNS Configuration'; Status = $StepStatus['network'] }
        @{ Key = '3'; Label = 'Certificate Management'; Status = $StepStatus['certificates'] }
        @{ Key = '4'; Label = 'Port Forwarding Test'; Status = $StepStatus['ports'] }
        @{ Key = '5'; Label = 'ADFS Installation'; Status = $StepStatus['adfs-install'] }
        @{ Key = '6'; Label = 'ADFS Configuration'; Status = $StepStatus['adfs-config'] }
        @{ Key = '7'; Label = 'Application Registration'; Status = $StepStatus['applications'] }
        @{ Key = '8'; Label = 'Validation & Testing'; Status = $StepStatus['validation'] }
    )

    return Show-WizardMenu -Title "Setup Steps" -MenuItems $menuItems -AllowQuit -AllowHelp
}

function Read-WizardInput {
    <#
    .SYNOPSIS
        Prompts for user input with validation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [string]$Default = "",

        [Parameter()]
        [scriptblock]$Validator,

        [Parameter()]
        [string]$ValidationMessage = "Invalid input",

        [Parameter()]
        [switch]$Required
    )

    while ($true) {
        $displayPrompt = $Prompt
        if ($Default) {
            $displayPrompt += " [$Default]"
        }
        $displayPrompt += ": "

        Write-Host ""
        Write-Host "  $displayPrompt" -NoNewline -ForegroundColor $script:Colors.Prompt
        $input = Read-Host

        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($Default) {
                $input = $Default
            }
            elseif ($Required) {
                Write-Host "  This field is required." -ForegroundColor $script:Colors.Error
                continue
            }
        }

        if ($Validator) {
            $isValid = & $Validator $input
            if (-not $isValid) {
                Write-Host "  $ValidationMessage" -ForegroundColor $script:Colors.Error
                continue
            }
        }

        return $input
    }
}

function Read-WizardSecureInput {
    <#
    .SYNOPSIS
        Prompts for secure/password input.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [switch]$Confirm
    )

    Write-Host ""
    Write-Host "  ${Prompt}: " -NoNewline -ForegroundColor $script:Colors.Prompt
    $secure = Read-Host -AsSecureString

    if ($Confirm) {
        Write-Host "  Confirm ${Prompt}: " -NoNewline -ForegroundColor $script:Colors.Prompt
        $confirm = Read-Host -AsSecureString

        # Compare secure strings
        $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm)
        try {
            $plain1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
            $plain2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
            if ($plain1 -ne $plain2) {
                Write-Host "  Inputs do not match. Please try again." -ForegroundColor $script:Colors.Error
                return Read-WizardSecureInput -Prompt $Prompt -Confirm
            }
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
        }
    }

    return $secure
}

function Show-WizardConfirmation {
    <#
    .SYNOPSIS
        Shows a Yes/No confirmation prompt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [bool]$Default = $false
    )

    $defaultText = if ($Default) { "Y/n" } else { "y/N" }

    Write-Host ""
    Write-Host "  $Message " -NoNewline -ForegroundColor $script:Colors.Warning
    Write-Host "[$defaultText]: " -NoNewline -ForegroundColor $script:Colors.Muted

    $response = Read-Host

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    return $response.ToUpper().StartsWith('Y')
}

function Write-WizardStatus {
    <#
    .SYNOPSIS
        Writes a status message with appropriate coloring.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Muted')]
        [string]$Type = 'Info'
    )

    $color = $script:Colors[$Type]
    $prefix = switch ($Type) {
        'Success' { "[+]" }
        'Warning' { "[!]" }
        'Error'   { "[-]" }
        'Info'    { "[*]" }
        'Muted'   { "   " }
    }

    Write-Host "  $prefix $Message" -ForegroundColor $color
}

function Show-WizardProgress {
    <#
    .SYNOPSIS
        Shows a progress bar for long operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [int]$PercentComplete,

        [Parameter()]
        [string]$Status = ""
    )

    $width = 40
    $complete = [Math]::Floor($width * $PercentComplete / 100)
    $remaining = $width - $complete

    $bar = "[" + ("=" * $complete) + (">" * [Math]::Min(1, $remaining)) + (" " * [Math]::Max(0, $remaining - 1)) + "]"

    Write-Host "`r  $Activity $bar $PercentComplete% $Status    " -NoNewline -ForegroundColor $script:Colors.Info

    if ($PercentComplete -ge 100) {
        Write-Host ""
    }
}

function Show-WizardTable {
    <#
    .SYNOPSIS
        Displays data in a formatted table.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Data,

        [Parameter()]
        [string[]]$Columns,

        [Parameter()]
        [string]$Title
    )

    if ($Title) {
        Write-Host ""
        Write-Host "  $Title" -ForegroundColor $script:Colors.Title
        Write-Host "  $('-' * $Title.Length)" -ForegroundColor $script:Colors.Border
    }

    Write-Host ""

    if ($Columns) {
        $Data | Select-Object $Columns | Format-Table -AutoSize | Out-String | ForEach-Object {
            $_.Split("`n") | ForEach-Object { Write-Host "  $_" }
        }
    }
    else {
        $Data | Format-Table -AutoSize | Out-String | ForEach-Object {
            $_.Split("`n") | ForEach-Object { Write-Host "  $_" }
        }
    }
}

function Show-WizardChecklist {
    <#
    .SYNOPSIS
        Shows a checklist of items with pass/fail status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter()]
        [string]$Title = "Checklist"
    )

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor $script:Colors.Title
    Write-Host "  $('-' * $Title.Length)" -ForegroundColor $script:Colors.Border
    Write-Host ""

    foreach ($item in $Items) {
        $icon = switch ($item.Status) {
            'Pass'    { "[X]"; $color = $script:Colors.Success }
            'Fail'    { "[ ]"; $color = $script:Colors.Error }
            'Warning' { "[!]"; $color = $script:Colors.Warning }
            'Skip'    { "[-]"; $color = $script:Colors.Muted }
            default   { "[ ]"; $color = $script:Colors.Muted }
        }

        Write-Host "  $icon " -NoNewline -ForegroundColor $color
        Write-Host $item.Name -NoNewline -ForegroundColor $script:Colors.Prompt
        if ($item.Message) {
            Write-Host " - $($item.Message)" -ForegroundColor $script:Colors.Muted
        }
        else {
            Write-Host ""
        }
    }
}

function Wait-WizardKeyPress {
    <#
    .SYNOPSIS
        Waits for any key press to continue.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Message = "Press any key to continue..."
    )

    Write-Host ""
    Write-Host "  $Message" -ForegroundColor $script:Colors.Muted
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-WizardError {
    <#
    .SYNOPSIS
        Displays an error message with optional details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Details,

        [Parameter()]
        [string]$Remediation
    )

    Write-Host ""
    Write-Host "  ERROR: $Message" -ForegroundColor $script:Colors.Error

    if ($Details) {
        Write-Host "  Details: $Details" -ForegroundColor $script:Colors.Muted
    }

    if ($Remediation) {
        Write-Host ""
        Write-Host "  To fix this:" -ForegroundColor $script:Colors.Warning
        Write-Host "  $Remediation" -ForegroundColor $script:Colors.Prompt
    }
}

function Show-WizardSuccess {
    <#
    .SYNOPSIS
        Displays a success message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string[]]$NextSteps
    )

    Write-Host ""
    Write-Host "  SUCCESS: $Message" -ForegroundColor $script:Colors.Success

    if ($NextSteps) {
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor $script:Colors.Info
        foreach ($step in $NextSteps) {
            Write-Host "    - $step" -ForegroundColor $script:Colors.Prompt
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Clear-WizardScreen'
    'Get-ConsoleWidth'
    'Write-CenteredText'
    'Write-BoxedHeader'
    'Show-WizardBanner'
    'Show-WizardMenu'
    'Show-WizardStepMenu'
    'Read-WizardInput'
    'Read-WizardSecureInput'
    'Show-WizardConfirmation'
    'Write-WizardStatus'
    'Show-WizardProgress'
    'Show-WizardTable'
    'Show-WizardChecklist'
    'Wait-WizardKeyPress'
    'Show-WizardError'
    'Show-WizardSuccess'
)
