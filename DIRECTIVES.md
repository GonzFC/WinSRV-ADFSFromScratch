# Project Directives

Design principles, constraints, and coding standards for the ADFS From Scratch project.

---

## Core Principles

### 1. Server Core First
Everything must work without a GUI. Test on Server Core before Desktop Experience.

- No GUI dialogs (`[System.Windows.Forms]` is forbidden)
- No browser launches (display URLs for user to open)
- Console-only output with ANSI colors where supported
- Must work over SSH and remote PowerShell

### 2. Idempotent by Design
Running the wizard twice must be safe and produce the same result.

- Always check state before acting
- Skip already-completed steps
- Use `-ErrorAction SilentlyContinue` where appropriate
- Never fail on "already exists" conditions

### 3. Fail Fast, Fail Clearly
Don't hide errors. Stop and explain.

- Validate inputs before expensive operations
- Provide actionable error messages
- Include remediation steps in errors
- Log all failures for troubleshooting

### 4. Security by Default
Refuse insecure configurations.

- Never run on Domain Controller
- Enforce gMSA (no plaintext passwords)
- Require TLS 1.2+ for all endpoints
- Never store secrets in state files
- Warn about direct internet exposure

### 5. Unix Philosophy
Do one thing well. Small, focused functions.

- Each function does one thing
- Functions are composable
- Avoid monolithic scripts
- Prefer configuration over code

---

## Technical Constraints

### PowerShell Version
- Minimum: PowerShell 5.1 (ships with Windows Server 2019)
- Do not use PowerShell 7+ features (not installed by default)
- Avoid aliases in scripts (use full cmdlet names)

### Windows Server Version
- Primary target: Windows Server 2019
- Should also work on: Windows Server 2022
- Not supported: Windows Server 2016 and earlier

### Dependencies
- Minimize external dependencies
- Built-in modules only where possible:
  - `ActiveDirectory`
  - `ADFS`
  - `ServerManager`
  - `PKI`
- Acceptable external tools:
  - `win-acme` (for Let's Encrypt, downloaded by wizard)

### Network
- Assume firewall may block outbound (warn, don't fail)
- Support proxy environments (document, may not automate)
- IPv4 focus (IPv6 as nice-to-have)

---

## Code Standards

### Naming Conventions
```powershell
# Functions: Verb-Noun (approved verbs only)
function Test-ADFSPrerequisites { }
function Install-ADFSFarm { }
function New-ADFSGMSAAccount { }

# Variables: PascalCase for parameters, camelCase for local
param([string]$FederationServiceName)
$adfsConfig = Get-ADFSConfiguration

# Constants: SCREAMING_SNAKE_CASE
$script:DEFAULT_TOKEN_LIFETIME = 60
$script:ADFS_SERVICE_NAME = "adfssrv"
```

### Function Structure
```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        One-line description.
    .DESCRIPTION
        Detailed description if needed.
    .PARAMETER ParameterName
        Parameter description.
    .EXAMPLE
        Example usage.
    .OUTPUTS
        What the function returns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParam,

        [Parameter()]
        [string]$OptionalParam = "default"
    )

    begin {
        # One-time setup
    }

    process {
        # Main logic
    }

    end {
        # Cleanup
    }
}
```

### Error Handling
```powershell
# Use try/catch for operations that can fail
try {
    Install-WindowsFeature -Name ADFS-Federation -IncludeManagementTools
}
catch {
    Write-WizardLog -Level Error -Message "Failed to install ADFS feature: $_"
    throw
}

# Use -ErrorAction Stop for critical cmdlets
Get-ADComputer -Identity $env:COMPUTERNAME -ErrorAction Stop

# Return meaningful error objects
[PSCustomObject]@{
    Success = $false
    Error   = "Domain Controller not reachable"
    Details = $_.Exception.Message
    Remediation = "Check network connectivity and DNS settings"
}
```

### Output Standards
```powershell
# Never use Write-Host for data (use Write-Output)
# Use Write-Host only for UI elements (menus, status)

# Color coding
Write-Host "SUCCESS" -ForegroundColor Green      # Success
Write-Host "WARNING" -ForegroundColor Yellow     # Warning
Write-Host "ERROR" -ForegroundColor Red          # Error
Write-Host "INFO" -ForegroundColor Cyan          # Information
Write-Host "INPUT" -ForegroundColor White        # User prompts
```

### State File Format
```json
{
    "version": "1.0.0",
    "wizardStarted": "2024-12-04T10:00:00Z",
    "lastUpdated": "2024-12-04T10:30:00Z",
    "currentStep": "certificates",
    "configuration": {
        "federationServiceName": "adfs.contoso.com",
        "gmsaAccountName": "svc_adfs$",
        "certificateThumbprint": "ABC123..."
    },
    "completedSteps": {
        "prerequisites": {
            "completed": true,
            "timestamp": "2024-12-04T10:05:00Z"
        },
        "certificates": {
            "completed": false,
            "timestamp": null
        }
    }
}
```

---

## Security Requirements

### Secrets Handling
- Never store passwords in state files
- Never log secrets (mask in transcripts)
- Generate secrets with cryptographic randomness
- Display secrets once, never retrieve them

### Input Validation
- Validate all user input
- Sanitize paths (no injection)
- Validate FQDNs, IP addresses
- Reject obviously wrong input early

### Privilege Escalation
- Run with minimum required privileges
- Document why elevation is needed
- Don't request more than necessary

---

## Testing Requirements

### Manual Testing Checklist
Before any release:
- [ ] Fresh Windows Server 2019 Core VM
- [ ] Domain-joined to test domain
- [ ] Run full wizard end-to-end
- [ ] Test resume from each step
- [ ] Test iex deployment method
- [ ] Verify Tailscale integration works

### Test Scenarios
1. Fresh install (no existing ADFS)
2. Resume interrupted installation
3. Re-run on already-configured server
4. Invalid input handling
5. Network failure scenarios
6. Missing prerequisites

---

## Documentation Requirements

### Code Comments
- Comment the "why", not the "what"
- Document non-obvious decisions
- Include references to Microsoft docs where relevant

### User-Facing Messages
- Clear, actionable messages
- No jargon without explanation
- Include "what to do next" where applicable

### External Documentation
- Keep README current
- Update STATUS.md after each session
- Document breaking changes in CHANGELOG

---

## Forbidden Patterns

1. **No hardcoded credentials** - Ever, for any reason
2. **No `-Force` without user confirmation** - Destructive actions need consent
3. **No silent failures** - Always log, always inform
4. **No infinite loops** - Always have exit conditions
5. **No blocking operations without timeout** - Network calls must timeout
6. **No `Invoke-Expression` on user input** - Security risk
7. **No assumptions about paths** - Use environment variables
8. **No GUI dependencies** - Must work on Server Core

---

## Module Dependencies

```
Start-ADFSWizard.ps1
├── modules/Menu.psm1         (no dependencies)
├── modules/State.psm1        (no dependencies)
├── modules/Prerequisites.psm1 (depends: Menu, State)
├── modules/Certificates.psm1  (depends: Menu, State)
├── modules/Connectivity.psm1  (depends: Menu, State)
├── modules/ADFS.psm1         (depends: Menu, State, Certificates)
├── modules/Applications.psm1  (depends: Menu, State, ADFS)
└── modules/Validation.psm1    (depends: Menu, State, ADFS)
```

Load order matters. Menu and State must load first.
