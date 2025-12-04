# ADFS From Scratch

A PowerShell TUI wizard that transforms a Windows Server 2019 Core into a fully functional Active Directory Federation Services (ADFS) server.

## Quick Start

Run directly from PowerShell on your **domain-joined Windows Server 2019 Core** (not on the Domain Controller):

```powershell
iex (irm 'https://raw.githubusercontent.com/GonzFC/WinSRV-ADFSFromScratch/main/Start-ADFSWizard.ps1')
```

## What This Does

This wizard automates the complex process of setting up ADFS with:

- **Interactive TUI menus** designed for Server Core (no GUI required)
- **Idempotent execution** - run it multiple times safely, it picks up where it left off
- **Prerequisites validation** - checks domain membership, connectivity, permissions
- **gMSA setup** - creates and configures Group Managed Service Account
- **Certificate management** - handles Let's Encrypt or existing certificates
- **Port connectivity testing** - validates external access through your reverse proxy
- **ADFS installation and configuration** - the actual federation service
- **Application registration** - pre-configured templates for common apps (Tailscale, etc.)

## Architecture

```
Internet → Nginx (SSL/Let's Encrypt) → ADFS Server → Domain Controller
              TCP 443                    TCP 443          LDAP/Kerberos
```

This wizard configures the **ADFS Server** component. You'll need:

1. **Domain Controller** - existing AD DS with DNS
2. **ADFS Server** - Windows Server 2019 Core, domain-joined (this wizard)
3. **Nginx Reverse Proxy** - Linux box with Let's Encrypt (separate setup)

## Requirements

### ADFS Server (where you run this wizard)
- Windows Server 2019 (Core or Desktop Experience)
- Domain-joined to your AD forest
- Domain Admin or delegated ADFS admin credentials
- Network access to Domain Controller
- Static internal IP address

### Domain Controller
- Windows Server 2016+ (for gMSA support)
- KDS Root Key configured (wizard will prompt to create if missing)
- DNS zone for your domain

### Network
- Public domain name (e.g., `adfs.yourdomain.com`)
- Fixed public IP address
- Nginx reverse proxy (or similar) for SSL termination
- TCP 443 forwarded through to Nginx

## Features

### Identity Provider Capabilities
Once configured, your ADFS server can authenticate:

- **Windows devices** - Domain join from anywhere via Workplace Join
- **WS-Federation apps** - Classic Microsoft authentication
- **SAML 2.0 apps** - Enterprise SSO standard
- **OAuth2/OIDC apps** - Modern authentication (Tailscale, custom apps, etc.)

### Included Application Templates
- Tailscale (OIDC)
- Generic OIDC application
- Generic SAML 2.0 application
- More coming...

## Security Considerations

- **Never run ADFS on a Domain Controller** - This wizard enforces this
- **Use gMSA** - Automatic password rotation, no stored credentials
- **Reverse proxy recommended** - Don't expose ADFS directly to internet
- **Certificate management** - Let's Encrypt auto-renewal supported

## Logging

The wizard creates transcripts in:
```
C:\ADFSFromScratch\Logs\
```

ADFS events are logged to Windows Event Log:
- `Applications and Services Logs > AD FS > Admin`
- `Security` log (authentication events)

For centralized logging, forward these events to Graylog/ELK using Winlogbeat or NXLog.

## Session Resume

If the wizard is interrupted, it saves state to:
```
C:\ADFSFromScratch\State\wizard-state.json
```

Re-run the wizard and select **[R] Resume** to continue.

## Project Structure

```
WinSRV-ADFSFromScratch/
├── Start-ADFSWizard.ps1      # Main entry point (run via iex)
├── modules/
│   ├── Menu.psm1             # TUI menu system
│   ├── Prerequisites.psm1    # Validation checks
│   ├── Certificates.psm1     # Certificate management
│   ├── ADFS.psm1             # ADFS installation/config
│   ├── Applications.psm1     # App registration templates
│   └── State.psm1            # Session state management
├── templates/
│   └── apps/                 # Application registration templates
├── README.md
├── GOALS.md
├── TASKS.md
├── STATUS.md
└── DIRECTIVES.md
```

## License

MIT License - Use at your own risk.

## Contributing

Issues and PRs welcome at: https://github.com/GonzFC/WinSRV-ADFSFromScratch
