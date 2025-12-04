# Implementation Tasks

## Phase 1: Core Infrastructure

### 1.1 Project Scaffolding
- [x] Create repository structure
- [x] Create README.md
- [x] Create GOALS.md
- [x] Create TASKS.md
- [x] Create STATUS.md
- [x] Create DIRECTIVES.md
- [ ] Create module directory structure
- [ ] Create template directory structure

### 1.2 TUI Menu System (`modules/Menu.psm1`)
- [ ] Implement `Show-Menu` function with keyboard navigation
- [ ] Implement `Show-Banner` for wizard header
- [ ] Implement `Show-Progress` for step tracking
- [ ] Implement `Read-SecureInput` for password/secret entry
- [ ] Implement `Show-Confirmation` for destructive actions
- [ ] Implement `Write-StatusLine` for colored output
- [ ] Implement `Show-Table` for data display
- [ ] Test rendering in Server Core environment
- [ ] Test rendering over SSH session

### 1.3 State Management (`modules/State.psm1`)
- [ ] Define state schema (JSON structure)
- [ ] Implement `Initialize-WizardState`
- [ ] Implement `Save-WizardState`
- [ ] Implement `Get-WizardState`
- [ ] Implement `Update-WizardStep`
- [ ] Implement `Test-StepCompleted`
- [ ] Implement state migration for version upgrades
- [ ] Create state directory (`C:\ADFSFromScratch\State\`)
- [ ] Handle concurrent execution prevention (lock file)

### 1.4 Logging Infrastructure
- [ ] Implement `Start-WizardTranscript`
- [ ] Implement `Stop-WizardTranscript`
- [ ] Implement `Write-WizardLog` (structured logging)
- [ ] Create log directory (`C:\ADFSFromScratch\Logs\`)
- [ ] Implement log rotation (keep last 10 sessions)

---

## Phase 2: Prerequisites Module

### 2.1 Environment Validation (`modules/Prerequisites.psm1`)
- [ ] `Test-IsServerCore` - Detect if running on Core
- [ ] `Test-IsDomainJoined` - Verify domain membership
- [ ] `Test-IsNotDomainController` - Refuse to run on DC
- [ ] `Test-AdminPrivileges` - Check for elevation
- [ ] `Test-PowerShellVersion` - Require 5.1+
- [ ] `Test-WindowsVersion` - Require Server 2019+
- [ ] `Test-RequiredModules` - Check for ADDSDeployment, ADFS modules

### 2.2 Network Validation
- [ ] `Test-DomainControllerConnectivity` - LDAP/Kerberos to DC
- [ ] `Test-DNSResolution` - Internal DNS working
- [ ] `Test-InternetConnectivity` - Can reach Let's Encrypt, etc.
- [ ] `Get-NetworkConfiguration` - Display current IP, DNS, gateway

### 2.3 Active Directory Validation
- [ ] `Test-ADForestFunctionalLevel` - Minimum 2012 R2 for gMSA
- [ ] `Test-KDSRootKey` - Check if gMSA can be created
- [ ] `New-KDSRootKeyIfMissing` - Create KDS root key (with warning)
- [ ] `Test-ADFSServiceAccountExists` - Check if gMSA already exists

### 2.4 Prerequisites Wizard Step
- [ ] Combine all checks into single wizard step
- [ ] Display results in table format
- [ ] Block progression if critical checks fail
- [ ] Allow skipping warnings with confirmation

---

## Phase 3: Certificate Management

### 3.1 Certificate Module (`modules/Certificates.psm1`)
- [ ] `Get-ADFSCertificateRequirements` - Document what certs are needed
- [ ] `Test-CertificateExists` - Check for existing ADFS cert
- [ ] `New-SelfSignedADFSCertificate` - For testing only
- [ ] `Import-PFXCertificate` - Import existing cert
- [ ] `Request-LetsEncryptCertificate` - ACME via win-acme
- [ ] `Install-WinAcme` - Download and install win-acme
- [ ] `Test-CertificateValidity` - Check expiry, chain, etc.
- [ ] `Get-CertificateThumbprint` - Helper function

### 3.2 Certificate Wizard Step
- [ ] Menu: Self-signed / Import PFX / Let's Encrypt
- [ ] Prompt for federation service name (FQDN)
- [ ] Validate FQDN is DNS-resolvable
- [ ] Execute certificate acquisition
- [ ] Store certificate info in state

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
- [ ] Parameter handling (resume, skip checks, etc.)
- [ ] Module loading (download if needed for iex scenario)
- [ ] State initialization
- [ ] Main menu loop
- [ ] Step orchestration
- [ ] Error handling and recovery
- [ ] Clean exit

### 8.2 Wizard Flow
- [ ] Welcome screen with disclaimer
- [ ] Resume detection and prompt
- [ ] Main menu with step status
- [ ] Sequential step execution
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
