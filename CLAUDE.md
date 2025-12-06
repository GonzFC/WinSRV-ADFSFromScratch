# Claude Code Context - ADFS From Scratch

> **Quick Context File** - Read this first to get up to speed fast.

## Project Summary

**What:** PowerShell TUI wizard to set up ADFS on Windows Server 2019 Core
**Why:** Self-hosted identity provider for Tailscale, web apps, OIDC/SAML authentication
**How:** Interactive menu-driven script, run via `iex` from GitHub

## Current State (as of 2024-12-04)

### Completed
- Full TUI menu system with keyboard navigation
- State management with JSON persistence and resume capability
- Logging with transcripts and rotation
- Prerequisites module (15+ environment checks)
- Main wizard with steps 1-3 working
- All core infrastructure ready

### Not Yet Implemented
- Step 4: Port/Connectivity testing
- Step 5: ADFS installation (gMSA, feature install, farm config)
- Step 6: ADFS configuration (endpoints, OAuth2)
- Step 7: Application registration (Tailscale template)
- Step 8: Validation and testing
- Let's Encrypt integration

## Architecture

```
Internet → Nginx (Let's Encrypt) → ADFS Server (2019 Core) → Domain Controller
              TCP 443                    TCP 443                 LDAP/Kerberos
```

**Key Decisions:**
- Nginx reverse proxy (NOT WAP) - user preference, lighter weight
- gMSA service account - security best practice
- WID database - single server, simple backup
- Windows Server 2019 - user's environment
- No MFA in v1.0 - focus on core functionality

## File Structure

```
WinSRV-ADFSFromScratch/
├── Start-ADFSWizard.ps1         # Entry point - run this
├── modules/
│   ├── Menu.psm1                # TUI (Show-WizardMenu, banners, etc.)
│   ├── State.psm1               # Persistence (Get/Save-WizardState)
│   ├── Logging.psm1             # Transcripts (Start/Stop-WizardTranscript)
│   └── Prerequisites.psm1       # Checks (Test-*, Invoke-PrerequisitesCheck)
├── templates/apps/              # App registration templates (empty)
├── README.md                    # User-facing docs
├── GOALS.md                     # 10 project objectives
├── TASKS.md                     # Detailed task breakdown
├── STATUS.md                    # Progress tracking
├── DIRECTIVES.md                # Coding standards
└── CLAUDE.md                    # This file
```

## Key Functions to Know

### Menu.psm1
- `Show-WizardBanner` - ASCII art header
- `Show-WizardMenu` - Arrow key navigation menu
- `Show-WizardChecklist` - Pass/fail display
- `Read-WizardInput` - Validated text input
- `Write-WizardStatus` - Colored status messages

### State.psm1
- `Get-WizardState` / `Save-WizardState` - JSON persistence
- `Set-StepComplete` / `Test-StepComplete` - Step tracking
- `New-WizardLock` / `Remove-WizardLock` - Concurrent execution prevention

### Prerequisites.psm1
- `Invoke-PrerequisitesCheck` - Run all checks
- `Test-IsNotDomainController` - Critical security check
- `Test-KDSRootKey` / `New-KDSRootKeyIfMissing` - gMSA support
- `Install-RequiredFeatures` - RSAT tools installation

## Next Session Priority

1. **Build `modules/ADFS.psm1`** - Core ADFS installation:
   - `Install-ADFSWindowsFeature`
   - `New-ADFSGMSAAccount`
   - `Install-ADFSFarm`
   - `Set-ADFSProperties`

2. **Update `Start-ADFSWizard.ps1`** - Wire up step 5

3. **Build `modules/Applications.psm1`** - App registration:
   - Tailscale OIDC template
   - Generic OIDC/SAML templates

## User Context

- User owns the script and trusts iex deployment
- Has Windows Server 2019 Core adjacent to DC
- Owns public domain with fixed IP
- Primary goal: Tailscale OIDC authentication
- Wants minimal server footprint ("Unix philosophy on Microsoft")
- No Azure/cloud dependencies preferred

## Testing

The wizard can be tested on Windows with:
```powershell
# From repo root
.\Start-ADFSWizard.ps1

# Or simulate iex deployment
$url = "https://raw.githubusercontent.com/GonzFC/WinSRV-ADFSFromScratch/main/Start-ADFSWizard.ps1"
iex (irm $url)
```

State is stored in: `C:\ADFSFromScratch\State\wizard-state.json`
Logs are stored in: `C:\ADFSFromScratch\Logs\`

## Quick Commands

```powershell
# Reset wizard state
Remove-Item C:\ADFSFromScratch -Recurse -Force

# Check ADFS status (after installation)
Get-ADFSProperties
Get-ADFSEndpoint | Where Enabled

# Test ADFS endpoints
Invoke-WebRequest "https://adfs.domain.com/federationmetadata/2007-06/federationmetadata.xml"
Invoke-WebRequest "https://adfs.domain.com/.well-known/openid-configuration"
```
