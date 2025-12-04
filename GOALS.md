# Project Goals

## Primary Objective

Create a production-ready, idempotent PowerShell wizard that transforms a Windows Server 2019 Core into a fully functional ADFS identity provider, capable of authenticating users and devices for modern applications.

---

## Goal 1: Zero-to-ADFS in One Session

**Description:** A domain admin should be able to run the wizard once and have a working ADFS server by the end.

**Success Criteria:**
- [ ] Wizard completes all steps without manual intervention (beyond answering prompts)
- [ ] ADFS metadata endpoint is accessible internally
- [ ] At least one test application can authenticate successfully
- [ ] Total time from start to working ADFS: under 30 minutes

---

## Goal 2: Server Core Compatible TUI

**Description:** The entire wizard must work on Windows Server Core with no GUI dependencies.

**Success Criteria:**
- [ ] All menus render correctly in PowerShell console
- [ ] No GUI dialogs or pop-ups
- [ ] Keyboard-only navigation
- [ ] Clear progress indicators and status display
- [ ] Works over SSH/remote PowerShell sessions

---

## Goal 3: Idempotent and Resumable

**Description:** The wizard can be run multiple times safely and can resume from interruption.

**Success Criteria:**
- [ ] Running twice with same inputs produces same result
- [ ] Already-completed steps are detected and skipped
- [ ] State is persisted to disk after each major step
- [ ] Resume option available on startup
- [ ] No orphaned resources on failure

---

## Goal 4: Secure by Default

**Description:** The wizard should enforce security best practices and refuse insecure configurations.

**Success Criteria:**
- [ ] Refuses to run on Domain Controller
- [ ] Uses gMSA for service account (no plaintext passwords)
- [ ] Enforces TLS 1.2+ for all ADFS endpoints
- [ ] Generates strong keys/secrets
- [ ] Warns about direct internet exposure
- [ ] No credentials stored in state files

---

## Goal 5: OIDC/OAuth2 Support (Tailscale and Beyond)

**Description:** ADFS must be configured to act as an OIDC provider for modern applications.

**Success Criteria:**
- [ ] OIDC discovery endpoint works (/.well-known/openid-configuration)
- [ ] Tailscale can authenticate via OIDC
- [ ] Generic OIDC application template available
- [ ] Token endpoint returns valid JWTs
- [ ] Standard claims (sub, email, groups) properly mapped

---

## Goal 6: Multi-Protocol Support

**Description:** Support legacy and modern authentication protocols.

**Success Criteria:**
- [ ] WS-Federation working (for older Microsoft apps)
- [ ] SAML 2.0 working (for enterprise SSO)
- [ ] OAuth2/OIDC working (for modern apps)
- [ ] Device authentication / Workplace Join functional

---

## Goal 7: Certificate Flexibility

**Description:** Support multiple certificate scenarios without manual intervention.

**Success Criteria:**
- [ ] Let's Encrypt via ACME (win-acme) supported
- [ ] Existing PFX import supported
- [ ] Self-signed for testing supported
- [ ] Certificate renewal automation documented
- [ ] Proper certificate binding to ADFS services

---

## Goal 8: Network Validation

**Description:** Validate external connectivity before and after ADFS setup.

**Success Criteria:**
- [ ] Test internal DNS resolution
- [ ] Test external DNS resolution (if applicable)
- [ ] Validate reverse proxy connectivity
- [ ] Test ADFS endpoints from both internal and external perspective
- [ ] Clear error messages for connectivity failures

---

## Goal 9: Clean Uninstall Path

**Description:** While rollback isn't automated, provide clear uninstall guidance.

**Success Criteria:**
- [ ] Document all changes made to the system
- [ ] Provide uninstall checklist in wizard
- [ ] State file tracks what was created
- [ ] Clean removal of ADFS role possible

---

## Goal 10: Extensible Application Templates

**Description:** Pre-built templates for common applications, easy to add more.

**Success Criteria:**
- [ ] Tailscale template included
- [ ] Generic OIDC template included
- [ ] Generic SAML template included
- [ ] Template format documented
- [ ] Easy to add new templates via PR

---

## Future Goals (Out of Scope for v1.0)

### Self-Hosted MFA
- Certificate-based authentication
- Integration with privacyIDEA or similar
- Windows Hello for Business

### Multi-Server ADFS Farm
- SQL Server backend instead of WID
- Load-balanced ADFS nodes
- Shared certificate management

### Automated Nginx Setup
- Companion script for Nginx configuration
- Let's Encrypt automation on proxy side
- Health check endpoints

### Monitoring Integration
- Prometheus metrics exporter
- Windows Event forwarding configuration
- Alert templates for common issues
