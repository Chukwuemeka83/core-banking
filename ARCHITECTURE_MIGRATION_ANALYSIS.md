# Architectural Migration Analysis - Cell-Based Multi-Tenancy

> **Analysis of changes from Event Sourcing to Formance-based Cell Architecture**
>
> Date: 2026-01-01
> Impact: Major architectural pivot affecting ~70% of tasks

---

## Executive Summary

### Previous Architecture (Event Horizon + CQRS)
- **Event Sourcing**: Event Horizon framework for all aggregates
- **CQRS**: Custom command/query buses with separate read/write models
- **Multi-Tenancy**: Column-based (`tenant_id` in all tables)
- **Wallet Management**: Custom event-sourced wallet aggregates
- **Identity**: Custom JWT-based authentication
- **Authorization**: Custom RBAC implementation
- **Ledger**: Custom double-entry bookkeeping

### New Architecture (Formance + Ory Cell-Based)
- **Ledger**: Formance Ledger (immutable transaction log)
- **Wallets**: Formance Wallets (multi-asset balance management)
- **Multi-Tenancy**: Schema-per-tenant (strict isolation)
- **Identity**: Ory Kratos (tenant-scoped)
- **Authorization**: Ory Keto (ReBAC with relationship tuples)
- **Gateway**: Ory Oathkeeper (routing + authentication)
- **Architecture**: Control Plane + Tenant Plane separation

---

## Architectural Changes Breakdown

### 1. Multi-Tenancy Model

#### **BEFORE: Column-Based (Shared Database)**
```sql
-- All tenants share same tables
CREATE TABLE accounts (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,  -- Discriminator column
    user_id UUID NOT NULL,
    balance DECIMAL(20,8),
    currency VARCHAR(3)
);

CREATE INDEX idx_accounts_tenant ON accounts(tenant_id);
```

```go
// Middleware sets tenant context
func TenantMiddleware(c *gin.Context) {
    tenantID := ExtractTenantFromJWT(c)
    c.Set("tenant_id", tenantID)
}

// All queries filter by tenant_id
db.Where("tenant_id = ?", tenantID).Find(&accounts)
```

**Problems:**
- ❌ Risk of cross-tenant data leakage (logic bug = data breach)
- ❌ Difficult to provide true data isolation for compliance
- ❌ Cannot white-label (separate databases per client)
- ❌ No physical data separation for regulated industries

#### **AFTER: Schema-Per-Tenant (Strict Isolation)**
```sql
-- Control Plane Database
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    domain VARCHAR(255),  -- e.g., "bank-a.com"
    schema_name VARCHAR(63),  -- e.g., "tenant_abc123"
    formance_ledger_id VARCHAR(255),
    kratos_realm_id UUID,
    created_at TIMESTAMP
);

-- Tenant A's Schema (physically isolated)
CREATE SCHEMA tenant_abc123;

-- Tenant A's tables (NO tenant_id column needed!)
CREATE TABLE tenant_abc123.accounts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,  -- References Ory Kratos identity
    formance_wallet_id VARCHAR(255),  -- Maps to Formance Wallet
    account_type VARCHAR(50),
    status VARCHAR(20)
);

-- Tenant B's Schema (completely separate)
CREATE SCHEMA tenant_xyz789;
CREATE TABLE tenant_xyz789.accounts (...);  -- Same structure, different data
```

```go
// Middleware sets PostgreSQL search_path per tenant
func TenantMiddleware(c *gin.Context) {
    // Extract tenant from subdomain or X-Tenant-ID header
    tenantDomain := ExtractTenantDomain(c)

    // Lookup tenant in control plane
    tenant, err := controlPlaneDB.GetTenantByDomain(tenantDomain)
    if err != nil {
        c.AbortWithStatus(403)
        return
    }

    // Set PostgreSQL schema for this request
    db.Exec(fmt.Sprintf("SET search_path TO %s", tenant.SchemaName))

    c.Set("tenant_id", tenant.ID)
    c.Set("schema_name", tenant.SchemaName)
    c.Next()
}

// Queries automatically use correct schema (no tenant_id filter needed!)
db.Find(&accounts)  // Reads from current search_path (tenant_abc123.accounts)
```

**Benefits:**
- ✅ Physical data isolation (impossible to query another tenant's data)
- ✅ Compliance-friendly (GDPR, PCI-DSS, SOC 2)
- ✅ Per-tenant backups and restores
- ✅ White-label capable (each tenant feels like dedicated deployment)

---

### 2. Identity & Authentication

#### **BEFORE: Custom JWT**
```go
// Custom user table with passwords
type User struct {
    ID           UUID
    TenantID     UUID
    Email        string
    PasswordHash string  // bcrypt hash
    CreatedAt    time.Time
}

// Custom authentication
func Login(email, password string) (string, error) {
    user, err := db.FindUserByEmail(email)
    if err != nil {
        return "", ErrInvalidCredentials
    }

    if !bcrypt.CompareHashAndPassword(user.PasswordHash, []byte(password)) {
        return "", ErrInvalidCredentials
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id":   user.ID,
        "tenant_id": user.TenantID,
        "exp":       time.Now().Add(24 * time.Hour).Unix(),
    })

    return token.SignedString(jwtSecret)
}
```

**Problems:**
- ❌ Security burden (password storage, hashing, rotation)
- ❌ No MFA out of the box
- ❌ No social login (Google, Apple, etc.)
- ❌ No passwordless flows (magic links, WebAuthn)
- ❌ Maintenance overhead (password reset, email verification, etc.)

#### **AFTER: Ory Kratos (Tenant-Scoped)**
```go
// User profile table (NO passwords!)
type UserProfile struct {
    ID            UUID  // Same as Ory Kratos identity ID
    KratosID      UUID  // FK to Kratos (for cross-reference)
    FirstName     string
    LastName      string
    PhoneNumber   string
    KYCStatus     string
    CreatedAt     time.Time
}

// Ory Kratos handles all authentication
// Each tenant gets dedicated Kratos instance/realm

// Login flow (delegated to Kratos)
func InitiateLogin(c *gin.Context) {
    tenantDomain := ExtractTenantDomain(c)
    tenant := GetTenantByDomain(tenantDomain)

    // Redirect to tenant's Kratos login UI
    kratosURL := fmt.Sprintf("https://kratos-%s.finaegis.com/self-service/login/browser", tenant.ID)
    c.Redirect(302, kratosURL)
}

// After Kratos authentication, receive session
func HandleKratosCallback(c *gin.Context) {
    sessionToken := c.Request.Header.Get("X-Session-Token")

    // Validate session with Kratos
    session, err := kratosClient.ToSession(sessionToken)
    if err != nil {
        c.AbortWithStatus(401)
        return
    }

    // Session contains Kratos identity UUID
    kratosID := session.Identity.ID

    // Lookup/create user profile
    user, _ := db.FindOrCreateUserProfile(kratosID)

    c.Set("user_id", user.ID)
    c.Set("kratos_id", kratosID)
}
```

**Benefits:**
- ✅ Battle-tested authentication (no password management)
- ✅ MFA built-in (TOTP, WebAuthn)
- ✅ Social login (Google, GitHub, Apple)
- ✅ Passwordless (magic links, WebAuthn)
- ✅ Account recovery flows
- ✅ Email/phone verification
- ✅ Tenant-scoped (different user bases per tenant)

---

### 3. Authorization Model

#### **BEFORE: Custom RBAC**
```go
// Custom permissions table
type Permission struct {
    ID       UUID
    TenantID UUID
    UserID   UUID
    Resource string  // "wallet", "account", "transaction"
    Action   string  // "read", "write", "approve"
}

// Check permission
func CanUserDebitWallet(userID, walletID UUID) bool {
    var perm Permission
    db.Where("user_id = ? AND resource = ? AND action = ?",
        userID, "wallet:"+walletID, "debit").First(&perm)
    return perm.ID != uuid.Nil
}
```

**Problems:**
- ❌ Limited to simple RBAC (hard to express complex relationships)
- ❌ No hierarchical permissions (account → wallet inheritance)
- ❌ No group permissions
- ❌ Performance issues with many permission checks

#### **AFTER: Ory Keto (ReBAC with Relationship Tuples)**
```go
// Ory Keto relationship tuples (stored in Keto, not our DB)
// Format: (namespace, object, relation, subject)

// Example tuples:
// - (accounts, account-123, owner, user-alice)
// - (accounts, account-123, admin, user-bob)
// - (wallets, wallet-456, parent, account-123)
// - (wallets, wallet-789, can_debit, user-charlie)

// Two-layer permission check
func CanUserDebitWallet(userID, walletID string) (bool, error) {
    // Layer 1: Direct wallet permission (granular override)
    allowed, err := ketoClient.Check(ctx, &keto.CheckRequest{
        Namespace: "wallets",
        Object:    walletID,
        Relation:  "can_debit",
        Subject:   fmt.Sprintf("user:%s", userID),
    })
    if err != nil {
        return false, err
    }
    if allowed {
        return true, nil  // Explicit wallet permission
    }

    // Layer 2: Account membership (inheritance)
    // Find parent account
    walletParent, err := ketoClient.ListRelations(ctx, &keto.ListRequest{
        Namespace: "wallets",
        Object:    walletID,
        Relation:  "parent",
    })
    if err != nil {
        return false, err
    }

    accountID := walletParent[0].Subject  // e.g., "account-123"

    // Check if user is admin of parent account
    allowed, err = ketoClient.Check(ctx, &keto.CheckRequest{
        Namespace: "accounts",
        Object:    accountID,
        Relation:  "admin",
        Subject:   fmt.Sprintf("user:%s", userID),
    })
    return allowed, err
}
```

**Benefits:**
- ✅ Relationship-based (ReBAC) - express complex hierarchies
- ✅ Two-layer fallback (wallet-specific + account membership)
- ✅ Google Zanzibar model (proven at scale)
- ✅ Powerful query capabilities ("list all wallets user can debit")

---

### 4. Wallet & Ledger Management

#### **BEFORE: Custom Event-Sourced Wallets**
```go
// Custom wallet aggregate with event sourcing
type WalletAggregate struct {
    *eventhorizon.AggregateBase
    balances map[string]decimal.Decimal  // currency -> balance
    holds    map[string]decimal.Decimal  // currency -> held amount
}

func (w *WalletAggregate) Deposit(currency string, amount decimal.Decimal) error {
    if amount.LessThanOrEqual(decimal.Zero) {
        return ErrInvalidAmount
    }

    w.AppendEvent(WalletDepositedEvent{
        Currency: currency,
        Amount:   amount,
    }, time.Now())
    return nil
}

func (w *WalletAggregate) ApplyWalletDeposited(evt WalletDepositedEvent) {
    current := w.balances[evt.Currency]
    w.balances[evt.Currency] = current.Add(evt.Amount)
}

// Custom ledger projection
type LedgerEntry struct {
    ID        UUID
    TenantID  UUID
    WalletID  UUID
    Type      string  // "debit" or "credit"
    Amount    decimal.Decimal
    Currency  string
    Balance   decimal.Decimal  // Running balance
}
```

**Problems:**
- ❌ Complex to maintain (event sourcing overhead)
- ❌ Balance calculation from events (slow for large histories)
- ❌ No built-in double-entry guarantees
- ❌ Custom ledger logic (prone to bugs)
- ❌ Hard to audit (need custom reporting)

#### **AFTER: Formance Wallets + Ledger**
```go
// Wallet mapping table (minimal)
type Wallet struct {
    ID                 UUID
    AccountID          UUID
    FormanceWalletID   string  // e.g., "wallet-abc123" (in Formance)
    Name               string
    Purpose            string  // "operating", "treasury", etc.
    CreatedAt          time.Time
}

// Deposit via Formance
func DepositToWallet(walletID UUID, amount decimal.Decimal, currency string) error {
    // Lookup Formance wallet ID
    wallet, err := db.GetWallet(walletID)
    if err != nil {
        return err
    }

    // Call Formance Wallets API
    resp, err := formanceClient.Wallets.Credit(ctx, &formance.CreditRequest{
        WalletID: wallet.FormanceWalletID,
        Amount: &formance.Monetary{
            Amount:   amount.IntPart(),  // Amount in smallest unit (cents)
            Currency: currency,
        },
        Reference: fmt.Sprintf("deposit-%s", uuid.New()),
        Metadata: map[string]string{
            "tenant_id":  tenant.ID,
            "wallet_id":  wallet.ID.String(),
            "source":     "bank_transfer",
        },
    })
    if err != nil {
        return err
    }

    // Formance automatically:
    // 1. Updates wallet balance
    // 2. Creates ledger entry (double-entry)
    // 3. Ensures atomicity

    return nil
}

// Get balance (from Formance)
func GetWalletBalance(walletID UUID) (map[string]decimal.Decimal, error) {
    wallet, err := db.GetWallet(walletID)
    if err != nil {
        return nil, err
    }

    // Query Formance for current balances
    resp, err := formanceClient.Wallets.GetBalance(ctx, wallet.FormanceWalletID)
    if err != nil {
        return nil, err
    }

    balances := make(map[string]decimal.Decimal)
    for currency, amount := range resp.Balances {
        balances[currency] = decimal.NewFromInt(amount)
    }
    return balances, nil
}

// Query ledger history (from Formance)
func GetLedgerHistory(walletID UUID, limit int) ([]formance.Transaction, error) {
    wallet, err := db.GetWallet(walletID)
    if err != nil {
        return nil, err
    }

    // Query Formance Ledger
    txs, err := formanceClient.Ledger.ListTransactions(ctx, &formance.ListTxRequest{
        Account: wallet.FormanceWalletID,
        Limit:   limit,
    })
    return txs, err
}
```

**Benefits:**
- ✅ Battle-tested ledger (immutable, auditable)
- ✅ Guaranteed double-entry bookkeeping
- ✅ Multi-asset support out of the box
- ✅ Built-in holds/reserves
- ✅ Real-time balance queries (no event replay)
- ✅ Compliance-ready audit trails
- ✅ No custom event sourcing complexity

---

### 5. Control Plane vs. Tenant Plane

#### **BEFORE: Monolithic Application**
```
Single API Server
├── Domain Logic
├── Event Store
├── Read Models
└── Admin Functions (all mixed together)
```

#### **AFTER: Separated Planes**
```
Control Plane (Global)
├── Tenant Provisioning (Temporal Workflow)
├── Tenant Registry (domains, schemas, Formance IDs)
├── Global Router (Ory Oathkeeper)
├── Billing & Metering
└── Admin API (manage tenants)

Tenant Plane (Per-Tenant)
├── Business Logic (accounts, payments, etc.)
├── PostgreSQL Schema (tenant_abc123)
├── Formance Ledger Instance (ledger-abc123)
├── Formance Wallets Instance
└── Ory Kratos Realm (kratos-abc123)
```

**Control Plane Database:**
```sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    domain VARCHAR(255) UNIQUE,
    schema_name VARCHAR(63) UNIQUE,
    formance_ledger_id VARCHAR(255),
    formance_org_id VARCHAR(255),
    kratos_realm_id VARCHAR(255),
    keto_namespace_prefix VARCHAR(63),
    status VARCHAR(20),  -- 'provisioning', 'active', 'suspended'
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE tenant_routing (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    domain VARCHAR(255),  -- e.g., "acme-bank.finaegis.com"
    is_primary BOOLEAN
);
```

**Tenant Provisioning Workflow (Temporal):**
```go
func TenantProvisioningWorkflow(ctx workflow.Context, input TenantProvisioningInput) error {
    ao := workflow.ActivityOptions{
        StartToCloseTimeout: 10 * time.Minute,
    }
    ctx = workflow.WithActivityOptions(ctx, ao)

    tenantID := uuid.New()

    // Step 1: Create PostgreSQL schema
    var schemaResult SchemaProvisioningResult
    err := workflow.ExecuteActivity(ctx, CreateTenantSchemaActivity, CreateSchemaInput{
        TenantID:   tenantID,
        SchemaName: fmt.Sprintf("tenant_%s", strings.Replace(tenantID.String(), "-", "", -1)[:12]),
    }).Get(ctx, &schemaResult)
    if err != nil {
        return err
    }

    // Step 2: Provision Formance Ledger
    var ledgerResult LedgerProvisioningResult
    err = workflow.ExecuteActivity(ctx, ProvisionFormanceLedgerActivity, ProvisionLedgerInput{
        TenantID: tenantID,
        OrgName:  input.TenantName,
    }).Get(ctx, &ledgerResult)
    if err != nil {
        // Compensate: Drop schema
        workflow.ExecuteActivity(ctx, DropTenantSchemaActivity, schemaResult.SchemaName)
        return err
    }

    // Step 3: Provision Ory Kratos realm
    var kratosResult KratosProvisioningResult
    err = workflow.ExecuteActivity(ctx, ProvisionKratosRealmActivity, ProvisionKratosInput{
        TenantID:   tenantID,
        TenantName: input.TenantName,
    }).Get(ctx, &kratosResult)
    if err != nil {
        // Compensate: Delete Formance resources, drop schema
        workflow.ExecuteActivity(ctx, DeleteFormanceLedgerActivity, ledgerResult.LedgerID)
        workflow.ExecuteActivity(ctx, DropTenantSchemaActivity, schemaResult.SchemaName)
        return err
    }

    // Step 4: Register routing in Ory Oathkeeper
    err = workflow.ExecuteActivity(ctx, RegisterTenantRoutingActivity, RegisterRoutingInput{
        TenantID: tenantID,
        Domain:   input.Domain,
    }).Get(ctx, nil)
    if err != nil {
        // Compensate all previous steps
        workflow.ExecuteActivity(ctx, DeregisterKratosRealmActivity, kratosResult.RealmID)
        workflow.ExecuteActivity(ctx, DeleteFormanceLedgerActivity, ledgerResult.LedgerID)
        workflow.ExecuteActivity(ctx, DropTenantSchemaActivity, schemaResult.SchemaName)
        return err
    }

    // Step 5: Create tenant record in control plane
    err = workflow.ExecuteActivity(ctx, CreateTenantRecordActivity, CreateTenantInput{
        TenantID:         tenantID,
        Name:             input.TenantName,
        Domain:           input.Domain,
        SchemaName:       schemaResult.SchemaName,
        FormanceLedgerID: ledgerResult.LedgerID,
        KratosRealmID:    kratosResult.RealmID,
    }).Get(ctx, nil)

    return err
}
```

---

## Impact Analysis by Phase

### Phase 0: Infrastructure (7 tasks)
**Impact:** MEDIUM
- ✅ Keep: Docker Compose, CI/CD, K8s, Logging, Observability
- ➕ Add: Ory stack containers, Formance services
- ➖ Remove: Event store migration

### Phase 1: Foundation (12 tasks)
**Impact:** HIGH
- ✅ Keep: Money, Currency value objects
- ➖ Remove: Event Sourcing tasks (1.9, 1.10, 1.11)
- ➖ Remove: CQRS buses (1.6, 1.7) - simplified with Formance
- ➕ Add: Ory Kratos integration (3 tasks)
- ➕ Add: Ory Keto integration (2 tasks)
- ➕ Add: Ory Oathkeeper integration (2 tasks)
- ➕ Add: Formance SDK setup (1 task)

### Phase 2: Account (8 tasks)
**Impact:** CRITICAL
- ➖ Remove: Account aggregate with event sourcing
- ➕ Replace: Account as logical container (not wallet)
- ✅ Modify: Account commands/queries (simplified)
- ✅ Keep: Account REST API (different implementation)

### Phase 3: Payment (13 tasks)
**Impact:** HIGH
- ✅ Keep: Payment value objects
- ➖ Remove: Custom deposit/withdrawal aggregates
- ➕ Replace: Formance Wallets integration for movements
- ✅ Keep: Stripe, Open Banking integrations
- ✅ Modify: Payment workflows use Formance

### Phase 4: Compliance (20 tasks)
**Impact:** LOW
- ✅ Keep: Most compliance tasks (KYC, AML independent of wallet)
- ✅ Modify: Transaction monitoring queries Formance Ledger

### Phase 5-14: Other Domains
**Impact:** VARIES
- Exchange, Stablecoin, Treasury, Lending: HIGH (wallet dependencies)
- AI, CGO, Governance: LOW (minimal wallet interaction)
- Monitoring, Supporting: LOW (infrastructure concerns)

---

## New Task Structure

### Revised Phase Breakdown (Estimated)

| Phase | Domain | Old Tasks | New Tasks | Change |
|-------|--------|-----------|-----------|--------|
| 0 | Infrastructure | 7 | 10 | +3 (Ory stack) |
| 1 | Ory + Formance Setup | 12 | 15 | +3 (Ory tasks) |
| 2 | Control Plane | 0 | 8 | +8 (NEW) |
| 3 | Tenant Plane & Schema Isolation | 8 | 10 | +2 |
| 4 | Account Domain (Revised) | 8 | 6 | -2 (simplified) |
| 5 | Formance Wallets Integration | 0 | 12 | +12 (NEW) |
| 6 | Payment (Formance-based) | 13 | 10 | -3 (simplified) |
| 7 | Compliance | 20 | 18 | -2 (slight simplification) |
| 8 | Exchange (Formance-based) | 14 | 12 | -2 |
| 9 | Treasury (Formance-based) | 18 | 14 | -4 |
| 10 | Lending (Formance-based) | 11 | 10 | -1 |
| 11 | Stablecoin (Formance-based) | 11 | 9 | -2 |
| 12 | Wallet/Blockchain | 15 | 12 | -3 |
| 13 | AI | 9 | 9 | 0 |
| 14 | CGO & Governance | 15 | 13 | -2 |
| 15 | Monitoring & Supporting | 18 | 16 | -2 |
| **TOTAL** | **All** | **180** | **174** | **-6** |

**Key Changes:**
- New Control Plane phase (tenant provisioning, routing)
- New Formance Wallets integration phase
- Removed event sourcing complexity (-~30 tasks worth of work)
- Added Ory stack integration (+~15 tasks worth of work)
- Net reduction: 6 tasks, but complexity significantly lower

---

## Technology Stack Changes

| Component | Old | New | Reason |
|-----------|-----|-----|--------|
| Event Sourcing | Event Horizon | Formance Ledger | Purpose-built financial ledger |
| CQRS | Custom buses | Simplified (Formance handles) | Reduce complexity |
| Wallet Management | Custom aggregates | Formance Wallets | Battle-tested, multi-asset |
| Balance Storage | PostgreSQL projections | Formance (real-time) | No event replay needed |
| Identity | Custom JWT | Ory Kratos | MFA, social login, passwordless |
| Authorization | Custom RBAC | Ory Keto (ReBAC) | Relationship-based, scalable |
| Gateway | Gin middleware | Ory Oathkeeper | Tenant routing, zero-trust |
| Multi-Tenancy | tenant_id column | Schema-per-tenant | Physical isolation |
| Double-Entry | Custom logic | Formance Ledger | Guaranteed correctness |

---

## Migration Strategy

### Step 1: Infrastructure (Week 1-2)
- Set up Ory stack (Kratos, Keto, Oathkeeper)
- Set up Formance (Ledger, Wallets)
- Configure schema-per-tenant PostgreSQL

### Step 2: Control Plane (Week 3-4)
- Build tenant provisioning workflow
- Implement tenant registry
- Configure Ory Oathkeeper routing

### Step 3: Core Integration (Week 5-8)
- Integrate Ory Kratos authentication
- Integrate Ory Keto authorization
- Integrate Formance Wallets
- Implement schema isolation middleware

### Step 4: Domain Migration (Week 9-50)
- Migrate Account domain (Formance-based)
- Migrate Payment domain (Formance-based)
- Migrate remaining domains

### Step 5: Testing & Deployment (Week 51-58)
- Integration testing
- Load testing
- Security audits
- Production deployment

---

## Next Steps

1. ✅ Review and approve architectural changes
2. ⏳ Update GOLANG_MIGRATION_TASKS.md with new task structure
3. ⏳ Update .cursorrules with Ory + Formance patterns
4. ⏳ Update .ai-context.md with new architecture
5. ⏳ Create new bootstrap script for Ory + Formance setup

**Status:** Ready for task update phase
**Estimated Effort:** ~40 hours to update all documentation
