# FinAegis Golang Migration - Cell-Based Multi-Tenant Architecture

> **Complete architectural specification for PHP/Laravel to Golang migration**
>
> **Architecture:** Cell-Based (Shared-Nothing) + Hexagonal Architecture + Ory Stack + Formance Stack
>
> **Pattern:** Ports & Adapters with vendor-agnostic design

---

## 🏗️ Architectural Overview

### **1. Architectural Strategy: The "Cell-Based" Model**

We are building a **Strict Multi-Tenant (Shared-Nothing)** fintech platform. The system is divided into two distinct planes to ensure data isolation, compliance, and white-labeling capabilities.

#### **The Two Planes**

**Control Plane (Infrastructure Layer):**
- **Role:** Manages the "Cells" (Tenants), billing, and routing. It has NO access to customer financial data.
- **Components:**
  - Global Admin API
  - Global Router (Ory Oathkeeper)
  - Tenant Provisioning Workflows (Temporal)
- **Technology:** Pure infrastructure management, no business logic

**Tenant Plane (The Data Silos):**
- **Role:** The isolated environment where a specific B2B Customer (Tenant) and their End-Users live.
- **Components:**
  - Every Tenant gets a dedicated PostgreSQL Schema
  - Every Tenant gets a dedicated Ory Kratos Identity Realm
  - Every Tenant gets a dedicated Formance Ledger Instance
  - Every Tenant gets a dedicated Formance Wallets Instance
- **Technology:** All business logic, financial operations, and workflows

---

### **2. Hexagonal Architecture (Ports & Adapters)**

**CRITICAL DESIGN PRINCIPLE:** Decouple business logic from infrastructure vendors.

```
┌──────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                          │
│  ┌────────────────────────────────────────────────┐      │
│  │  Business Logic (Pure Go, No Vendor Imports)   │      │
│  │  • Aggregates, Entities, Value Objects         │      │
│  │  • Domain Services, Commands, Queries          │      │
│  │  • Sagas, Workflows, Business Rules            │      │
│  └────────────────┬───────────────────────────────┘      │
│                   │ Depends on ▼                          │
│  ┌────────────────▼───────────────────────────────┐      │
│  │  PORTS (Interfaces - Defined BY Domain)        │      │
│  │  • IdentityProvider interface                  │      │
│  │  • AuthorizationProvider interface             │      │
│  │  • LedgerService interface                     │      │
│  │  • WalletService interface                     │      │
│  │  • WorkflowOrchestrator interface              │      │
│  │  • APIGateway interface                        │      │
│  └────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────┘
                          │ Implemented by ▼
┌──────────────────────────────────────────────────────────┐
│               INFRASTRUCTURE LAYER                        │
│  ┌──────────────────────────────────────────────────┐    │
│  │  ADAPTERS (Implementations - Pluggable)          │    │
│  │  DEFAULT PRODUCTION ADAPTERS:                    │    │
│  │  • OryKratosAdapter (implements IdentityProv)    │    │
│  │  • OryKetoAdapter (implements AuthzProvider)     │    │
│  │  • FormanceLedgerAdapter (implements LedgerSvc)  │    │
│  │  • FormanceWalletAdapter (implements WalletSvc)  │    │
│  │  • TemporalAdapter (implements WorkflowOrch)     │    │
│  │  • OryOathkeeperAdapter (implements APIGateway)  │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  ALTERNATIVE ADAPTERS (Can be swapped):                   │
│  • Auth0Adapter, KeycloakAdapter (Identity)               │
│  • CasbinAdapter, OPAAdapter (Authorization)              │
│  • TigerBeetleAdapter, CustomLedgerAdapter (Ledger)       │
│  • InMemoryAdapter (Testing)                              │
└──────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ **Vendor Independence**: Domain logic doesn't change when switching vendors
- ✅ **Testability**: Unit tests use in-memory adapters (no external dependencies)
- ✅ **Flexibility**: Development uses mocks, staging uses real vendors, production optimized
- ✅ **Migration**: Can gradually migrate from one vendor to another
- ✅ **Cost Control**: Switch to cost-effective alternatives without code rewrites

**Example:**
```go
// ❌ BAD: Domain imports vendor directly
import "github.com/formancehq/formance-sdk-go"  // NEVER in domain layer!

// ✅ GOOD: Domain depends on interface
type WalletService interface {
    Credit(ctx context.Context, req CreditRequest) (*Transaction, error)
    Debit(ctx context.Context, req DebitRequest) (*Transaction, error)
    GetBalance(ctx context.Context, walletID string) (*Balance, error)
}

// Adapter implements interface (in infrastructure layer)
type FormanceWalletAdapter struct {
    client *formance.Client  // Vendor import OK in adapter layer!
}
```

---

### **3. Technology Stack & Component Selection**

**CRITICAL:** We use **Hexagonal Architecture (Ports & Adapters)** to decouple from vendors.

| Component | Port (Interface) | Selected Default | Scope | Alternative Options |
|-----------|------------------|------------------|-------|---------------------|
| **Identity** | `IdentityProvider` | **Ory Kratos** | Tenant-scoped (per-realm authentication) | Auth0, Keycloak, AWS Cognito, Custom |
| **Permissions** | `AuthorizationProvider` | **Ory Keto** | Global service with namespaces (ReBAC) | Casbin, OpenPolicyAgent, Custom RBAC |
| **Gateway/Router** | `APIGateway` | **Ory Oathkeeper** | Global (routes by domain to tenant silos) | Kong, Traefik, Envoy, Custom |
| **Financial Ledger** | `LedgerService` | **Formance Ledger** | Tenant-scoped (double-entry transaction log) | TigerBeetle, Custom PostgreSQL, EventStore |
| **Asset Engine** | `WalletService` | **Formance Wallets** | Tenant-scoped (multi-asset balance management) | Custom, Blockchain Nodes, In-Memory |
| **Workflows** | `WorkflowOrchestrator` | **Temporal** | Global + Per-Tenant queues (sagas, provisioning) | Cadence, Custom State Machine, Conductor |
| **Database** | Standard SQL | **PostgreSQL 16** | Schema-per-tenant (physical isolation) | CockroachDB, MySQL, YugabyteDB |
| **Cache** | Standard Cache | **Redis 7** | Tenant-scoped (namespace per tenant) | Valkey, Memcached, Dragonfly |
| **Observability** | Standard Telemetry | **OpenTelemetry** | Global with tenant context | Datadog, New Relic, Jaeger |

**Key Principle:** Business logic NEVER imports vendor packages directly. Only adapters do.

**Rationale for Selected Defaults:**
- **Ory Stack**: Battle-tested identity/authz/gateway with tenant isolation
- **Formance**: Purpose-built for financial ledgers with immutability guarantees
- **Temporal**: Reliable workflow orchestration with saga pattern support
- **PostgreSQL**: Schema-per-tenant provides true data isolation

---

### **4. Data Hierarchy & Relationships**

```
Level 1: Tenant (B2B Customer - The Cell)
  └─ Level 2: Account (Logical Container - Polymorphic)
      ├─ B2C Account (Personal): Owned by single User
      │   ├─ Wallet 1 (Multi-Asset: USD, EUR, BTC, etc.)
      │   ├─ Wallet 2 (Multi-Asset: Savings, Trading, etc.)
      │   └─ User (OWNER - sole owner)
      │
      └─ B2B Account (Corporate): Owned by Tenant Entity
          ├─ Wallet 1 (Operational Wallet)
          ├─ Wallet 2 (Treasury Wallet)
          ├─ Wallet 3 (Petty Cash Wallet)
          └─ Users (Operators with varying roles)
              ├─ User A (ADMIN - full access)
              ├─ User B (MEMBER - limited access)
              └─ User C (VIEWER - read-only)
```

**Level 1: The Tenant (The Silo)**
- Definition: The B2B Customer (Bank/Fintech) using the platform
- Implementation: Identified by `X-Tenant-ID` header
- All data downstream is isolated within this Tenant's:
  - Specific PostgreSQL Schema (`schema_tenant_{id}`)
  - Specific Ory Kratos Realm
  - Specific Formance Ledger instance

**Level 2: The Account (The Logical Container)**
- Definition: The primary "Portfolio" or "Relationship" container
- Polymorphism:
  - **B2C Account (Personal):** Owned by a single User
  - **B2B Account (Corporate):** Owned by the Tenant Entity, managed by multiple Users with varying roles
- **Key Requirement:** Users and Wallets are NEVER directly linked. They are linked through the Account.

**Level 3: The Wallet (The Asset Holder)**
- Solution: Formance Wallets Service (via `WalletService` interface)
- Capabilities:
  - **Multi-Asset:** A single Wallet holds multiple currencies (e.g., `{ USD: 100, EUR: 50, BTC: 0.5 }`)
  - **Multi-Wallet Accounts:** An Account can hold multiple Wallets for functional separation (e.g., "Operational Wallet," "Treasury Wallet," "Savings Wallet")
- **NO Balance in PostgreSQL:** All balance state lives in Formance Ledger

**Level 4: The User (The Member)**
- Solution: Ory Kratos Identity (via `IdentityProvider` interface)
- Relationship: Users are **Members** of an Account
  - **B2C:** User is the sole OWNER member
  - **B2B:** Users can be ADMIN, MEMBER, or VIEWER members
- **NO Password Storage:** Ory Kratos handles all authentication

---

### **5. Authorization & Permissions Model**

#### **The "Fallback" Strategy (Ory Keto Implementation)**

To support complex B2B use cases, we implement a **two-layer permission check** using `AuthorizationProvider` interface:

**Layer 1: Specific Wallet Permissions (Granular Override)**
- Check: "Does User Bob have explicit `can_debit` permission on `Wallet_ID_123`?"
- Use Case: Allowing a junior employee to spend only from the "Petty Cash Wallet"
- Implementation: Direct relation tuple in Ory Keto

```go
// Check via interface (vendor-agnostic)
allowed, err := authzProvider.CheckPermission(ctx, PermissionCheckRequest{
    Subject:  "user:bob",
    Resource: "wallet:123",
    Action:   "debit",
})
```

**Layer 2: Account Membership Roles (Inheritance)**
- Check: "Is User Bob an `ADMIN` of the parent Account?"
- Logic: If yes, they inherit full access to all Wallets within that Account
- Implementation: Indirect relation tuple via parent Account

```go
// Fallback to account-level check
allowed, err := authzProvider.CheckPermission(ctx, PermissionCheckRequest{
    Subject:  "user:bob",
    Resource: "account:456",
    Action:   "admin",
})
// If true, user has full access to all wallets in Account 456
```

#### **Permission Hierarchy**

```
Tenant (Cell)
  └─ Account
      ├─ Account Roles (ADMIN, MEMBER, VIEWER)
      │   └─ Inherited wallet access
      └─ Wallets
          └─ Explicit wallet permissions (override)
              ├─ can_view
              ├─ can_credit
              └─ can_debit
```

---

### **6. Critical Workflows (The "Sagas")**

#### **Workflow A: The "Tenant Factory" (Onboarding)**

**Tool:** Temporal Workflow (via `WorkflowOrchestrator` interface)

**Steps:**
1. **DB Provisioning:** Create a new PostgreSQL Schema and Role restricted to that schema
2. **Ledger Provisioning:** Call Formance API to initialize a new Ledger instance (`ledger-tenant-{id}`)
3. **Wallet Provisioning:** Initialize Formance Wallets service for the tenant
4. **Identity Provisioning:** Spin up/configure the Ory Kratos Realm for the new tenant
5. **Authorization Setup:** Create tenant namespace in Ory Keto
6. **Routing Registration:** Register the tenant's domain in Ory Oathkeeper routing config

**Saga Pattern:** Full compensation on failure (rollback all provisioned resources)

```go
// Via interface (vendor-agnostic)
err := workflowOrchestrator.ExecuteWorkflow(ctx, TenantProvisioningWorkflow{
    TenantID: newTenantID,
    Domain:   "bank-a.com",
    Compensation: true, // Enable saga compensation
})
```

#### **Workflow B: Money Movement (Transfer)**

**Tool:** Temporal Workflow + Formance Wallets

**Logic:**
1. **Authenticate:** Validate `X-Tenant-ID` and User Session via Ory Oathkeeper
2. **Authorize:** Check Permissions via Ory Keto (Wallet-level or Account-level)
3. **Execute:** Call Formance Wallets API to perform the transfer (atomic multi-asset)
4. **Record:** Formance automatically writes to the underlying Ledger (immutable)
5. **Notify:** Emit domain events for downstream systems

```go
// Via interfaces (vendor-agnostic)
func (s *TransferService) ExecuteTransfer(ctx context.Context, cmd TransferCommand) error {
    // 1. Authorization check (via interface)
    allowed, _ := s.authzProvider.CheckPermission(ctx, PermissionCheckRequest{
        Subject:  fmt.Sprintf("user:%s", cmd.UserID),
        Resource: fmt.Sprintf("wallet:%s", cmd.SourceWalletID),
        Action:   "debit",
    })
    if !allowed {
        return ErrUnauthorized
    }

    // 2. Execute transfer (via interface)
    _, err := s.walletService.Transfer(ctx, TransferRequest{
        SourceWalletID: cmd.SourceWalletID,
        DestWalletID:   cmd.DestWalletID,
        Amount:         cmd.Amount,
        Metadata:       cmd.Metadata,
    })

    return err
}
```

---

## 🚨 Critical Directives

> **Implementation Instructions:**
>
> **Hexagonal Architecture Principles:**
> 1. ✅ **Domain depends on INTERFACES**, not vendor SDKs
> 2. ✅ **Ports (interfaces) defined BY domain** in `domain/**/ports/`
> 3. ✅ **Adapters implement interfaces** in `infrastructure/adapters/`
> 4. ❌ **Domain NEVER imports vendor packages** (`github.com/formancehq/*`, `github.com/ory/*`)
> 5. ❌ **Domain NEVER imports infrastructure** (`internal/infrastructure/*`)
> 6. ✅ **Adapters are pluggable** - switch vendors via configuration
>
> **Multi-Tenancy (Cell-Based):**
> 7. ✅ **Structure:** Separate `control_plane` (Admin/Provisioning) and `tenant_plane` (Business Logic)
> 8. ✅ **Isolation:** Middleware extracts `X-Tenant-ID` and sets PostgreSQL `SEARCH_PATH` to correct schema
> 9. ✅ **Control Plane Restriction:** Control Plane NEVER accesses Tenant Plane data
> 10. ✅ **All Entities Tenant-Scoped:** No global user/wallet/event tables
>
> **Identity & Security (Abstracted):**
> 11. ✅ **Identity:** Use `IdentityProvider` interface (default: Ory Kratos adapter)
> 12. ✅ **Authorization:** Use `AuthorizationProvider` interface (default: Ory Keto adapter)
> 13. ✅ **Gateway:** Use `APIGateway` interface (default: Ory Oathkeeper adapter)
> 14. ❌ **NO Custom User Table with Passwords:** Use Ory Kratos UUIDs as FK (profiles only)
>
> **Financial Operations (Abstracted):**
> 15. ✅ **Wallets:** Use `WalletService` interface (default: Formance adapter)
> 16. ✅ **Ledger:** Use `LedgerService` interface (default: Formance adapter)
> 17. ❌ **NO Balances in PostgreSQL:** PostgreSQL stores mappings ONLY (Local_Wallet_ID <-> Formance_Wallet_ID)
> 18. ✅ **Formance as Source of Truth:** All financial state lives in Formance Ledger
>
> **Workflows & Orchestration:**
> 19. ✅ **Workflows:** Use `WorkflowOrchestrator` interface (default: Temporal adapter)
> 20. ✅ **Sagas:** Implement compensation for distributed transactions
> 21. ✅ **Tenant Provisioning:** Atomic workflow with full rollback on failure
>
> **Permissions (Two-Layer Fallback):**
> 22. ✅ **Layer 1:** Check wallet-level permissions first (granular override)
> 23. ✅ **Layer 2:** Fallback to account membership roles (inheritance)
> 24. ✅ **Ory Keto Relations:** Define `owner`, `admin`, `member`, `viewer` relations
>
> **Testing & Flexibility:**
> 25. ✅ **In-Memory Adapters:** Provide mock implementations for all interfaces
> 26. ✅ **Configuration-Based:** Adapter selection via environment variables / DI container
> 27. ✅ **Gradual Migration:** Can run multiple adapters simultaneously during transition
> 28. ✅ **Unit Tests:** Use in-memory adapters (no external dependencies)
> 29. ✅ **Integration Tests:** Use real adapters against test instances

---

## 📁 Project Structure

```
finaegis-go/
├── control-plane/              # Control Plane (Infrastructure Layer)
│   ├── cmd/
│   │   ├── api/                # Control Plane API server
│   │   └── provisioner/        # Tenant provisioning worker
│   ├── internal/
│   │   ├── tenant/             # Tenant registry & management
│   │   ├── provisioning/       # Tenant provisioning workflows
│   │   │   ├── workflow/       # Temporal workflows
│   │   │   └── activity/       # Temporal activities
│   │   └── routing/            # Ory Oathkeeper configuration
│   └── api/                    # Control Plane API contracts
│
├── tenant-plane/               # Tenant Plane (Business Logic Layer)
│   ├── cmd/
│   │   ├── api/                # Tenant API server
│   │   └── worker/             # Background workers
│   ├── internal/
│   │   ├── domain/             # Domain layer (DDD + Hexagonal)
│   │   │   ├── account/        # Account domain
│   │   │   │   ├── aggregate/  # Aggregates, entities
│   │   │   │   ├── valueobject/# Value objects
│   │   │   │   ├── command/    # Commands
│   │   │   │   ├── query/      # Queries
│   │   │   │   ├── service/    # Domain services
│   │   │   │   ├── ports/      # 🔌 INTERFACES (defined BY domain!)
│   │   │   │   │   ├── wallet.go      # WalletService interface
│   │   │   │   │   ├── ledger.go      # LedgerService interface
│   │   │   │   │   ├── identity.go    # IdentityProvider interface
│   │   │   │   │   ├── authz.go       # AuthorizationProvider interface
│   │   │   │   │   └── workflow.go    # WorkflowOrchestrator interface
│   │   │   │   ├── workflow/   # Temporal workflow definitions
│   │   │   │   └── repository/ # Repository interfaces
│   │   │   ├── payment/        # Payment domain (similar structure)
│   │   │   ├── compliance/     # Compliance domain
│   │   │   └── shared/         # Shared kernel
│   │   │       └── ports/      # Shared interfaces (EventStore, EventBus, etc.)
│   │   ├── application/        # Application layer
│   │   │   ├── handler/        # Command/query handlers
│   │   │   └── service/        # Application services (use case orchestration)
│   │   ├── infrastructure/     # Infrastructure layer
│   │   │   ├── adapters/       # 🔌 VENDOR ADAPTERS (Hexagonal Architecture)
│   │   │   │   ├── wallet/     # WalletService implementations
│   │   │   │   │   ├── formance_wallet_adapter.go    # Formance implementation
│   │   │   │   │   ├── inmemory_wallet_adapter.go    # In-memory for testing
│   │   │   │   │   └── blockchain_wallet_adapter.go  # Alternative implementation
│   │   │   │   ├── ledger/     # LedgerService implementations
│   │   │   │   │   ├── formance_ledger_adapter.go
│   │   │   │   │   └── tigerbeetle_ledger_adapter.go
│   │   │   │   ├── authz/      # AuthorizationProvider implementations
│   │   │   │   │   ├── ory_keto_adapter.go           # Ory Keto implementation
│   │   │   │   │   ├── casbin_adapter.go             # Casbin alternative
│   │   │   │   │   └── inmemory_authz_adapter.go
│   │   │   │   ├── identity/   # IdentityProvider implementations
│   │   │   │   │   ├── ory_kratos_adapter.go
│   │   │   │   │   ├── auth0_adapter.go
│   │   │   │   │   └── keycloak_adapter.go
│   │   │   │   ├── gateway/    # APIGateway implementations
│   │   │   │   │   ├── ory_oathkeeper_adapter.go
│   │   │   │   │   ├── kong_adapter.go
│   │   │   │   │   └── envoy_adapter.go
│   │   │   │   └── workflow/   # WorkflowOrchestrator implementations
│   │   │   │       ├── temporal_adapter.go
│   │   │   │       └── cadence_adapter.go
│   │   │   ├── persistence/    # GORM repositories (read models)
│   │   │   ├── http/           # Gin HTTP handlers
│   │   │   ├── middleware/     # Schema isolation, auth, logging
│   │   │   ├── config/         # DI container, adapter wiring
│   │   │   │   └── container.go # Configuration-based adapter selection
│   │   │   └── external/       # External API clients
│   │   └── api/                # API contracts (OpenAPI)
│   └── migrations/             # Database migrations
│
├── pkg/                        # Shared libraries (used by both planes)
│   ├── telemetry/              # OpenTelemetry, logging, metrics
│   ├── errors/                 # Standard error types
│   ├── middleware/             # Shared middleware
│   └── testing/                # Testing utilities
│
├── deployments/
│   ├── docker/
│   │   ├── docker-compose.yml  # Ory + Formance + Temporal services
│   │   ├── ory/                # Ory configuration files
│   │   └── formance/           # Formance configuration files
│   └── kubernetes/             # K8s manifests for production
│
└── scripts/
    ├── init-tenant.sh          # Manual tenant creation
    ├── migrate.sh              # Database migrations
    └── seed-test-data.sh       # Test data seeding
```

---

## 🔄 Adapter Wiring Example

```go
// Configuration-based adapter selection
package config

import (
    "github.com/finaegis/core/internal/domain/account/ports"
    "github.com/finaegis/core/internal/infrastructure/adapters/wallet"
    "github.com/finaegis/core/internal/infrastructure/adapters/authz"
    "github.com/finaegis/core/internal/infrastructure/adapters/identity"
    "github.com/finaegis/core/internal/infrastructure/adapters/workflow"
)

type Config struct {
    WalletProvider   string // "formance", "inmemory", "blockchain"
    AuthzProvider    string // "ory-keto", "casbin", "inmemory"
    IdentityProvider string // "ory-kratos", "auth0", "keycloak"
    WorkflowProvider string // "temporal", "cadence"
}

type Container struct {
    walletService ports.WalletService
    authzProvider ports.AuthorizationProvider
    identityProvider ports.IdentityProvider
    workflowOrchestrator ports.WorkflowOrchestrator
}

func NewContainer(cfg Config) *Container {
    c := &Container{}

    // Wire wallet service based on config
    switch cfg.WalletProvider {
    case "formance":
        c.walletService = wallet.NewFormanceAdapter(cfg.FormanceAPIKey)
    case "inmemory":
        c.walletService = wallet.NewInMemoryAdapter()
    case "blockchain":
        c.walletService = wallet.NewBlockchainAdapter(cfg.BlockchainRPC)
    default:
        panic("unknown wallet provider: " + cfg.WalletProvider)
    }

    // Wire authorization provider
    switch cfg.AuthzProvider {
    case "ory-keto":
        c.authzProvider = authz.NewOryKetoAdapter(cfg.KetoURL)
    case "casbin":
        c.authzProvider = authz.NewCasbinAdapter(cfg.CasbinModel)
    case "inmemory":
        c.authzProvider = authz.NewInMemoryAdapter()
    }

    // Wire identity provider
    switch cfg.IdentityProvider {
    case "ory-kratos":
        c.identityProvider = identity.NewOryKratosAdapter(cfg.KratosURL)
    case "auth0":
        c.identityProvider = identity.NewAuth0Adapter(cfg.Auth0Domain)
    case "keycloak":
        c.identityProvider = identity.NewKeycloakAdapter(cfg.KeycloakURL)
    }

    // Wire workflow orchestrator
    switch cfg.WorkflowProvider {
    case "temporal":
        c.workflowOrchestrator = workflow.NewTemporalAdapter(cfg.TemporalURL)
    case "cadence":
        c.workflowOrchestrator = workflow.NewCadenceAdapter(cfg.CadenceURL)
    }

    return c
}

// Application services receive interfaces
func (c *Container) NewTransferService() *application.TransferService {
    return &application.TransferService{
        walletService: c.walletService,   // Injected interface!
        authzProvider: c.authzProvider,   // Injected interface!
    }
}
```

**Environment Configuration:**

```bash
# .env.development (local testing)
WALLET_PROVIDER=inmemory
AUTHZ_PROVIDER=inmemory
IDENTITY_PROVIDER=inmemory
WORKFLOW_PROVIDER=inmemory

# .env.staging (integration testing)
WALLET_PROVIDER=formance
AUTHZ_PROVIDER=ory-keto
IDENTITY_PROVIDER=ory-kratos
WORKFLOW_PROVIDER=temporal

# .env.production (optimized stack)
WALLET_PROVIDER=formance
AUTHZ_PROVIDER=ory-keto
IDENTITY_PROVIDER=ory-kratos
WORKFLOW_PROVIDER=temporal
```

---

This architectural specification provides the foundation for all migration tasks. The hexagonal architecture ensures vendor independence while the cell-based model provides strict multi-tenancy. Ory, Formance, and Temporal are selected as defaults but remain swappable through the adapter pattern.
