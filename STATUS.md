# Project Status

> Last Updated: 2024-12-04 (End of Session 1)

## Current State: Core Infrastructure Complete

**Ready for:** ADFS Installation Module (Phase 5)

**Quick Resume:** Read `CLAUDE.md` for fast context loading.

## Overall Progress

| Phase | Status | Progress | Notes |
|-------|--------|----------|-------|
| 1. Core Infrastructure | **Complete** | 100% | Menu, State, Logging |
| 2. Prerequisites Module | **Complete** | 100% | 15+ checks |
| 3. Certificate Management | Partial | 60% | Missing Let's Encrypt |
| 4. Port/Connectivity Testing | Not Started | 0% | |
| 5. ADFS Installation | Not Started | 0% | **Next priority** |
| 6. Application Registration | Not Started | 0% | Tailscale template |
| 7. Validation and Testing | Not Started | 0% | |
| 8. Main Wizard Integration | **Complete** | 90% | Steps 1-3 working |
| 9. Documentation and Polish | In Progress | 50% | |

## What's Working Now

### Wizard Steps
| Step | Status | What It Does |
|------|--------|--------------|
| 1. Prerequisites | **Working** | Checks admin, DC connectivity, gMSA support, creates KDS key |
| 2. Network | **Working** | Gets federation FQDN, validates DNS |
| 3. Certificates | **Working** | Self-signed, PFX import, existing cert selection |
| 4-8 | Placeholder | Shows "not implemented" message |

### Core Features
- TUI with keyboard navigation (arrow keys, numbers, enter)
- State persistence (JSON) with resume capability
- Lock files prevent concurrent execution
- Transcript logging with rotation
- Module auto-loading from local or GitHub

## Files Created

```
WinSRV-ADFSFromScratch/
├── Start-ADFSWizard.ps1      # 588 lines - Main wizard
├── modules/
│   ├── Menu.psm1             # 456 lines - TUI system
│   ├── State.psm1            # 389 lines - Persistence
│   ├── Logging.psm1          # 198 lines - Transcripts
│   └── Prerequisites.psm1    # 478 lines - Checks
├── templates/apps/           # Empty (for app templates)
├── README.md                 # User documentation
├── GOALS.md                  # 10 objectives
├── TASKS.md                  # Detailed task breakdown
├── STATUS.md                 # This file
├── DIRECTIVES.md             # Coding standards
├── ARCHITECTURE.md           # System design diagrams
└── CLAUDE.md                 # Quick context for AI resume
```

**Total PowerShell:** ~2,100 lines
**Total Documentation:** ~1,500 lines

## Milestone Tracking

### Milestone 1: Foundation Complete ✅
- [x] Repository created
- [x] Documentation structure defined
- [x] Architecture decided
- [x] TUI menu system working
- [x] State management working
- [x] Main menu displays correctly

### Milestone 2: Prerequisites Working ✅
- [x] All environment checks implemented
- [x] Network validation working
- [x] AD validation working
- [x] gMSA prerequisites checked
- [x] KDS Root Key creation automated

### Milestone 3: Certificates Working (Partial)
- [x] Self-signed certificate generation
- [x] PFX import working
- [ ] Let's Encrypt integration (win-acme)

### Milestone 4: ADFS Installable (Next)
- [ ] Windows feature installation
- [ ] gMSA account creation
- [ ] ADFS farm configuration
- [ ] Basic endpoints accessible

### Milestone 5: First Application
- [ ] Tailscale OIDC integration working
- [ ] End-to-end authentication successful

### Milestone 6: Release Ready
- [ ] All wizard steps complete
- [ ] Testing on fresh VM passed
- [ ] Documentation complete
- [ ] iex deployment verified

---

## Known Issues

| ID | Description | Severity | Status |
|----|-------------|----------|--------|
| 1 | Let's Encrypt not yet integrated | Medium | Planned |
| 2 | Steps 4-8 show placeholder | Medium | In Progress |

---

## Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-12-04 | Nginx reverse proxy (not WAP) | Lighter, easier Let's Encrypt, user preference |
| 2024-12-04 | Windows Server 2019 target | User's environment |
| 2024-12-04 | gMSA service account | Security best practice |
| 2024-12-04 | WID database (not SQL) | Single-server, simple backup |
| 2024-12-04 | Skip iex signature validation | User trusts their own script |
| 2024-12-04 | MFA deferred to v2 | Focus on core functionality |
| 2024-12-04 | Inline certificate handling | Simpler than separate module |

---

## Next Session Priorities

### Priority 1: ADFS Installation Module
Create `modules/ADFS.psm1`:
- `Install-ADFSWindowsFeature`
- `New-ADFSGMSAAccount`
- `Install-ADFSFarm`
- `Test-ADFSHealth`

### Priority 2: Wire Up Step 5
Update `Start-ADFSWizard.ps1` to use ADFS module

### Priority 3: Application Templates
Create `modules/Applications.psm1` with Tailscale OIDC

---

## Testing

```powershell
# From GitHub (current branch)
iex (irm 'https://raw.githubusercontent.com/GonzFC/WinSRV-ADFSFromScratch/claude/adfs-setup-wizard-01P8WruoZrHowGdBT9DB4Mw4/Start-ADFSWizard.ps1')

# Reset state
Remove-Item C:\ADFSFromScratch -Recurse -Force
```

---

## Session Log

### 2024-12-04 - Session 1 (Complete)

**What Was Done:**
1. Planning discussion with user
2. Challenged assumptions (DC vs member server, WAP vs Nginx)
3. Documented architecture decisions
4. Built Menu.psm1 - Full TUI with keyboard navigation
5. Built State.psm1 - JSON persistence, resume, locking
6. Built Logging.psm1 - Transcripts with rotation
7. Built Prerequisites.psm1 - 15+ environment checks
8. Built Start-ADFSWizard.ps1 - Main wizard with 3 working steps
9. Created comprehensive documentation (ARCHITECTURE.md, CLAUDE.md)

**Commits:**
1. `939aed1` - Initial project documentation
2. `8cf08f3` - Core wizard infrastructure (Phase 1 & 2)

**User Context:**
- Windows Server 2019 Core (separate from DC)
- Nginx for reverse proxy
- Tailscale OIDC as first integration target
- Prefers minimal, focused servers ("Unix philosophy")
- Okay with iex deployment from GitHub
