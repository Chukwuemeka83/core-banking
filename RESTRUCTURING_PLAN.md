# GOLANG_MIGRATION_TASKS.md Restructuring Plan

**Date:** 2026-01-03
**Status:** APPROVED
**Priority:** CRITICAL

## Executive Summary

The GOLANG_MIGRATION_TASKS.md file contains critical structural issues that make it unreliable:
- **Only 166/238 tasks exist (70% complete)**
- **Phase 6 (Account Domain) completely missing** - blocks 8+ dependent tasks
- **P4 prefix conflict** between Event Horizon and Compliance domains
- **28 infrastructure tasks missing** (Phases 2, 3, 5)
- **13 incomplete tasks** (Phases 0, 1)
- **Inconsistent formatting** and duplicate headers

## Critical Issues Identified

### 1. Missing Phase 6: Account Domain (BLOCKER)
- **Impact:** 8+ tasks depend on non-existent P2-ACCOUNT-* tasks
- **Required:** 8 tasks, 96 hours
- **Dependencies:** P3-PAYMENT-002, P3-PAYMENT-004, P4-COMPLIANCE-003, P5-EXCHANGE-003, etc.

### 2. P4 Prefix Conflict
- P4-EVENTHORIZON-* (8 tasks) - Phase 4
- P4-COMPLIANCE-* (20 tasks) - Phase 8 content
- **Fix:** Rename P4-COMPLIANCE to P8-COMPLIANCE

### 3. Incomplete Infrastructure Phases
- Phase 0: 4/10 tasks (need 6 more)
- Phase 1: 1/8 tasks (need 7 more)
- Phase 2: 0/12 tasks (need all 12)
- Phase 3: 0/10 tasks (need all 10)
- Phase 5: 0/6 tasks (need all 6)
- **Total Missing:** 41 tasks

### 4. Phase Numbering Mismatch
- Domain phases use old numbering (before infrastructure phases added)
- "# Phase 3: Payment" should be "## Phase 7: Payment"
- Task prefixes don't match phase numbers

### 5. Header Format Inconsistency
- Infrastructure phases: `## Phase N` (H2)
- Domain phases: `# Phase N` (H1) - nested inside Phase 6
- Need consistent formatting

## Restructuring Strategy

### Phase 1: Create New Branch
```bash
git checkout -b claude/fintech-architecture-review-VdSJM
```

### Phase 2: Fix Critical Blockers (Priority 1)

#### 2.1 Create Phase 6: Account Domain
**Location:** After line 1759 (after Phase 5)

**Tasks to Create:**
1. P6-ACCOUNT-001: Account Value Objects (8h)
2. P6-ACCOUNT-002: Account Aggregate (12h)
3. P6-ACCOUNT-003: Account Repository (Ports) (10h)
4. P6-ACCOUNT-004: Account Service (12h)
5. P6-ACCOUNT-005: Account API Endpoints (14h)
6. P6-ACCOUNT-006: Account Workflows (16h)
7. P6-ACCOUNT-007: Account Testing (16h)
8. P6-ACCOUNT-008: Account Integration (8h)

**Total:** 96 hours

#### 2.2 Fix P4 Prefix Conflict
**Action:** Rename all P4-COMPLIANCE-* to P8-COMPLIANCE-*
**Affected Lines:** 3940-5611 (entire Compliance Domain section)
**Search/Replace:** `P4-COMPLIANCE-` → `P8-COMPLIANCE-`

### Phase 3: Complete Infrastructure Tasks (Priority 2)

#### 3.1 Complete Phase 0: Infrastructure Setup
Add tasks P0-INFRA-005 through P0-INFRA-010:
- P0-INFRA-005: Formance Docker Setup (8h)
- P0-INFRA-006: Temporal Docker Setup (10h)
- P0-INFRA-007: PostgreSQL 16 Setup (8h)
- P0-INFRA-008: Redis Setup for Event Bus (8h)
- P0-INFRA-009: Monitoring Stack (Prometheus/Grafana) (12h)
- P0-INFRA-010: CI/CD Pipeline Setup (18h)

#### 3.2 Complete Phase 1: Control Plane
Add tasks P1-CONTROL-002 through P1-CONTROL-008:
- P1-CONTROL-002: Tenant Registry Service (12h)
- P1-CONTROL-003: Tenant API Endpoints (10h)
- P1-CONTROL-004: Tenant Billing Integration (12h)
- P1-CONTROL-005: Tenant Metrics & Monitoring (10h)
- P1-CONTROL-006: Tenant Lifecycle Workflows (14h)
- P1-CONTROL-007: Tenant Migration Tools (16h)
- P1-CONTROL-008: Control Plane Testing (10h)

#### 3.3 Complete Phase 2: Ory Stack Integration
Create 12 new tasks (P2-ORY-001 through P2-ORY-012):
- Kratos adapter implementation
- Keto adapter implementation
- Oathkeeper configuration
- Identity schema design
- Permission model setup
- Realm management
- Testing & verification

**Estimated:** 120 hours

#### 3.4 Complete Phase 3: Formance Integration
Create 10 new tasks (P3-FORMANCE-001 through P3-FORMANCE-010):
- Ledger adapter implementation
- Wallet adapter implementation
- Transaction workflows
- Balance management
- Multi-asset support
- Testing & verification

**Note:** Must rename existing P3-PAYMENT to avoid conflict
**Estimated:** 100 hours

#### 3.5 Complete Phase 5: Schema-per-Tenant Middleware
Create 6 new tasks (P5-SCHEMA-001 through P5-SCHEMA-006):
- Middleware implementation
- Schema isolation
- Connection pooling
- Migration management
- Testing
- Performance optimization

**Estimated:** 48 hours

### Phase 4: Structural Cleanup (Priority 3)

#### 4.1 Standardize Header Levels
**Decision:** Use `## Phase N:` format for ALL phases

**Changes:**
- Line 1778: `# Phase 3:` → `## Phase 7:`
- Line 3940: `# Phase 4:` → `## Phase 8:`
- Line 5612: `# Phase 6:` → `## Phase 9:`
- Continue for all domain phases

#### 4.2 Remove Duplicate Headers
- Delete line 1760: `## Phase 6: Exchange Domain` (placeholder)
- Delete line 16219: `## Phase 10 Summary`
- Delete lines 19205-19250: Duplicate summary sections

#### 4.3 Fix Phase Numbering
Update all phase headers to match correct sequence:
- Current "# Phase 3: Payment" → "## Phase 7: Payment Domain"
- Current "# Phase 4: Compliance" → "## Phase 8: Compliance Domain"
- Current "# Phase 6: Exchange" → "## Phase 9: Exchange Domain"
- etc.

**Add prefix notes:**
```markdown
## Phase 7: Payment Domain

> **Note:** Tasks use P3-PAYMENT-* prefix (historical)

**Duration:** Weeks X-Y
...
```

#### 4.4 Update Task Prefix Documentation
Add note at top explaining prefix mismatch:
```markdown
## Task Prefix Convention

**Note:** Task prefixes were created before infrastructure phases (0-5) were added.
Therefore, domain phase numbers and task prefixes differ:

| Phase # | Domain | Task Prefix |
|---------|--------|-------------|
| 6 | Account | P6-ACCOUNT |
| 7 | Payment | P3-PAYMENT |
| 8 | Compliance | P8-COMPLIANCE (was P4) |
| 9 | Exchange | P5-EXCHANGE |
| 10 | Stablecoin | P6-STABLECOIN |
| 11 | Treasury | P7-TREASURY |
| 12 | Lending | P8-LENDING |
| 13 | Wallet/Blockchain | P9-WALLET |
| 14 | AI | P10-AI |
| 15 | CGO + Supporting | P11-P14-* |
```

### Phase 5: Update Statistics (Priority 4)

#### 5.1 Update Header Breakdown
Current:
```markdown
**Total Tasks:** 238 (updated with infrastructure phases)
**Total Estimated Hours:** 2,968 hours (~74 weeks)
```

After completion:
```markdown
**Total Tasks:** 238
**Total Estimated Hours:** 2,968 hours (~74 weeks)
**Completion Status:** 100% documented
```

#### 5.2 Verify Phase Breakdown Matches Content
Update line 13-30 phase breakdown to reflect actual content.

### Phase 6: Quality Assurance (Priority 5)

#### 6.1 Validate All Dependencies
Verify all `P2-ACCOUNT-*` references now point to real tasks:
- P3-PAYMENT-002 → P6-ACCOUNT-002 (update references)
- P3-PAYMENT-004 → P6-ACCOUNT-002
- P4-COMPLIANCE-003 → P6-ACCOUNT-002 (will be P8-COMPLIANCE-003)
- etc.

#### 6.2 Consistency Checks
- [ ] All phases have ## headers (H2 level)
- [ ] No duplicate phase numbers
- [ ] All task IDs follow pattern: `P{N}-{DOMAIN}-{###}`
- [ ] Total task count = 238
- [ ] Total hours = 2,968
- [ ] All dependencies exist

#### 6.3 Run Validation Script
```bash
./scripts/validate-migration-tasks.sh
```

## Implementation Order

### Week 1: Critical Fixes
1. ✅ Create branch
2. ✅ Fix P4 prefix conflict (P4-COMPLIANCE → P8-COMPLIANCE)
3. ✅ Create Phase 6: Account Domain (8 tasks)
4. ✅ Update all P2-ACCOUNT dependencies to P6-ACCOUNT

### Week 2: Infrastructure Completion
5. ✅ Complete Phase 0 (add 6 tasks)
6. ✅ Complete Phase 1 (add 7 tasks)
7. ✅ Complete Phase 2 (add 12 tasks)
8. ✅ Complete Phase 3 (add 10 tasks) - rename to P3-FORMANCE
9. ✅ Complete Phase 5 (add 6 tasks)

### Week 3: Structural Cleanup
10. ✅ Standardize all headers to ##
11. ✅ Remove duplicate headers
12. ✅ Fix phase numbering
13. ✅ Add prefix documentation
14. ✅ Update header statistics

### Week 4: Validation & Delivery
15. ✅ Validate all dependencies
16. ✅ Run consistency checks
17. ✅ Pre-commit quality checks
18. ✅ Commit and push
19. ✅ Create pull request

## Success Criteria

- [ ] All 238 tasks exist with proper Task IDs
- [ ] Phase 6 (Account Domain) fully implemented
- [ ] No prefix conflicts (P4 resolved)
- [ ] All infrastructure phases complete (0-5)
- [ ] Consistent ## header formatting
- [ ] No duplicate phase headers
- [ ] All dependencies exist and are correct
- [ ] Header statistics match content
- [ ] File passes all quality checks

## Risk Mitigation

### Risk 1: Breaking Dependencies
**Mitigation:** Create mapping document of all dependency changes
**Action:** Update all references when renaming prefixes

### Risk 2: Task Count Mismatch
**Mitigation:** Automated validation script
**Action:** Run count verification after each phase

### Risk 3: Merge Conflicts
**Mitigation:** Work in dedicated branch, small incremental commits
**Action:** Commit after each major section completed

## Validation Commands

```bash
# Count all task IDs
grep -c "^\*\*Task ID:\*\*" GOLANG_MIGRATION_TASKS.md

# Find all P2-ACCOUNT references
grep -n "P2-ACCOUNT" GOLANG_MIGRATION_TASKS.md

# Find duplicate phase headers
grep -n "^## Phase" GOLANG_MIGRATION_TASKS.md | sort

# Verify no P4-COMPLIANCE remains
grep -n "P4-COMPLIANCE" GOLANG_MIGRATION_TASKS.md
```

## Notes

- Preserve all existing task content - only fix structure
- Maintain code examples and implementation details
- Keep architectural sections intact
- Update only phase headers and task IDs where necessary
- Document all changes in commit messages
