# Implementation Tasks

## Phase 1: Core Infrastructure

### 1.1 Project Scaffolding
- [x] Create repository structure
- [x] Create README.md
- [x] Create GOALS.md
- [x] Create TASKS.md
- [x] Create STATUS.md
- [x] Create DIRECTIVES.md
- [x] Create module directory structure
- [x] Create template directory structure

### 1.2 TUI Menu System (`modules/Menu.psm1`)
- [x] Implement `Show-WizardMenu` function with keyboard navigation
- [x] Implement `Show-WizardBanner` for wizard header
- [x] Implement `Show-WizardProgress` for step tracking
- [x] Implement `Read-WizardSecureInput` for password/secret entry
- [x] Implement `Show-WizardConfirmation` for destructive actions
- [x] Implement `Write-WizardStatus` for colored output
- [x] Implement `Show-WizardTable` for data display
- [x] Implement `Show-WizardChecklist` for pass/fail displays
- [ ] Test rendering in Server Core environment
- [ ] Test rendering over SSH session

### 1.3 State Management (`modules/State.psm1`)
- [x] Define state schema (JSON structure)
- [x] Implement `Get-WizardState`
- [x] Implement `Save-WizardState`
- [x] Implement `Set-WizardStateValue` / `Get-WizardStateValue`
- [x] Implement `Set-StepComplete` / `Test-StepComplete`
- [x] Implement state migration for version upgrades
- [x] Handle concurrent execution prevention (lock file)
- [x] Implement `Test-HasPreviousSession` for resume detection
- [x] Implement `Reset-WizardState` for fresh start

### 1.4 Logging Infrastructure (`modules/Logging.psm1`)
- [x] Implement `Start-WizardTranscript`
- [x] Implement `Stop-WizardTranscript`
- [x] Implement `Write-WizardLog` (structured logging)
- [x] Implement log rotation (keep last 10 sessions)
- [x] Implement `Export-WizardLogs` for troubleshooting

---

## Phase 2: Prerequisites Module

### 2.1 Environment Validation (`modules/Prerequisites.psm1`)
- [x] `Test-IsServerCore` - Detect if running on Core
- [x] `Test-IsDomainJoined` - Verify domain membership
- [x] `Test-IsNotDomainController` - Refuse to run on DC
- [x] `Test-AdminPrivileges` - Check for elevation
- [x] `Test-PowerShellVersion` - Require 5.1+
- [x] `Test-WindowsVersion` - Require Server 2019+
- [x] `Test-RequiredModules` - Check for AD, ADFS modules

### 2.2 Network Validation
- [x] `Test-DomainControllerConnectivity` - LDAP/Kerberos to DC
- [x] `Test-DNSResolution` - Internal DNS working
- [x] `Test-InternetConnectivity` - Can reach Let's Encrypt, etc.
- [x] `Get-NetworkConfiguration` - Display current IP, DNS, gateway

### 2.3 Active Directory Validation
- [x] `Test-ADForestFunctionalLevel` - Minimum 2012 R2 for gMSA
- [x] `Test-KDSRootKey` - Check if gMSA can be created
- [x] `New-KDSRootKeyIfMissing` - Create KDS root key (with warning)
- [x] `Test-ADFSServiceAccountExists` - Check if gMSA already exists

### 2.4 Prerequisites Wizard Step
- [x] Combine all checks into single wizard step
- [x] Display results in checklist format
- [x] Block progression if critical checks fail
- [x] Allow skipping warnings with confirmation
- [x] Offer to create KDS Root Key if missing
- [x] Install required Windows features if missing

---

## Phase 3: Certificate Management

### 3.1 Certificate Module (`modules/Certificates.psm1`)
- [ ] `Get-ADFSCertificateRequirements` - Document what certs are needed
- [ ] `Test-CertificateExists` - Check for existing ADFS cert
- [x] Self-signed certificate generation (built into wizard step)
- [x] PFX import (built into wizard step)
- [ ] `Request-LetsEncryptCertificate` - ACME via win-acme
- [ ] `Install-WinAcme` - Download and install win-acme
- [ ] `Test-CertificateValidity` - Check expiry, chain, etc.

### 3.2 Certificate Wizard Step
- [x] Menu: Self-signed / Import PFX / Let's Encrypt / Skip
- [x] Prompt for federation service name (FQDN)
- [x] Validate FQDN is DNS-resolvable
- [x] Execute certificate acquisition
- [x] Store certificate info in state
- [ ] Let's Encrypt integration (placeholder)

---

## Phase 4: Port/Connectivity Testing

### 4.1 Connectivity Module (`modules/Connectivity.psm1`)
- [ ] `Test-PortOpen` - Local port listener test
- [ ] `Test-ExternalConnectivity` - Use external service to test inbound
- [ ] `Start-TemporaryListener` - HTTP listener for port test
- [ ] `Test-ReverseProxyConnectivity` - Validate Nginx is forwarding
- [ ] `Get-RequiredPorts` - List of ports ADFS needs

### 4.2 External Connectivity Test Strategy
- [ ] Option 1: User manually tests with phone/external device
- [ ] Option 2: Use public "port check" API service
- [ ] Option 3: User confirms Nginx is configured
- [ ] Document Nginx configuration requirements

### 4.3 Connectivity Wizard Step
- [ ] Display required ports
- [ ] Run local tests
- [ ] Guide user through external test
- [ ] Store connectivity results in state

---

## Phase 5: ADFS Installation

### 5.1 ADFS Module (`modules/ADFS.psm1`)
- [ ] `Install-ADFSWindowsFeature` - Add Windows feature
- [ ] `New-ADFSGMSAAccount` - Create gMSA in AD
- [ ] `Install-ADFSFarm` - Initial ADFS configuration
- [ ] `Get-ADFSConfiguration` - Read current config
- [ ] `Test-ADFSHealth` - Verify ADFS is running
- [ ] `Set-ADFSProperties` - Configure ADFS settings
- [ ] `Enable-ADFSEndpoints` - Enable required endpoints

### 5.2 ADFS Service Configuration
- [ ] Configure token signing certificate
- [ ] Configure token decryption certificate
- [ ] Configure SSL certificate
- [ ] Set federation service display name
- [ ] Configure primary authentication methods
- [ ] Enable modern authentication endpoints

### 5.3 OIDC/OAuth2 Configuration
- [ ] Enable OAuth2 endpoints
- [ ] Configure OIDC discovery metadata
- [ ] Set token lifetimes
- [ ] Configure claims rules

### 5.4 ADFS Installation Wizard Step
- [ ] Check if ADFS already installed
- [ ] If fresh: full installation
- [ ] If existing: offer reconfiguration
- [ ] Progress indicators for long operations
- [ ] Validation after installation

---

## Phase 6: Application Registration

### 6.1 Applications Module (`modules/Applications.psm1`)
- [ ] `Get-ApplicationTemplates` - List available templates
- [ ] `New-ADFSApplicationFromTemplate` - Create app from template
- [ ] `New-ADFSRelyingPartyTrust` - SAML/WS-Fed apps
- [ ] `New-ADFSApplicationGroup` - OIDC apps
- [ ] `Get-ADFSApplications` - List registered apps
- [ ] `Remove-ADFSApplication` - Delete app registration
- [ ] `Export-ADFSApplicationConfig` - Export for documentation

### 6.2 Application Templates (`templates/apps/`)
- [ ] `tailscale.json` - Tailscale OIDC configuration
- [ ] `generic-oidc.json` - Generic OIDC template
- [ ] `generic-saml.json` - Generic SAML template
- [ ] Template schema documentation

### 6.3 Tailscale Integration
- [ ] Document Tailscale OIDC requirements
- [ ] Create Application Group
- [ ] Configure redirect URIs
- [ ] Set up claims (email, groups)
- [ ] Generate client credentials
- [ ] Output configuration for Tailscale admin console

### 6.4 Application Wizard Step
- [ ] List available templates
- [ ] Guided setup for each app type
- [ ] Display generated secrets (once only!)
- [ ] Store app registrations in state

---

## Phase 7: Validation and Testing

### 7.1 Validation Module (`modules/Validation.psm1`)
- [ ] `Test-ADFSMetadataEndpoint` - Federation metadata accessible
- [ ] `Test-ADFSOIDCDiscovery` - OIDC discovery working
- [ ] `Test-ADFSTokenEndpoint` - Token endpoint responds
- [ ] `Test-ADFSAuthentication` - End-to-end auth test
- [ ] `Get-ADFSHealthReport` - Comprehensive health check

### 7.2 Validation Wizard Step
- [ ] Run all health checks
- [ ] Display results summary
- [ ] Provide troubleshooting guidance for failures
- [ ] Generate final report

---

## Phase 8: Main Wizard Integration

### 8.1 Entry Point (`Start-ADFSWizard.ps1`)
- [x] Parameter handling (Resume, SkipPrerequisites, Reset)
- [x] Module loading (download if needed for iex scenario)
- [x] State initialization
- [x] Main menu loop
- [x] Step orchestration
- [x] Error handling and recovery
- [x] Clean exit with lock cleanup

### 8.2 Wizard Flow
- [x] Welcome screen with disclaimer
- [x] Resume detection and prompt
- [x] Main menu with step status indicators
- [x] Sequential step execution with dependencies
- [ ] Final summary and next steps

---

## Phase 9: Documentation and Polish

### 9.1 User Documentation
- [ ] Nginx configuration guide
- [ ] DNS configuration guide
- [ ] Troubleshooting guide
- [ ] Security hardening guide
- [ ] Application integration guides

### 9.2 Code Quality
- [ ] Consistent error handling
- [ ] Input validation
- [ ] Comment coverage
- [ ] Remove debug code
- [ ] Test on fresh Server 2019 Core VM

### 9.3 Release Preparation
- [ ] Version numbering
- [ ] Changelog
- [ ] GitHub release
- [ ] Test iex deployment method
