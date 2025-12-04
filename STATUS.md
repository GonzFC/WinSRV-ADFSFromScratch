# Project Status

> Last Updated: 2024-12-04

## Current Phase: Planning & Documentation

## Overall Progress

| Phase | Status | Progress |
|-------|--------|----------|
| 1. Core Infrastructure | Not Started | 0% |
| 2. Prerequisites Module | Not Started | 0% |
| 3. Certificate Management | Not Started | 0% |
| 4. Port/Connectivity Testing | Not Started | 0% |
| 5. ADFS Installation | Not Started | 0% |
| 6. Application Registration | Not Started | 0% |
| 7. Validation and Testing | Not Started | 0% |
| 8. Main Wizard Integration | Not Started | 0% |
| 9. Documentation and Polish | In Progress | 30% |

## Milestone Tracking

### Milestone 1: Foundation Complete
- [x] Repository created
- [x] Documentation structure defined
- [x] Architecture decided
- [ ] TUI menu system working
- [ ] State management working
- [ ] Can show main menu on Server Core

### Milestone 2: Prerequisites Working
- [ ] All environment checks implemented
- [ ] Network validation working
- [ ] AD validation working
- [ ] gMSA creation automated

### Milestone 3: Certificates Working
- [ ] Self-signed certificate generation
- [ ] PFX import working
- [ ] Let's Encrypt integration (win-acme)

### Milestone 4: ADFS Installable
- [ ] Windows feature installation
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
| - | No known issues yet | - | - |

---

## Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-12-04 | Use Nginx reverse proxy instead of WAP | Lighter weight, easier Let's Encrypt, user preference |
| 2024-12-04 | Target Windows Server 2019 | User's environment, stable platform |
| 2024-12-04 | Use gMSA for service account | Security best practice, automatic password management |
| 2024-12-04 | Use WID not SQL | Single-server deployment, simpler backup/restore |
| 2024-12-04 | Skip signature validation for iex | User accepts risk, simplicity preferred |
| 2024-12-04 | MFA deferred to future version | Complexity, focus on core functionality first |

---

## Next Actions

1. **Implement TUI Menu System** - Core building block for wizard
2. **Implement State Management** - Enable resume capability
3. **Build Prerequisites Checks** - First functional wizard step

---

## Session Log

### 2024-12-04
- Initial planning session
- Defined architecture (ADFS Server + Nginx Proxy + DC)
- Clarified requirements with user
- Created documentation structure (README, GOALS, TASKS, STATUS, DIRECTIVES)
- Decided on gMSA, WID, Nginx approach
- Scoped MFA to future version
