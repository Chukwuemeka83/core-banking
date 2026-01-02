# FinAegis Golang Migration - Cell-Based Multi-Tenant Architecture

> **Complete source of truth for PHP/Laravel to Golang migration**
>
> **Architecture:** Cell-Based (Shared-Nothing) + Ory Stack + **HYBRID (Formance + Event Horizon)**
>
> 191 comprehensive, AI-agent-executable atomic tasks covering 15 domains

---

## 🏗️ Architectural Overview

### **🔄 HYBRID Event Sourcing Strategy**

**Critical Design Decision:** We use **TWO complementary systems** based on domain requirements:

| Domain Class | Technology | Use Cases |
|--------------|------------|-----------|
| **Class A - Financial** | Formance Ledger + Wallets | Account balances, Payment transactions, Exchange trades, Lending repayments, Treasury movements, Stablecoin operations |
| **Class B - Non-Financial** | Event Horizon (Event Sourcing) | Compliance alerts, KYC verification, AML monitoring, Fraud detection, Governance votes, AI agent decisions, Audit logs |

**Rationale:**
- **Formance** provides battle-tested immutable ledger for financial correctness
- **Event Horizon** offers flexible event sourcing for complex workflows requiring replay capability
- **Best of both worlds:** Financial accuracy + Workflow flexibility

---

### **🔌 Hexagonal Architecture (Ports & Adapters)**

**CRITICAL DESIGN PRINCIPLE:** Decouple business logic from infrastructure vendors.

```
┌──────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                          │
│  ┌────────────────────────────────────────────────┐      │
│  │  Business Logic (Pure Go, No Vendor Imports)   │      │
│  │  • Aggregates, Entities, Value Objects         │      │
│  │  • Domain Services, Commands, Queries          │      │
│  └────────────────┬───────────────────────────────┘      │
│                   │ Depends on ▼                          │
│  ┌────────────────▼───────────────────────────────┐      │
│  │  PORTS (Interfaces - Defined by Domain)        │      │
│  │  • LedgerService interface                     │      │
│  │  • WalletService interface                     │      │
│  │  • IdentityProvider interface                  │      │
│  │  • AuthorizationProvider interface             │      │
│  │  • EventStore interface                        │      │
│  └────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────┘
                          │ Implemented by ▼
┌──────────────────────────────────────────────────────────┐
│               INFRASTRUCTURE LAYER                        │
│  ┌──────────────────────────────────────────────────┐    │
│  │  ADAPTERS (Implementations - Pluggable)          │    │
│  │  • FormanceLedgerAdapter (implements LedgerSvc)  │    │
│  │  • FormanceWalletAdapter (implements WalletSvc)  │    │
│  │  • OryKratosAdapter (implements IdentityProv)    │    │
│  │  • OryKetoAdapter (implements AuthzProvider)     │    │
│  │  • EventHorizonAdapter (implements EventStore)   │    │
│  │  • TemporalAdapter (implements WorkflowOrch)     │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  Alternative Adapters (Swap without changing domain):     │
│  • TigerBeetleAdapter, Auth0Adapter, CasbinAdapter, etc. │
└──────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ **Vendor Independence**: Switch Formance → TigerBeetle without changing business logic
- ✅ **Testability**: Mock interfaces for unit tests (no external services needed)
- ✅ **Flexibility**: Run with in-memory adapters in development
- ✅ **Migration**: Gradual migration from one vendor to another
- ✅ **Cost Control**: Switch to cheaper alternatives when needed

**Example:**
```go
// ❌ BAD: Domain imports vendor directly
import "github.com/formancehq/formance-sdk-go"  // NEVER in domain!

// ✅ GOOD: Domain depends on interface
type LedgerService interface {
    CreateTransaction(ctx, tx) error
    GetBalance(ctx, walletID) (Balance, error)
}

// Adapter implements interface
type FormanceLedgerAdapter struct {
    client *formance.Client  // Vendor import OK in adapter
}
```

---

### **The Cell-Based Model**

We are building a **Strict Multi-Tenant (Shared-Nothing)** fintech platform divided into two distinct planes:

#### **1. Control Plane (Infrastructure Layer)**
- **Role:** Manages "Cells" (Tenants), billing, routing
- **Components:** Global Admin API, Ory Oathkeeper Router, Tenant Provisioning (Temporal)
- **Data Access:** NO access to customer financial data

#### **2. Tenant Plane (Data Silos)**
- **Role:** Isolated environment for each B2B Customer (Tenant) and their End-Users
- **Components:**
  - Dedicated PostgreSQL Schema (`schema_tenant_{id}`)
  - Dedicated Ory Kratos Realm (identity)
  - Dedicated Formance Ledger Instance
  - Dedicated Formance Wallets Instance

### **Technology Stack (Vendor-Agnostic Architecture)**

**CRITICAL:** We use **Hexagonal Architecture (Ports & Adapters)** to decouple from vendors.

| Component | Port (Interface) | Default Adapter | Alternative Adapters |
|-----------|------------------|-----------------|----------------------|
| **Identity** | `IdentityProvider` | Ory Kratos | Auth0, Keycloak, Cognito, Custom |
| **Authorization** | `AuthorizationProvider` | Ory Keto (ReBAC) | Casbin, OPA, Custom RBAC |
| **Gateway** | `APIGateway` | Ory Oathkeeper | Kong, Traefik, Envoy, Custom |
| **Financial Ledger** | `LedgerService` | Formance Ledger | TigerBeetle, Custom, PostgreSQL |
| **Wallet Engine** | `WalletService` | Formance Wallets | Custom, Blockchain Nodes |
| **Event Store** | `EventStore` | Event Horizon (PostgreSQL) | EventStoreDB, Custom PostgreSQL |
| **Event Bus** | `EventBus` | Redis Streams | NATS, Kafka, RabbitMQ |
| **Workflow Engine** | `WorkflowOrchestrator` | Temporal | Cadence, Custom State Machine |
| **Database** | Standard SQL | PostgreSQL 16 | MySQL, CockroachDB |
| **Cache** | Standard Cache | Redis 7 | Memcached, Valkey |
| **Observability** | Standard Telemetry | OpenTelemetry | Datadog, New Relic |

**Key Principle:** Business logic NEVER imports vendor packages directly. Only adapters do.

### **Data Hierarchy**

```
Tenant (B2B Customer - The Cell)
  └─ Account (Logical Container - B2C or B2B)
      ├─ Wallet 1 (Multi-Asset: USD, EUR, BTC, etc.)
      ├─ Wallet 2 (Multi-Asset)
      └─ Users (Members with Roles)
          ├─ User A (OWNER / ADMIN)
          ├─ User B (MEMBER)
          └─ User C (VIEWER)
```

**Key Principle:** Users and Wallets are NEVER directly linked - always through Account.

### **Authorization Model (Two-Layer Fallback)**

**Layer 1 - Granular Override:**
Check: "Does User Bob have explicit `can_debit` on Wallet_123?"
Use Case: Allow junior employee to spend only from "Petty Cash Wallet"

**Layer 2 - Account Membership Inheritance:**
Check: "Is User Bob an `ADMIN` of parent Account?"
Logic: If yes, inherit full access to all Account's wallets

---

## 📊 Task Breakdown

**Total Tasks:** 191
**Total Estimated Hours:** 2,344 hours (~59 weeks)
**Completion Status:** 0% (Hybrid architecture redesigned - ready to implement)
**Last Updated:** 2026-01-01

### Phase Summary

| Phase | Domain | Technology | Tasks | Hours | Weeks |
|-------|--------|------------|-------|-------|-------|
| 0 | Infrastructure & Ory/Formance Setup | Ory + Formance | 10 | 96 | 2.5 |
| 1 | Control Plane (Tenant Provisioning) | Temporal | 8 | 84 | 2 |
| 2 | Ory Stack Integration | Ory Kratos/Keto/Oathkeeper | 12 | 120 | 3 |
| 3 | Formance Integration | Formance Ledger/Wallets | 10 | 100 | 2.5 |
| 4 | **Event Horizon Setup** | **Event Horizon** | **8** | **64** | **1.5** |
| 5 | Schema-per-Tenant Middleware | PostgreSQL | 6 | 48 | 1.5 |
| 6 | Account Domain (Cell-Based) | Formance (balances) + GORM | 8 | 80 | 2 |
| 7 | Payment Domain (Formance-Based) | Formance | 10 | 100 | 2.5 |
| 8 | **Compliance & KYC** | **Event Horizon** | **18** | **220** | **5.5** |
| 9 | Exchange (Formance-Based) | Formance | 12 | 140 | 3.5 |
| 10 | Treasury (Formance-Based) | Formance | 14 | 180 | 4.5 |
| 11 | Lending (Formance-Based) | Formance | 10 | 120 | 3 |
| 12 | Stablecoin (Formance-Based) | Formance | 9 | 110 | 3 |
| 13 | Wallet/Blockchain | Formance + Ethereum | 12 | 160 | 4 |
| 14 | **AI & Agent Coordination** | **Event Horizon** | **9** | **110** | **3** |
| 15 | **CGO & Governance** | **Event Horizon** | **13** | **170** | **4.5** |
| 16 | Monitoring & Supporting | OpenTelemetry | 13 | 142 | 3.5 |
| **TOTAL** | **All Domains** | **Hybrid** | **191** | **2,344** | **~59** |

**Legend:**
- **Bold** = Event Horizon-based domains (non-financial workflows)
- Regular = Formance-based domains (financial operations)

---

## 🚨 Critical Directives

> **MUST FOLLOW:**
>
> **Architectural Principles:**
> 1. **Hexagonal Architecture:** Domain depends on INTERFACES, not vendor SDKs
> 2. **Dependency Inversion:** Infrastructure implements domain interfaces
> 3. **Vendor Independence:** All vendor SDKs isolated in adapter layer
> 4. **Interface Segregation:** Each port has single, focused responsibility
>
> **Multi-Tenancy:**
> 5. **Strict Plane Separation:** Control Plane NEVER accesses Tenant Plane data
> 6. **Schema Isolation:** Middleware MUST set `search_path` per request
> 7. **All Entities Tenant-Scoped:** No global user/wallet/event tables
>
> **Hybrid Event Strategy:**
> 8. **Financial Operations:** Use `LedgerService` interface (default: Formance adapter)
> 9. **Non-Financial Workflows:** Use `EventStore` interface (default: Event Horizon adapter)
> 10. **Clear Domain Classification:** Financial vs Non-Financial strictly separated
>
> **Security & Identity:**
> 11. **Identity Abstraction:** Use `IdentityProvider` interface (default: Ory Kratos adapter)
> 12. **Authorization Abstraction:** Use `AuthorizationProvider` interface (default: Ory Keto adapter)
> 13. **NO Password Storage:** Identity provider handles authentication
> 14. **NO Balance in PostgreSQL:** Ledger service handles financial state
>
> **Testing & Flexibility:**
> 15. **Mock Adapters:** Provide in-memory implementations for testing
> 16. **Configuration-Based:** Adapter selection via config (DI container)
> 17. **Gradual Migration:** Can run multiple adapters simultaneously

---


## Phase 0: Infrastructure & Ory/Formance Setup

**Duration:** Weeks 1-2
**Goal:** Set up foundational infrastructure with Ory stack and Formance services
**Dependencies:** None

---

### Task 0.1: Bootstrap Golang Project with Cell Architecture

**Task ID:** P0-INFRA-001
**Description:** Initialize Golang monorepo with Control Plane + Tenant Plane separation
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** None

**Acceptance Criteria:**
- [ ] Project structure created with `control-plane/` and `tenant-plane/` separation
- [ ] Go modules initialized (go 1.21+)
- [ ] Docker Compose configured for Ory stack + Formance
- [ ] Makefile with development commands
- [ ] .env.example with all required variables

**Files to Create:**
```
finaegis-go/
├── control-plane/              # Tenant management, provisioning
│   ├── cmd/
│   │   ├── api/               # Control Plane API
│   │   └── provisioner/       # Tenant provisioning worker
│   └── internal/
│       ├── tenant/            # Tenant registry
│       ├── provisioning/      # Provisioning workflows
│       └── routing/           # Ory Oathkeeper config
├── tenant-plane/              # Business logic (runtime)
│   ├── cmd/
│   │   ├── api/               # Tenant API server
│   │   └── worker/            # Background workers
│   └── internal/
│       ├── domain/            # Domain logic
│       ├── middleware/        # Schema isolation
│       └── integration/       # Ory/Formance clients
├── pkg/                       # Shared libraries
│   ├── ory/                   # Ory SDK wrappers
│   ├── formance/              # Formance SDK wrappers
│   └── telemetry/             # Observability
├── deployments/
│   └── docker/
│       └── docker-compose.yml  # Ory + Formance services
└── scripts/
    └── init-tenant.sh         # Manual tenant creation script
```

**Implementation:**
```bash
# Create directory structure
mkdir -p finaegis-go/{control-plane,tenant-plane,pkg,deployments,scripts}

# Initialize Go modules
cd finaegis-go
go mod init github.com/finaegis/core

# Add dependencies
go get github.com/ory/client-go
go get github.com/formancehq/stack/libs/go-libs
go get github.com/gin-gonic/gin
go get go.temporal.io/sdk
go get gorm.io/gorm
go get gorm.io/driver/postgres
go get github.com/shopspring/decimal
go get go.uber.org/zap
go get go.opentelemetry.io/otel
```

**Testing:**
```bash
make verify    # Verify project structure
make build     # Build all binaries
go mod verify  # Verify dependencies
```

---

### Task 0.2: Docker Compose for Ory Stack

**Task ID:** P0-INFRA-002
**Description:** Configure Docker Compose with Ory Kratos, Keto, Oathkeeper
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P0-INFRA-001

**Acceptance Criteria:**
- [ ] Ory Kratos running on port 4433 (public), 4434 (admin)
- [ ] Ory Keto running on port 4466 (read), 4467 (write)
- [ ] Ory Oathkeeper running on port 4455 (proxy), 4456 (API)
- [ ] PostgreSQL 16 for Ory storage
- [ ] Mailslurper for email testing (Kratos notifications)
- [ ] Health checks configured for all services

**Files to Create:**
```
deployments/docker/docker-compose.yml
deployments/docker/ory/kratos/config.yml
deployments/docker/ory/keto/config.yml
deployments/docker/ory/oathkeeper/config.yml
deployments/docker/ory/oathkeeper/access-rules.yml
```

**Docker Compose Configuration:**
```yaml
version: '3.9'

services:
  # PostgreSQL for Ory persistence
  ory-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ory
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: ory
    volumes:
      - ory-postgres-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"

  # Ory Kratos - Identity Management
  kratos:
    image: oryd/kratos:v1.0
    ports:
      - "4433:4433"  # Public API
      - "4434:4434"  # Admin API
    environment:
      DSN: postgres://ory:secret@ory-postgres:5432/ory?sslmode=disable
      LOG_LEVEL: debug
    command: serve -c /etc/config/kratos/config.yml --dev --watch-courier
    volumes:
      - ./ory/kratos:/etc/config/kratos
    depends_on:
      - ory-postgres
      - mailslurper

  # Ory Keto - Permissions (ReBAC)
  keto:
    image: oryd/keto:v0.11
    ports:
      - "4466:4466"  # Read API
      - "4467:4467"  # Write API
    environment:
      DSN: postgres://ory:secret@ory-postgres:5432/ory?sslmode=disable
      LOG_LEVEL: debug
    command: serve -c /etc/config/keto/config.yml
    volumes:
      - ./ory/keto:/etc/config/keto
    depends_on:
      - ory-postgres

  # Ory Oathkeeper - Gateway/Proxy
  oathkeeper:
    image: oryd/oathkeeper:v0.40
    ports:
      - "4455:4455"  # Proxy
      - "4456:4456"  # API
    environment:
      LOG_LEVEL: debug
    command: serve -c /etc/config/oathkeeper/config.yml
    volumes:
      - ./ory/oathkeeper:/etc/config/oathkeeper
    depends_on:
      - kratos
      - keto

  # Mailslurper - Email testing
  mailslurper:
    image: oryd/mailslurper:latest-smtps
    ports:
      - "4436:4436"  # Web UI
      - "4437:4437"  # SMTP

volumes:
  ory-postgres-data:
```

**Kratos Configuration (`ory/kratos/config.yml`):**
```yaml
dsn: postgres://ory:secret@ory-postgres:5432/ory?sslmode=disable

serve:
  public:
    base_url: http://localhost:4433/
    cors:
      enabled: true
  admin:
    base_url: http://localhost:4434/

selfservice:
  default_browser_return_url: http://localhost:3000/
  flows:
    error:
      ui_url: http://localhost:3000/error
    settings:
      ui_url: http://localhost:3000/settings
    recovery:
      enabled: true
      ui_url: http://localhost:3000/recovery
    verification:
      enabled: true
      ui_url: http://localhost:3000/verification
    logout:
      after:
        default_browser_return_url: http://localhost:3000/login
    login:
      ui_url: http://localhost:3000/login
    registration:
      ui_url: http://localhost:3000/registration

identity:
  default_schema_id: default
  schemas:
    - id: default
      url: file:///etc/config/kratos/identity.schema.json

courier:
  smtp:
    connection_uri: smtps://test:test@mailslurper:1025/?skip_ssl_verify=true
```

**Keto Configuration (`ory/keto/config.yml`):**
```yaml
dsn: postgres://ory:secret@ory-postgres:5432/ory?sslmode=disable

serve:
  read:
    port: 4466
  write:
    port: 4467

namespaces:
  - id: 0
    name: accounts
  - id: 1
    name: wallets
  - id: 2
    name: transactions
```

**Testing:**
```bash
# Start Ory stack
docker-compose up -d

# Verify Kratos
curl http://localhost:4433/health/ready

# Verify Keto
curl http://localhost:4466/health/ready

# Verify Oathkeeper
curl http://localhost:4455/health/ready

# Access Mailslurper UI
open http://localhost:4436
```

---

### Task 0.3: Docker Compose for Formance Services

**Task ID:** P0-INFRA-003
**Description:** Configure Formance Ledger and Wallets services
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P0-INFRA-001

**Acceptance Criteria:**
- [ ] Formance Ledger running on port 3068
- [ ] Formance Wallets running on port 8080
- [ ] PostgreSQL 16 for Formance storage
- [ ] Formance UI (Control) running on port 8081
- [ ] Health checks configured

**Update Docker Compose:**
```yaml
  # PostgreSQL for Formance
  formance-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: formance
      POSTGRES_PASSWORD: formance
      POSTGRES_DB: formance
    volumes:
      - formance-postgres-data:/var/lib/postgresql/data
    ports:
      - "5434:5432"

  # Formance Ledger
  formance-ledger:
    image: ghcr.io/formancehq/ledger:latest
    ports:
      - "3068:3068"
    environment:
      POSTGRES_URI: postgresql://formance:formance@formance-postgres:5432/formance?sslmode=disable
      STORAGE_DRIVER: postgres
      BIND: 0.0.0.0:3068
    depends_on:
      - formance-postgres
    command: server

  # Formance Wallets
  formance-wallets:
    image: ghcr.io/formancehq/wallets:latest
    ports:
      - "8080:8080"
    environment:
      LEDGER_URL: http://formance-ledger:3068
      POSTGRES_URI: postgresql://formance:formance@formance-postgres:5432/formance?sslmode=disable
      BIND: 0.0.0.0:8080
    depends_on:
      - formance-ledger

  # Formance Control (UI)
  formance-control:
    image: ghcr.io/formancehq/control:latest
    ports:
      - "8081:8081"
    environment:
      LEDGER_URL: http://formance-ledger:3068
      WALLETS_URL: http://formance-wallets:8080
    depends_on:
      - formance-ledger
      - formance-wallets

volumes:
  formance-postgres-data:
```

**Testing:**
```bash
# Start Formance stack
docker-compose up -d

# Verify Ledger
curl http://localhost:3068/_info

# Verify Wallets
curl http://localhost:8080/_info

# Access Formance Control UI
open http://localhost:8081
```

---

### Task 0.4: PostgreSQL Multi-Schema Setup

**Task ID:** P0-INFRA-004
**Description:** Configure PostgreSQL for schema-per-tenant isolation
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P0-INFRA-001

**Acceptance Criteria:**
- [ ] PostgreSQL 16 configured with multi-schema support
- [ ] Control Plane database created (`finaegis_control`)
- [ ] Migration system configured (Goose)
- [ ] Initial control plane migrations created
- [ ] Schema creation SQL templates ready

**Docker Compose Update:**
```yaml
  # PostgreSQL for Tenant Plane (multi-schema)
  tenant-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: finaegis
      POSTGRES_PASSWORD: finaegis
      POSTGRES_MULTIPLE_DATABASES: finaegis_control
    volumes:
      - tenant-postgres-data:/var/lib/postgresql/data
      - ./postgres/init-multi-schema.sh:/docker-entrypoint-initdb.d/init.sh
    ports:
      - "5432:5432"

volumes:
  tenant-postgres-data:
```

**Init Script (`postgres/init-multi-schema.sh`):**
```bash
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- Control Plane database
    CREATE DATABASE finaegis_control;

    -- Grant schema creation privilege
    GRANT CREATE ON DATABASE finaegis_control TO finaegis;
EOSQL

# Connect to control plane DB and create initial schema
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="finaegis_control" <<-EOSQL
    -- Tenants registry table
    CREATE TABLE IF NOT EXISTS tenants (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        slug VARCHAR(100) UNIQUE NOT NULL,
        domain VARCHAR(255) UNIQUE NOT NULL,
        schema_name VARCHAR(63) UNIQUE NOT NULL,
        formance_ledger_id VARCHAR(255),
        formance_org_id VARCHAR(255),
        kratos_realm_id VARCHAR(255),
        status VARCHAR(20) DEFAULT 'provisioning',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
    );

    -- Tenant routing table
    CREATE TABLE IF NOT EXISTS tenant_routing (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
        domain VARCHAR(255) UNIQUE NOT NULL,
        is_primary BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX idx_tenant_routing_tenant ON tenant_routing(tenant_id);
    CREATE INDEX idx_tenant_routing_domain ON tenant_routing(domain);
EOSQL

echo "Control Plane database initialized successfully"
```

**Control Plane Migrations:**
```sql
-- migrations/control_plane/00001_create_tenants.sql
-- +goose Up
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    domain VARCHAR(255) UNIQUE NOT NULL,
    schema_name VARCHAR(63) UNIQUE NOT NULL,
    formance_ledger_id VARCHAR(255),
    formance_org_id VARCHAR(255),
    kratos_realm_id VARCHAR(255),
    keto_namespace_prefix VARCHAR(63),
    status VARCHAR(20) DEFAULT 'provisioning',
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_domain ON tenants(domain);
CREATE INDEX idx_tenants_status ON tenants(status);

-- +goose Down
DROP TABLE tenants;
```

**Tenant Schema Template (`scripts/tenant-schema-template.sql`):**
```sql
-- Template for creating new tenant schema
-- Usage: Replace {TENANT_SCHEMA} with actual schema name

CREATE SCHEMA IF NOT EXISTS {TENANT_SCHEMA};

-- Set search path
SET search_path TO {TENANT_SCHEMA};

-- Accounts table (NO tenant_id needed - isolated by schema!)
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kratos_user_id UUID NOT NULL,  -- FK to Ory Kratos identity
    account_type VARCHAR(50) NOT NULL,  -- 'personal', 'business'
    status VARCHAR(20) DEFAULT 'active',
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_accounts_user ON accounts(kratos_user_id);
CREATE INDEX idx_accounts_status ON accounts(status);

-- Wallets table (maps to Formance Wallets)
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
    formance_wallet_id VARCHAR(255) UNIQUE NOT NULL,  -- FK to Formance
    name VARCHAR(255) NOT NULL,
    purpose VARCHAR(100),  -- 'operating', 'savings', 'treasury'
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_wallets_account ON wallets(account_id);
CREATE INDEX idx_wallets_formance ON wallets(formance_wallet_id);

-- Account members (users who can access account)
CREATE TABLE account_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
    kratos_user_id UUID NOT NULL,
    role VARCHAR(50) NOT NULL,  -- 'owner', 'admin', 'member', 'viewer'
    added_by UUID,
    added_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_account_members_account ON account_members(account_id);
CREATE INDEX idx_account_members_user ON account_members(kratos_user_id);
CREATE UNIQUE INDEX idx_account_members_unique ON account_members(account_id, kratos_user_id);

-- User profiles (supplemental to Kratos identity)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,  -- Same as Kratos identity ID
    kratos_identity_id UUID UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone_number VARCHAR(20),
    kyc_status VARCHAR(20) DEFAULT 'pending',
    kyc_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_profiles_kratos ON user_profiles(kratos_identity_id);
```

**Testing:**
```bash
# Run control plane migrations
goose -dir migrations/control_plane postgres "postgresql://finaegis:finaegis@localhost:5432/finaegis_control" up

# Create test tenant schema
psql -h localhost -U finaegis -d finaegis_control -c "SELECT create_tenant_schema('tenant_test123');"

# Verify schema exists
psql -h localhost -U finaegis -d finaegis_control -c "\dn"
```

---

[Continue with remaining Phase 0 tasks 0.5-0.10...]


## Phase 1: Control Plane - Tenant Provisioning

**Duration:** Weeks 3-4
**Goal:** Build Control Plane for tenant lifecycle management
**Dependencies:** Phase 0

---

### Task 1.1: Tenant Registry Service

**Task ID:** P1-CONTROL-001
**Description:** Implement Tenant Registry for managing tenant metadata
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P0-INFRA-004

**Acceptance Criteria:**
- [ ] Tenant CRUD operations
- [ ] Domain lookup (map domain → tenant)
- [ ] Schema name generation (deterministic)
- [ ] Tenant status management (provisioning, active, suspended)
- [ ] Metadata storage (JSONB)

**Files to Create:**
```
control-plane/internal/tenant/
├── model.go           # Tenant struct
├── repository.go      # GORM repository
├── service.go         # Business logic
└── service_test.go    # Unit tests
```

**Implementation:**
```go
// control-plane/internal/tenant/model.go
package tenant

import (
    "time"
    "github.com/google/uuid"
)

type Tenant struct {
    ID                  uuid.UUID   `gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
    Name                string      `gorm:"not null;size:255"`
    Slug                string      `gorm:"unique;not null;size:100"`
    Domain              string      `gorm:"unique;not null;size:255"`
    SchemaName          string      `gorm:"unique;not null;size:63"`
    FormanceLedgerID    string      `gorm:"size:255"`
    FormanceOrgID       string      `gorm:"size:255"`
    KratosRealmID       string      `gorm:"size:255"`
    KetoNamespacePrefix string      `gorm:"size:63"`
    Status              TenantStatus `gorm:"size:20;default:'provisioning'"`
    Metadata            map[string]interface{} `gorm:"type:jsonb"`
    CreatedAt           time.Time
    UpdatedAt           time.Time
}

type TenantStatus string

const (
    TenantStatusProvisioning TenantStatus = "provisioning"
    TenantStatusActive       TenantStatus = "active"
    TenantStatusSuspended    TenantStatus = "suspended"
    TenantStatusDeleted      TenantStatus = "deleted"
)

// control-plane/internal/tenant/repository.go
package tenant

import (
    "context"
    "fmt"
    "gorm.io/gorm"
    "github.com/google/uuid"
)

type Repository interface {
    Create(ctx context.Context, tenant *Tenant) error
    GetByID(ctx context.Context, id uuid.UUID) (*Tenant, error)
    GetByDomain(ctx context.Context, domain string) (*Tenant, error)
    GetBySlug(ctx context.Context, slug string) (*Tenant, error)
    List(ctx context.Context, limit, offset int) ([]*Tenant, error)
    Update(ctx context.Context, tenant *Tenant) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type repository struct {
    db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
    return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, tenant *Tenant) error {
    return r.db.WithContext(ctx).Create(tenant).Error
}

func (r *repository) GetByDomain(ctx context.Context, domain string) (*Tenant, error) {
    var tenant Tenant
    err := r.db.WithContext(ctx).Where("domain = ?", domain).First(&tenant).Error
    if err != nil {
        return nil, err
    }
    return &tenant, nil
}

// control-plane/internal/tenant/service.go
package tenant

import (
    "context"
    "fmt"
    "strings"
    "github.com/google/uuid"
    "github.com/gosimple/slug"
)

type Service interface {
    CreateTenant(ctx context.Context, input CreateTenantInput) (*Tenant, error)
    GetTenantByDomain(ctx context.Context, domain string) (*Tenant, error)
    ActivateTenant(ctx context.Context, tenantID uuid.UUID) error
    SuspendTenant(ctx context.Context, tenantID uuid.UUID) error
}

type service struct {
    repo Repository
}

func NewService(repo Repository) Service {
    return &service{repo: repo}
}

type CreateTenantInput struct {
    Name   string
    Domain string
}

func (s *service) CreateTenant(ctx context.Context, input CreateTenantInput) (*Tenant, error) {
    // Generate slug from name
    tenantSlug := slug.Make(input.Name)

    // Generate schema name (max 63 chars for Postgres)
    schemaName := fmt.Sprintf("tenant_%s", strings.ReplaceAll(uuid.New().String(), "-", "")[:12])

    tenant := &Tenant{
        Name:       input.Name,
        Slug:       tenantSlug,
        Domain:     input.Domain,
        SchemaName: schemaName,
        Status:     TenantStatusProvisioning,
        Metadata:   make(map[string]interface{}),
    }

    if err := s.repo.Create(ctx, tenant); err != nil {
        return nil, fmt.Errorf("failed to create tenant: %w", err)
    }

    return tenant, nil
}

func (s *service) GetTenantByDomain(ctx context.Context, domain string) (*Tenant, error) {
    return s.repo.GetByDomain(ctx, domain)
}

func (s *service) ActivateTenant(ctx context.Context, tenantID uuid.UUID) error {
    tenant, err := s.repo.GetByID(ctx, tenantID)
    if err != nil {
        return err
    }

    tenant.Status = TenantStatusActive
    return s.repo.Update(ctx, tenant)
}
```

**Testing:**
```go
// control-plane/internal/tenant/service_test.go
package tenant_test

import (
    "testing"
    "context"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestTenantService_CreateTenant(t *testing.T) {
    db := setupTestDB(t)
    repo := tenant.NewRepository(db)
    svc := tenant.NewService(repo)

    ctx := context.Background()

    input := tenant.CreateTenantInput{
        Name:   "Acme Bank",
        Domain: "acme-bank.finaegis.com",
    }

    created, err := svc.CreateTenant(ctx, input)
    require.NoError(t, err)
    assert.NotNil(t, created.ID)
    assert.Equal(t, "acme-bank", created.Slug)
    assert.Equal(t, "acme-bank.finaegis.com", created.Domain)
    assert.NotEmpty(t, created.SchemaName)
    assert.Equal(t, tenant.TenantStatusProvisioning, created.Status)
}

func TestTenantService_GetByDomain(t *testing.T) {
    db := setupTestDB(t)
    repo := tenant.NewRepository(db)
    svc := tenant.NewService(repo)

    ctx := context.Background()

    // Create tenant
    input := tenant.CreateTenantInput{
        Name:   "Test Bank",
        Domain: "test.com",
    }
    created, _ := svc.CreateTenant(ctx, input)

    // Retrieve by domain
    retrieved, err := svc.GetTenantByDomain(ctx, "test.com")
    require.NoError(t, err)
    assert.Equal(t, created.ID, retrieved.ID)
}
```

---

[Continue with remaining Phase 1 tasks 1.2-1.8...]


## Phase 2: Ory Stack Integration

**Duration:** Weeks 5-7 (3 weeks)
**Goal:** Integrate Ory Kratos, Keto, and Oathkeeper
**Dependencies:** Phase 0, Phase 1

### Tasks Overview (12 tasks, 120 hours)

- **2.1:** Ory Kratos SDK Integration (tenant-scoped realms)
- **2.2:** Kratos Identity Schema Design (user profiles)
- **2.3:** Kratos Authentication Flows (login, registration, recovery)
- **2.4:** Kratos Session Management & Validation
- **2.5:** Ory Keto SDK Integration (ReBAC)
- **2.6:** Keto Namespace Configuration (accounts, wallets, transactions)
- **2.7:** Keto Relationship Tuple Management (create, delete, check)
- **2.8:** Two-Layer Permission Check Implementation
- **2.9:** Ory Oathkeeper Routing Configuration
- **2.10:** Oathkeeper Access Rules (domain → tenant mapping)
- **2.11:** Oathkeeper Authenticator/Authorizer Pipeline
- **2.12:** Integration Testing (Ory stack end-to-end)

[Detailed tasks to be added]

---

## Phase 3: Formance Integration

**Duration:** Weeks 8-10 (2.5 weeks)
**Goal:** Integrate Formance Ledger and Wallets
**Dependencies:** Phase 0, Phase 1

### Tasks Overview (10 tasks, 100 hours)

- **3.1:** Formance SDK Setup (Ledger + Wallets clients)
- **3.2:** Formance Ledger Instance Provisioning (per tenant)
- **3.3:** Formance Wallets Configuration (multi-asset support)
- **3.4:** Wallet Mapping Service (Postgres ↔ Formance IDs)
- **3.5:** Money Movement API (credit, debit, transfer via Formance)
- **3.6:** Balance Query Service (real-time from Formance)
- **3.7:** Transaction History Query (Formance Ledger API)
- **3.8:** Hold/Reserve Management (Formance holds)
- **3.9:** Multi-Asset Support (USD, EUR, BTC, etc.)
- **3.10:** Formance Webhooks (transaction notifications)

[Detailed tasks to be added]

---

## Phase 4: Event Horizon Setup (Event Sourcing for Non-Financial Domains)

**Duration:** Weeks 11-12 (1.5 weeks)
**Goal:** Set up Event Horizon framework for compliance, governance, and workflow domains
**Dependencies:** Phase 0

---

### Task 4.1: Event Horizon SDK Installation

**Task ID:** P4-EVENTHORIZON-001
**Description:** Install and configure Event Horizon v0.16+ for event sourcing
**Priority:** Critical
**Complexity:** S (1-3h)

**Dependencies:** P0-INFRA-001

**Acceptance Criteria:**
- [ ] Event Horizon SDK installed (github.com/looplab/eventhorizon)
- [ ] MongoDB driver for event store configured
- [ ] Redis for event bus configured
- [ ] Basic event store configuration working

**Implementation:**
```bash
go get github.com/looplab/eventhorizon/v2
go get github.com/looplab/eventhorizon/v2/eventstore/mongodb
go get github.com/looplab/eventhorizon/v2/eventbus/redis
```

**Configuration:**
```go
// pkg/eventhorizon/config.go
package eventhorizon

import (
    "context"
    "github.com/looplab/eventhorizon/v2"
    mongostore "github.com/looplab/eventhorizon/v2/eventstore/mongodb"
    redisbus "github.com/looplab/eventhorizon/v2/eventbus/redis"
)

func NewEventStore(ctx context.Context, tenantID string) (eventhorizon.EventStore, error) {
    // Tenant-scoped MongoDB collection
    collectionName := fmt.Sprintf("events_%s", tenantID)

    store, err := mongostore.NewEventStore(
        mongoURI,
        dbName,
        mongostore.WithCollectionName(collectionName),
    )
    return store, err
}

func NewEventBus(tenantID string) (eventhorizon.EventBus, error) {
    // Tenant-scoped Redis stream
    streamKey := fmt.Sprintf("events:%s", tenantID)

    return redisbus.NewEventBus(
        redisAddr,
        redisbus.WithStreamKey(streamKey),
    )
}
```

**Testing:**
```go
func TestEventStoreCreation(t *testing.T) {
    ctx := context.Background()
    store, err := NewEventStore(ctx, "test-tenant")
    require.NoError(t, err)
    assert.NotNil(t, store)
}
```

---

### Task 4.2: Tenant-Scoped Event Store Tables

**Task ID:** P4-EVENTHORIZON-002
**Description:** Configure PostgreSQL event store tables per tenant schema
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-001, P0-INFRA-004

**Acceptance Criteria:**
- [ ] Event store tables in each tenant schema
- [ ] Snapshot tables in each tenant schema
- [ ] Proper indexing for aggregate retrieval
- [ ] Migration templates created

**Schema Template:**
```sql
-- Add to tenant schema template
-- Event store for non-financial domains (Compliance, Governance, etc.)

CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    version INT NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    metadata JSONB,
    timestamp TIMESTAMP DEFAULT NOW(),
    UNIQUE(aggregate_id, version)
);

CREATE INDEX idx_events_aggregate ON events(aggregate_id);
CREATE INDEX idx_events_type ON events(aggregate_type);
CREATE INDEX idx_events_timestamp ON events(timestamp);

CREATE TABLE snapshots (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    version INT NOT NULL,
    data JSONB NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW(),
    UNIQUE(aggregate_id, version)
);

CREATE INDEX idx_snapshots_aggregate ON snapshots(aggregate_id);
```

**Testing:**
```bash
# Apply to test tenant schema
psql -c "SET search_path TO tenant_test123; \i event-store-schema.sql"
```

---

### Task 4.3: Aggregate Root Base Implementation

**Task ID:** P4-EVENTHORIZON-003
**Description:** Create base aggregate root with event sourcing patterns
**Priority:** Critical
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-002

**Acceptance Criteria:**
- [ ] Base aggregate interface defined
- [ ] Event application logic implemented
- [ ] Version tracking working
- [ ] Snapshot support added

**Implementation:**
```go
// pkg/eventhorizon/aggregate.go
package eventhorizon

import (
    "context"
    "github.com/google/uuid"
    eh "github.com/looplab/eventhorizon/v2"
)

// BaseAggregate provides common aggregate functionality
type BaseAggregate struct {
    ID      uuid.UUID
    Version int
    Events  []eh.Event
}

func (a *BaseAggregate) EntityID() uuid.UUID {
    return a.ID
}

func (a *BaseAggregate) AggregateVersion() int {
    return a.Version
}

func (a *BaseAggregate) ApplyEvent(ctx context.Context, event eh.Event) error {
    a.Events = append(a.Events, event)
    a.Version++
    return nil
}

// Example: Compliance Alert Aggregate
type ComplianceAlertAggregate struct {
    BaseAggregate

    AlertType   string
    Severity    string
    Status      string
    Description string
    AssignedTo  string
    ResolvedBy  string
}

const ComplianceAlertAggregateType eh.AggregateType = "compliance_alert"

func (a *ComplianceAlertAggregate) HandleCommand(ctx context.Context, cmd eh.Command) error {
    switch cmd := cmd.(type) {
    case *CreateAlertCommand:
        return a.handleCreateAlert(ctx, cmd)
    case *AssignAlertCommand:
        return a.handleAssignAlert(ctx, cmd)
    case *ResolveAlertCommand:
        return a.handleResolveAlert(ctx, cmd)
    default:
        return fmt.Errorf("unsupported command: %T", cmd)
    }
}

func (a *ComplianceAlertAggregate) handleCreateAlert(ctx context.Context, cmd *CreateAlertCommand) error {
    // Business validation
    if cmd.Severity == "" {
        return fmt.Errorf("severity required")
    }

    // Record domain event
    event := &AlertCreatedEvent{
        AlertID:     a.ID,
        AlertType:   cmd.AlertType,
        Severity:    cmd.Severity,
        Description: cmd.Description,
    }

    return a.ApplyEvent(ctx, event)
}

// Event handler
func (a *ComplianceAlertAggregate) ApplyEvent(ctx context.Context, event eh.Event) error {
    switch e := event.Data().(type) {
    case *AlertCreatedEvent:
        a.AlertType = e.AlertType
        a.Severity = e.Severity
        a.Status = "open"
        a.Description = e.Description
    case *AlertAssignedEvent:
        a.AssignedTo = e.AssignedTo
        a.Status = "investigating"
    case *AlertResolvedEvent:
        a.ResolvedBy = e.ResolvedBy
        a.Status = "resolved"
    }

    return a.BaseAggregate.ApplyEvent(ctx, event)
}
```

**Testing:**
```go
func TestComplianceAlertAggregate(t *testing.T) {
    aggregate := &ComplianceAlertAggregate{
        BaseAggregate: BaseAggregate{ID: uuid.New()},
    }

    cmd := &CreateAlertCommand{
        AlertType:   "suspicious_activity",
        Severity:    "high",
        Description: "Large cash transaction",
    }

    err := aggregate.HandleCommand(context.Background(), cmd)
    require.NoError(t, err)
    assert.Equal(t, "suspicious_activity", aggregate.AlertType)
    assert.Equal(t, "open", aggregate.Status)
}
```

---

### Task 4.4: Event Bus Configuration

**Task ID:** P4-EVENTHORIZON-004
**Description:** Set up event bus for domain event publishing
**Priority:** High
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-003

**Acceptance Criteria:**
- [ ] Redis-based event bus configured
- [ ] Tenant-scoped event streams
- [ ] Event handlers registration working
- [ ] Retry and error handling implemented

**Implementation:**
```go
// pkg/eventhorizon/eventbus.go
package eventhorizon

import (
    "context"
    eh "github.com/looplab/eventhorizon/v2"
    redisbus "github.com/looplab/eventhorizon/v2/eventbus/redis"
)

type TenantEventBus struct {
    buses map[string]eh.EventBus
    redis string
}

func NewTenantEventBus(redisAddr string) *TenantEventBus {
    return &TenantEventBus{
        buses: make(map[string]eh.EventBus),
        redis: redisAddr,
    }
}

func (b *TenantEventBus) GetBusForTenant(tenantID string) (eh.EventBus, error) {
    if bus, exists := b.buses[tenantID]; exists {
        return bus, nil
    }

    streamKey := fmt.Sprintf("events:%s", tenantID)
    bus, err := redisbus.NewEventBus(
        b.redis,
        redisbus.WithStreamKey(streamKey),
    )
    if err != nil {
        return nil, err
    }

    b.buses[tenantID] = bus
    return bus, nil
}
```

**Testing:**
```go
func TestEventBusPublish(t *testing.T) {
    bus := NewTenantEventBus("localhost:6379")
    tenantBus, _ := bus.GetBusForTenant("test-tenant")

    event := eh.NewEvent(
        "AlertCreated",
        &AlertCreatedEvent{AlertID: uuid.New()},
        time.Now(),
    )

    err := tenantBus.PublishEvent(context.Background(), event)
    require.NoError(t, err)
}
```

---

### Task 4.5: Projector Infrastructure

**Task ID:** P4-EVENTHORIZON-005
**Description:** Build projector system for read model updates
**Priority:** High
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-004

**Acceptance Criteria:**
- [ ] Base projector interface
- [ ] Event subscription mechanism
- [ ] Read model updates working
- [ ] Idempotent event handling

**Implementation:**
```go
// pkg/eventhorizon/projector.go
package eventhorizon

import (
    "context"
    eh "github.com/looplab/eventhorizon/v2"
    "gorm.io/gorm"
)

type Projector interface {
    ProjectorType() string
    Project(ctx context.Context, event eh.Event) error
}

type BaseProjector struct {
    db *gorm.DB
}

// Example: Compliance Alert Projector
type ComplianceAlertProjector struct {
    BaseProjector
}

func (p *ComplianceAlertProjector) ProjectorType() string {
    return "ComplianceAlertProjector"
}

func (p *ComplianceAlertProjector) Project(ctx context.Context, event eh.Event) error {
    switch e := event.Data().(type) {
    case *AlertCreatedEvent:
        return p.onAlertCreated(ctx, e)
    case *AlertAssignedEvent:
        return p.onAlertAssigned(ctx, e)
    case *AlertResolvedEvent:
        return p.onAlertResolved(ctx, e)
    }
    return nil
}

func (p *ComplianceAlertProjector) onAlertCreated(ctx context.Context, event *AlertCreatedEvent) error {
    // Create read model
    alert := &ComplianceAlertReadModel{
        ID:          event.AlertID,
        AlertType:   event.AlertType,
        Severity:    event.Severity,
        Status:      "open",
        Description: event.Description,
        CreatedAt:   time.Now(),
    }

    return p.db.WithContext(ctx).Create(alert).Error
}

func (p *ComplianceAlertProjector) onAlertAssigned(ctx context.Context, event *AlertAssignedEvent) error {
    return p.db.WithContext(ctx).
        Model(&ComplianceAlertReadModel{}).
        Where("id = ?", event.AlertID).
        Updates(map[string]interface{}{
            "assigned_to": event.AssignedTo,
            "status":      "investigating",
            "updated_at":  time.Now(),
        }).Error
}

// Read model (GORM)
type ComplianceAlertReadModel struct {
    ID          uuid.UUID `gorm:"type:uuid;primary_key"`
    AlertType   string
    Severity    string
    Status      string
    Description string
    AssignedTo  string
    ResolvedBy  string
    CreatedAt   time.Time
    UpdatedAt   time.Time
}
```

**Testing:**
```go
func TestProjectorUpdatesReadModel(t *testing.T) {
    db := setupTestDB(t)
    projector := &ComplianceAlertProjector{BaseProjector{db: db}}

    event := &AlertCreatedEvent{
        AlertID:   uuid.New(),
        AlertType: "test",
        Severity:  "high",
    }

    err := projector.onAlertCreated(context.Background(), event)
    require.NoError(t, err)

    var alert ComplianceAlertReadModel
    err = db.First(&alert, "id = ?", event.AlertID).Error
    require.NoError(t, err)
    assert.Equal(t, "open", alert.Status)
}
```

---

### Task 4.6: Command/Event Handler Base Classes

**Task ID:** P4-EVENTHORIZON-006
**Description:** Create reusable command and event handler patterns
**Priority:** Medium
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-005

**Acceptance Criteria:**
- [ ] Command handler interface
- [ ] Event handler interface
- [ ] Handler registration system
- [ ] Middleware support (logging, validation)

**Implementation:**
```go
// pkg/eventhorizon/handlers.go
package eventhorizon

import (
    "context"
    eh "github.com/looplab/eventhorizon/v2"
)

type CommandHandler interface {
    HandleCommand(ctx context.Context, cmd eh.Command) error
}

type EventHandler interface {
    HandleEvent(ctx context.Context, event eh.Event) error
}

// Command handler with middleware
type MiddlewareCommandHandler struct {
    handler    CommandHandler
    middleware []CommandMiddleware
}

type CommandMiddleware func(CommandHandler) CommandHandler

func (h *MiddlewareCommandHandler) HandleCommand(ctx context.Context, cmd eh.Command) error {
    handler := h.handler
    for i := len(h.middleware) - 1; i >= 0; i-- {
        handler = h.middleware[i](handler)
    }
    return handler.HandleCommand(ctx, cmd)
}

// Logging middleware
func LoggingMiddleware(logger *zap.Logger) CommandMiddleware {
    return func(next CommandHandler) CommandHandler {
        return CommandHandlerFunc(func(ctx context.Context, cmd eh.Command) error {
            logger.Info("handling command",
                zap.String("command", fmt.Sprintf("%T", cmd)),
            )
            return next.HandleCommand(ctx, cmd)
        })
    }
}
```

---

### Task 4.7: Integration Testing Setup

**Task ID:** P4-EVENTHORIZON-007
**Description:** Create integration tests for Event Horizon infrastructure
**Priority:** High
**Complexity:** M (4-8h)

**Dependencies:** P4-EVENTHORIZON-006

**Acceptance Criteria:**
- [ ] End-to-end event sourcing test
- [ ] Aggregate reconstitution from events
- [ ] Projection rebuild test
- [ ] Tenant isolation verified

**Testing:**
```go
// pkg/eventhorizon/integration_test.go
func TestEventSourcingEndToEnd(t *testing.T) {
    // Setup
    ctx := context.Background()
    tenantID := "test-tenant"

    store, _ := NewEventStore(ctx, tenantID)
    bus, _ := NewEventBus(tenantID)

    // Create aggregate
    alertID := uuid.New()
    aggregate := &ComplianceAlertAggregate{
        BaseAggregate: BaseAggregate{ID: alertID},
    }

    // Execute commands
    aggregate.HandleCommand(ctx, &CreateAlertCommand{
        AlertType: "test",
        Severity:  "high",
    })
    aggregate.HandleCommand(ctx, &AssignAlertCommand{
        AssignedTo: "officer-123",
    })

    // Save events
    err := store.Save(ctx, aggregate.Events, aggregate.Version)
    require.NoError(t, err)

    // Reconstitute from events
    events, _ := store.Load(ctx, alertID)

    newAggregate := &ComplianceAlertAggregate{
        BaseAggregate: BaseAggregate{ID: alertID},
    }

    for _, event := range events {
        newAggregate.ApplyEvent(ctx, event)
    }

    assert.Equal(t, "investigating", newAggregate.Status)
    assert.Equal(t, "officer-123", newAggregate.AssignedTo)
}
```

---

### Task 4.8: Documentation & Examples

**Task ID:** P4-EVENTHORIZON-008
**Description:** Document Event Horizon usage patterns and examples
**Priority:** Medium
**Complexity:** S (1-3h)

**Dependencies:** P4-EVENTHORIZON-007

**Acceptance Criteria:**
- [ ] README with Event Horizon setup
- [ ] Code examples for common patterns
- [ ] Decision guide (Formance vs Event Horizon)
- [ ] Migration guide from Laravel Event Sourcing

**Documentation:**
```markdown
# Event Horizon Setup

## When to Use Event Horizon

Use Event Horizon for:
- Compliance workflows (alerts, investigations)
- KYC/AML processes (document verification, risk assessment)
- Governance (voting, proposals)
- AI agent decision tracking
- Audit logs requiring replay capability

Use Formance for:
- Account balances
- Payment transactions
- Exchange trades
- Lending repayments
- Treasury movements
- Stablecoin operations

## Example: Creating an Aggregate

\`\`\`go
aggregate := ComplianceAlertAggregate.Create(
    alertType: "suspicious_activity",
    severity: "high",
)
aggregate.Assign("officer-123")
aggregate.Resolve("false_positive", "officer-123")
aggregate.Persist()
\`\`\`

## Event Store Schema

Each tenant gets isolated event tables:
- `events` - Event stream
- `snapshots` - Aggregate snapshots
```

---

## Phase 5: Schema-per-Tenant Middleware

**Duration:** Weeks 13-14 (1.5 weeks)
**Goal:** Implement automatic schema isolation
**Dependencies:** Phase 0

### Tasks Overview (6 tasks, 48 hours)

- **5.1:** Tenant Context Extraction Middleware (X-Tenant-ID, domain)
- **5.2:** PostgreSQL Search Path Middleware (SET search_path)
- **5.3:** Tenant-Scoped Database Connection Pool
- **5.4:** Request-Level Tenant Context Propagation
- **5.5:** Cross-Tenant Query Prevention (circuit breaker)
- **5.6:** Integration Testing (schema isolation verification)

[Detailed tasks to be added]

---

## Phase 6: Account Domain (Cell-Based)

**Duration:** Weeks 15-16 (2 weeks)
**Goal:** Implement Account as logical container with Formance wallet integration
**Dependencies:** Phase 2, Phase 3, Phase 5

### Tasks Overview (8 tasks, 80 hours)

- **6.1:** Account Model & Repository (B2C vs B2B support)
- **6.2:** Account Creation Service (with Kratos user linking)
- **6.3:** Account Member Management (OWNER, ADMIN, MEMBER, VIEWER)
- **6.4:** Account-Wallet Relationship (one-to-many via Formance)
- **6.5:** Account Query Service (list, get, search)
- **6.6:** Account Status Management (active, suspended, closed)
- **6.7:** Account REST API (CRUD + membership)
- **6.8:** Integration Tests (Account + Ory Keto permissions + Formance wallets)

[Detailed tasks to be added]

---

## Phase 7-16: Remaining Domains

[Due to scope, detailed task breakdowns will be provided in subsequent revisions]

### Phase 7: Payment Domain (Formance-Based) - 10 tasks, 100 hours
**Technology:** Formance Ledger + Wallets
**Focus:** Deposits, withdrawals, transfers using Formance APIs

### Phase 8: Compliance & KYC (Event Horizon-Based) - 18 tasks, 220 hours
**Technology:** Event Horizon Event Sourcing
**Focus:** Alert aggregates, KYC verification workflows, AML monitoring with full audit trail

### Phase 9: Exchange (Formance-Based) - 12 tasks, 140 hours
**Technology:** Formance Ledger
**Focus:** Order matching, trade execution, liquidity pools using double-entry ledger

### Phase 10: Treasury (Formance-Based) - 14 tasks, 180 hours
**Technology:** Formance Wallets + Ledger
**Focus:** Portfolio management, cash allocation, yield optimization with multi-asset support

### Phase 11: Lending (Formance-Based) - 10 tasks, 120 hours
**Technology:** Formance Ledger
**Focus:** Loan disbursements, repayments, interest calculation via ledger

### Phase 12: Stablecoin (Formance-Based) - 9 tasks, 110 hours
**Technology:** Formance Ledger
**Focus:** Token minting, burning, transfers with reserve management

### Phase 13: Wallet/Blockchain - 12 tasks, 160 hours
**Technology:** Formance Wallets + Ethereum
**Focus:** Blockchain integration, wallet management, crypto operations

### Phase 14: AI & Agent Coordination (Event Horizon-Based) - 9 tasks, 110 hours
**Technology:** Event Horizon Event Sourcing
**Focus:** AI decision tracking, agent orchestration, conversation audit trails

### Phase 15: CGO & Governance (Event Horizon-Based) - 13 tasks, 170 hours
**Technology:** Event Horizon Event Sourcing
**Focus:** Voting workflows, proposal management, investment rounds with event replay

### Phase 16: Monitoring & Supporting - 13 tasks, 142 hours
**Technology:** OpenTelemetry + Prometheus + Jaeger
**Focus:** Observability, metrics, tracing, alerting

---

## Appendix A: Architecture Patterns

### Pattern 1: Tenant Schema Isolation

```go
// Middleware
func TenantSchemaMiddleware(db *gorm.DB) gin.HandlerFunc {
    return func(c *gin.Context) {
        // Extract tenant from domain or X-Tenant-ID
        tenantDomain := ExtractTenantDomain(c)

        // Lookup tenant in control plane
        tenant, err := tenantService.GetByDomain(c.Request.Context(), tenantDomain)
        if err != nil {
            c.AbortWithStatusJSON(403, gin.H{"error": "invalid tenant"})
            return
        }

        // Set PostgreSQL search_path for this request
        db.Exec(fmt.Sprintf("SET search_path TO %s", tenant.SchemaName))

        // Store tenant context
        c.Set("tenant_id", tenant.ID)
        c.Set("schema_name", tenant.SchemaName)

        c.Next()

        // Reset search_path after request
        db.Exec("RESET search_path")
    }
}
```

### Pattern 2: Vendor-Agnostic Wallet Operations (Hexagonal Architecture)

```go
// ✅ DOMAIN LAYER: Define interface (port)
package domain

type WalletService interface {
    Credit(ctx context.Context, req CreditRequest) (*Transaction, error)
    Debit(ctx context.Context, req DebitRequest) (*Transaction, error)
    GetBalance(ctx context.Context, walletID string) (*Balance, error)
    Transfer(ctx context.Context, req TransferRequest) (*Transaction, error)
}

// Domain types (vendor-agnostic)
type CreditRequest struct {
    WalletID string
    Amount   Money
    Metadata map[string]string
}

type Money struct {
    Amount   decimal.Decimal
    Currency string
}

// ✅ APPLICATION LAYER: Use interface (business logic)
package application

type DepositService struct {
    walletService domain.WalletService  // Interface, not vendor!
    walletRepo    domain.WalletRepository
}

func (s *DepositService) ProcessDeposit(ctx context.Context, cmd DepositCommand) error {
    wallet, err := s.walletRepo.GetByID(ctx, cmd.WalletID)
    if err != nil {
        return err
    }

    // Call through interface (vendor-agnostic!)
    _, err = s.walletService.Credit(ctx, domain.CreditRequest{
        WalletID: wallet.ExternalID,
        Amount: domain.Money{
            Amount:   cmd.Amount,
            Currency: cmd.Currency,
        },
        Metadata: map[string]string{
            "deposit_id": cmd.DepositID.String(),
            "source":     "bank_transfer",
        },
    })

    return err
}

// ✅ INFRASTRUCTURE LAYER: Implement interface (adapter)
package adapters

import formance "github.com/formancehq/formance-sdk-go"  // Only adapters import vendors!

type FormanceWalletAdapter struct {
    client *formance.Client
}

// Implements domain.WalletService interface
func (a *FormanceWalletAdapter) Credit(ctx context.Context, req domain.CreditRequest) (*domain.Transaction, error) {
    // Translate domain request to vendor request
    formanceReq := &formance.CreditRequest{
        WalletID: req.WalletID,
        Amount: &formance.Monetary{
            Asset:  req.Amount.Currency,
            Amount: req.Amount.Amount.IntPart(),
        },
        Metadata: req.Metadata,
    }

    resp, err := a.client.Wallets.Credit(ctx, formanceReq)
    if err != nil {
        return nil, err
    }

    // Translate vendor response to domain response
    return &domain.Transaction{
        ID:       resp.TransactionID,
        WalletID: req.WalletID,
        Amount:   req.Amount,
        Type:     "credit",
    }, nil
}

// ✅ INFRASTRUCTURE: Alternative adapter (can swap!)
package adapters

type TigerBeetleWalletAdapter struct {
    client *tigerbeetle.Client
}

func (a *TigerBeetleWalletAdapter) Credit(ctx context.Context, req domain.CreditRequest) (*domain.Transaction, error) {
    // Different vendor, same interface!
    // Business logic unchanged!
}
```

### Pattern 3: Vendor-Agnostic Authorization (Two-Layer Permissions)

```go
// ✅ DOMAIN LAYER: Define interface (port)
package domain

type AuthorizationProvider interface {
    CheckPermission(ctx context.Context, req PermissionCheckRequest) (bool, error)
    GrantPermission(ctx context.Context, req GrantPermissionRequest) error
    RevokePermission(ctx context.Context, req RevokePermissionRequest) error
    ListPermissions(ctx context.Context, subject string) ([]Permission, error)
}

type PermissionCheckRequest struct {
    Subject  string  // "user:123"
    Resource string  // "wallet:456"
    Action   string  // "debit", "credit", "view"
}

// ✅ APPLICATION LAYER: Use interface
package application

type WalletPermissionService struct {
    authz domain.AuthorizationProvider  // Interface!
}

func (s *WalletPermissionService) CanDebitWallet(ctx context.Context, userID, walletID string) (bool, error) {
    // Layer 1: Check direct wallet permission
    allowed, err := s.authz.CheckPermission(ctx, domain.PermissionCheckRequest{
        Subject:  fmt.Sprintf("user:%s", userID),
        Resource: fmt.Sprintf("wallet:%s", walletID),
        Action:   "debit",
    })
    if err != nil {
        return false, err
    }
    if allowed {
        return true, nil
    }

    // Layer 2: Check account membership (fallback)
    allowed, err = s.authz.CheckPermission(ctx, domain.PermissionCheckRequest{
        Subject:  fmt.Sprintf("user:%s", userID),
        Resource: fmt.Sprintf("wallet:%s", walletID),
        Action:   "account_admin",  // Inherited from parent account
    })

    return allowed, err
}

// ✅ INFRASTRUCTURE: Ory Keto adapter
package adapters

import keto "github.com/ory/keto-client-go"

type OryKetoAuthzAdapter struct {
    client *keto.APIClient
}

func (a *OryKetoAuthzAdapter) CheckPermission(ctx context.Context, req domain.PermissionCheckRequest) (bool, error) {
    // Translate to Keto API
    result, _, err := a.client.PermissionApi.CheckPermission(ctx).
        Namespace("finaegis").
        Object(req.Resource).
        Relation(req.Action).
        SubjectId(req.Subject).
        Execute()

    if err != nil {
        return false, err
    }

    return result.Allowed, nil
}

// ✅ INFRASTRUCTURE: Alternative Casbin adapter
package adapters

import "github.com/casbin/casbin/v2"

type CasbinAuthzAdapter struct {
    enforcer *casbin.Enforcer
}

func (a *CasbinAuthzAdapter) CheckPermission(ctx context.Context, req domain.PermissionCheckRequest) (bool, error) {
    // Different vendor, same interface!
    return a.enforcer.Enforce(req.Subject, req.Resource, req.Action)
}

// ✅ INFRASTRUCTURE: In-memory mock for testing
package adapters

type InMemoryAuthzAdapter struct {
    permissions map[string]bool
}

func (a *InMemoryAuthzAdapter) CheckPermission(ctx context.Context, req domain.PermissionCheckRequest) (bool, error) {
    key := fmt.Sprintf("%s:%s:%s", req.Subject, req.Resource, req.Action)
    return a.permissions[key], nil
}
```

### Pattern 4: Event Horizon Compliance Workflow

```go
// Compliance Alert Aggregate (Event Sourcing)
func (s *ComplianceService) CreateAlert(ctx context.Context, cmd CreateAlertCommand) error {
    // Create aggregate
    aggregate := &ComplianceAlertAggregate{
        BaseAggregate: BaseAggregate{
            ID: uuid.New(),
        },
    }

    // Handle command (records events)
    if err := aggregate.HandleCommand(ctx, &cmd); err != nil {
        return err
    }

    // Persist events to event store
    events := aggregate.UncommittedEvents()
    if err := s.eventStore.Save(ctx, aggregate.ID, events); err != nil {
        return err
    }

    // Publish events to event bus
    for _, event := range events {
        if err := s.eventBus.Publish(ctx, event); err != nil {
            return err
        }
    }

    return nil
}

// Projector listens to events and updates read model
func (p *ComplianceAlertProjector) HandleEvent(ctx context.Context, event eh.Event) error {
    switch e := event.Data().(type) {
    case *AlertCreatedEvent:
        // Create read model for queries
        alert := &ComplianceAlertReadModel{
            ID:          e.AlertID,
            AlertType:   e.AlertType,
            Severity:    e.Severity,
            Status:      "open",
            Description: e.Description,
            CreatedAt:   event.Timestamp(),
        }
        return p.db.Create(alert).Error

    case *AlertAssignedEvent:
        // Update read model
        return p.db.Model(&ComplianceAlertReadModel{}).
            Where("id = ?", e.AlertID).
            Updates(map[string]interface{}{
                "assigned_to": e.AssignedTo,
                "status":      "investigating",
            }).Error
    }

    return nil
}

// Query read model (CQRS)
func (q *ComplianceQueryService) GetOpenAlerts(ctx context.Context) ([]*ComplianceAlertReadModel, error) {
    var alerts []*ComplianceAlertReadModel
    err := q.db.WithContext(ctx).
        Where("status = ?", "open").
        Order("severity DESC, created_at DESC").
        Find(&alerts).Error
    return alerts, err
}

// Replay events to rebuild projections
func (s *ComplianceService) RebuildProjections(ctx context.Context) error {
    // Get all events
    events, err := s.eventStore.LoadAll(ctx, ComplianceAlertAggregateType)
    if err != nil {
        return err
    }

    // Clear existing read models
    s.db.Exec("TRUNCATE compliance_alert_read_models")

    // Replay all events through projector
    for _, event := range events {
        if err := s.projector.HandleEvent(ctx, event); err != nil {
            return err
        }
    }

    return nil
}
```

### Pattern 5: Hybrid Pattern (Formance + Event Horizon)

```go
// Transfer money (Formance) + Create compliance audit trail (Event Horizon)
func (s *PaymentService) ExecuteTransfer(ctx context.Context, cmd TransferCommand) error {
    // 1. Validate with Event Horizon compliance aggregate
    complianceCheck := ComplianceCheckAggregate.Create(
        transactionType: "transfer",
        amount:          cmd.Amount,
        fromWalletID:    cmd.FromWalletID,
        toWalletID:      cmd.ToWalletID,
    )

    if err := complianceCheck.ValidateRiskThresholds(ctx); err != nil {
        return fmt.Errorf("compliance check failed: %w", err)
    }

    // 2. Execute financial transfer via Formance
    transfer, err := s.formanceClient.Transfers.Create(ctx, &formance.TransferRequest{
        SourceWalletID: cmd.FromWalletID,
        DestWalletID:   cmd.ToWalletID,
        Amount: &formance.Monetary{
            Asset:  cmd.Currency,
            Amount: cmd.Amount.IntPart(),
        },
        Metadata: map[string]string{
            "transfer_id":        cmd.TransferID.String(),
            "compliance_check":   complianceCheck.ID.String(),
            "initiated_by":       cmd.UserID.String(),
        },
    })
    if err != nil {
        // Record failure in Event Horizon
        complianceCheck.RecordTransferFailure(err.Error())
        complianceCheck.Persist(ctx)
        return err
    }

    // 3. Create audit log via Event Horizon (for compliance replay)
    auditLog := NewAuditLogAggregate(uuid.New())
    auditLog.RecordTransfer(TransferRecordedEvent{
        TransferID:         cmd.TransferID,
        FormanceTransferID: transfer.ID,
        FromWalletID:       cmd.FromWalletID,
        ToWalletID:         cmd.ToWalletID,
        Amount:             cmd.Amount,
        Currency:           cmd.Currency,
        InitiatedBy:        cmd.UserID,
        ApprovedBy:         cmd.ApproverID,
        ComplianceCheckID:  complianceCheck.ID,
        ComplianceNote:     "Transfer approved - risk score: low",
        Timestamp:          time.Now(),
    })

    if err := s.auditEventStore.Save(ctx, auditLog); err != nil {
        // Transfer succeeded in Formance but audit failed - log for reconciliation
        s.logger.Error("audit log creation failed",
            zap.String("transfer_id", transfer.ID),
            zap.Error(err),
        )
    }

    // 4. Record successful compliance check
    complianceCheck.RecordTransferSuccess(transfer.ID)
    complianceCheck.Persist(ctx)

    return nil
}

// Query: Combine Formance balance with Event Horizon compliance status
func (q *AccountQueryService) GetAccountSummary(ctx context.Context, accountID uuid.UUID) (*AccountSummary, error) {
    // Get account from PostgreSQL
    account, err := q.accountRepo.GetByID(ctx, accountID)
    if err != nil {
        return nil, err
    }

    // Get wallet balances from Formance
    wallets, err := q.getWalletBalances(ctx, account.Wallets)
    if err != nil {
        return nil, err
    }

    // Get compliance status from Event Horizon read model
    complianceStatus, err := q.complianceRepo.GetAccountStatus(ctx, accountID)
    if err != nil {
        return nil, err
    }

    return &AccountSummary{
        Account:          account,
        Wallets:          wallets,              // From Formance
        TotalBalance:     calculateTotal(wallets),
        ComplianceStatus: complianceStatus,     // From Event Horizon
        RiskScore:        complianceStatus.RiskScore,
        KYCStatus:        complianceStatus.KYCStatus,
    }, nil
}
```

### Pattern 6: Dependency Injection & Adapter Wiring

```go
// ✅ Configuration-based adapter selection
package main

import (
    "github.com/finaegis/core/internal/domain"
    "github.com/finaegis/core/internal/infrastructure/adapters"
)

type Config struct {
    WalletProvider   string  // "formance", "tigerbeetle", "inmemory"
    AuthzProvider    string  // "ory-keto", "casbin", "inmemory"
    LedgerProvider   string  // "formance", "custom"
    IdentityProvider string  // "ory-kratos", "auth0", "keycloak"
}

// Container wires dependencies
type Container struct {
    walletService   domain.WalletService
    authzProvider   domain.AuthorizationProvider
    ledgerService   domain.LedgerService
    identityService domain.IdentityProvider
}

func NewContainer(cfg Config) *Container {
    c := &Container{}

    // Wire wallet service based on config
    switch cfg.WalletProvider {
    case "formance":
        c.walletService = adapters.NewFormanceWalletAdapter(cfg.FormanceAPIKey)
    case "tigerbeetle":
        c.walletService = adapters.NewTigerBeetleAdapter(cfg.TigerBeetleURL)
    case "inmemory":
        c.walletService = adapters.NewInMemoryWalletAdapter()
    default:
        panic("unknown wallet provider: " + cfg.WalletProvider)
    }

    // Wire authorization provider
    switch cfg.AuthzProvider {
    case "ory-keto":
        c.authzProvider = adapters.NewOryKetoAdapter(cfg.KetoURL)
    case "casbin":
        c.authzProvider = adapters.NewCasbinAdapter(cfg.CasbinModel)
    case "inmemory":
        c.authzProvider = adapters.NewInMemoryAuthzAdapter()
    }

    // Wire ledger service
    switch cfg.LedgerProvider {
    case "formance":
        c.ledgerService = adapters.NewFormanceLedgerAdapter(cfg.FormanceAPIKey)
    case "custom":
        c.ledgerService = adapters.NewCustomLedgerAdapter()
    }

    // Wire identity provider
    switch cfg.IdentityProvider {
    case "ory-kratos":
        c.identityService = adapters.NewOryKratosAdapter(cfg.KratosURL)
    case "auth0":
        c.identityService = adapters.NewAuth0Adapter(cfg.Auth0Domain)
    case "keycloak":
        c.identityService = adapters.NewKeycloakAdapter(cfg.KeycloakURL)
    }

    return c
}

// Application services receive interfaces
func (c *Container) NewPaymentService() *application.PaymentService {
    return &application.PaymentService{
        walletService: c.walletService,   // Injected!
        ledgerService: c.ledgerService,   // Injected!
        authz:         c.authzProvider,   // Injected!
    }
}

// ✅ Environment-specific configuration
// .env.development
WALLET_PROVIDER=inmemory
AUTHZ_PROVIDER=inmemory
LEDGER_PROVIDER=inmemory

// .env.staging
WALLET_PROVIDER=formance
AUTHZ_PROVIDER=ory-keto
LEDGER_PROVIDER=formance

// .env.production
WALLET_PROVIDER=formance
AUTHZ_PROVIDER=ory-keto
LEDGER_PROVIDER=formance

// ✅ Testing with mocks (no external dependencies!)
package application_test

func TestPaymentService_ProcessDeposit(t *testing.T) {
    // Use in-memory adapters for testing!
    mockWallet := adapters.NewInMemoryWalletAdapter()
    mockAuthz := adapters.NewInMemoryAuthzAdapter()

    service := &application.PaymentService{
        walletService: mockWallet,
        authz:         mockAuthz,
    }

    // Test business logic without external services!
    err := service.ProcessDeposit(ctx, cmd)
    assert.NoError(t, err)
}
```

### Pattern 7: Folder Structure (Hexagonal Architecture)

```
finaegis-go/
├── internal/
│   ├── domain/                    # ✅ CORE: Pure business logic
│   │   ├── account/
│   │   │   ├── aggregate/        # Entities, aggregates
│   │   │   ├── valueobject/      # Value objects
│   │   │   ├── service/          # Domain services
│   │   │   └── ports/            # 🔌 INTERFACES (defined by domain!)
│   │   │       ├── wallet.go     # type WalletService interface
│   │   │       ├── ledger.go     # type LedgerService interface
│   │   │       ├── authz.go      # type AuthorizationProvider interface
│   │   │       └── identity.go   # type IdentityProvider interface
│   │   ├── payment/
│   │   │   └── ports/
│   │   │       └── payment_gateway.go
│   │   └── shared/
│   │       └── ports/            # Shared interfaces
│   │           ├── event_store.go
│   │           ├── event_bus.go
│   │           └── repository.go
│   │
│   ├── application/              # ✅ USE CASES: Orchestration
│   │   ├── payment/
│   │   │   ├── deposit_service.go      # Uses domain.WalletService interface
│   │   │   ├── withdraw_service.go     # Uses domain.WalletService interface
│   │   │   └── transfer_service.go     # Uses domain.LedgerService interface
│   │   └── account/
│   │       └── account_service.go      # Uses domain.AuthorizationProvider
│   │
│   └── infrastructure/           # ✅ ADAPTERS: Implementations
│       ├── adapters/             # 🔌 Concrete implementations
│       │   ├── wallet/
│       │   │   ├── formance_wallet_adapter.go      # implements domain.WalletService
│       │   │   ├── tigerbeetle_wallet_adapter.go   # implements domain.WalletService
│       │   │   └── inmemory_wallet_adapter.go      # implements domain.WalletService
│       │   ├── ledger/
│       │   │   ├── formance_ledger_adapter.go      # implements domain.LedgerService
│       │   │   ├── custom_ledger_adapter.go        # implements domain.LedgerService
│       │   │   └── inmemory_ledger_adapter.go
│       │   ├── authz/
│       │   │   ├── ory_keto_adapter.go             # implements domain.AuthorizationProvider
│       │   │   ├── casbin_adapter.go               # implements domain.AuthorizationProvider
│       │   │   ├── opa_adapter.go                  # implements domain.AuthorizationProvider
│       │   │   └── inmemory_authz_adapter.go
│       │   ├── identity/
│       │   │   ├── ory_kratos_adapter.go           # implements domain.IdentityProvider
│       │   │   ├── auth0_adapter.go                # implements domain.IdentityProvider
│       │   │   ├── keycloak_adapter.go             # implements domain.IdentityProvider
│       │   │   └── inmemory_identity_adapter.go
│       │   ├── eventstore/
│       │   │   ├── eventhorizon_adapter.go         # implements domain.EventStore
│       │   │   ├── eventstoredb_adapter.go         # implements domain.EventStore
│       │   │   └── postgres_eventstore_adapter.go
│       │   └── gateway/
│       │       ├── ory_oathkeeper_adapter.go       # implements domain.APIGateway
│       │       ├── kong_adapter.go                 # implements domain.APIGateway
│       │       └── envoy_adapter.go
│       ├── persistence/          # Database repositories
│       ├── http/                 # HTTP handlers
│       └── config/               # DI container, wiring
│           └── container.go      # Adapter selection logic
│
├── cmd/
│   └── api-server/
│       └── main.go               # Wires adapters based on env config
│
└── test/
    └── adapters/                 # In-memory test adapters
        ├── mock_wallet_adapter.go
        ├── mock_authz_adapter.go
        └── mock_ledger_adapter.go
```

**Key Rules:**
1. ✅ `internal/domain/**/ports/` = Interfaces defined BY domain (NOT by infrastructure!)
2. ✅ `internal/infrastructure/adapters/` = Vendor-specific implementations
3. ❌ Domain layer NEVER imports `github.com/formancehq/*` or `github.com/ory/*`
4. ❌ Domain layer NEVER imports `internal/infrastructure/*`
5. ✅ Infrastructure imports domain to implement interfaces
6. ✅ Application layer injects adapters via constructor
7. ✅ `cmd/main.go` wires adapters based on environment config

---

## Appendix B: Migration Checklist

### Before Starting

- [ ] Review architectural analysis (ARCHITECTURE_MIGRATION_ANALYSIS.md)
- [ ] Understand hybrid approach (Formance vs Event Horizon decision matrix)
- [ ] Set up Ory stack locally (Docker Compose)
- [ ] Set up Formance stack locally
- [ ] Set up Event Horizon with PostgreSQL event store
- [ ] Configure PostgreSQL multi-schema
- [ ] Review .cursorrules for Cell-Based + Hybrid patterns

### Per-Phase Checklist

- [ ] Read phase overview and dependencies
- [ ] Complete all tasks in sequential order
- [ ] Run tests after each task
- [ ] Verify integration with Ory/Formance
- [ ] Update .ai-context.md with progress

### Per-Task Checklist

- [ ] Write tests FIRST (TDD)
- [ ] Implement minimal code
- [ ] Verify schema isolation (if tenant-scoped)
- [ ] Verify Formance integration (if financial domain)
- [ ] Verify Event Horizon integration (if non-financial domain)
- [ ] Verify Ory integration (if auth/authz-related)
- [ ] Run all tests
- [ ] Check coverage (>80%)
- [ ] Commit with conventional message

### Decision Matrix: Formance vs Event Horizon

**Use Formance if:**
- Financial transaction (balance changes)
- Money movement (deposits, withdrawals, transfers)
- Multi-asset balances required
- Regulatory financial audit trail needed
- Double-entry accounting required

**Use Event Horizon if:**
- Workflow with complex state machine
- Compliance investigation requiring replay
- Governance/voting process
- AI decision tracking
- Audit trail for non-financial operations
- Event replay capability required

**Use Both (Hybrid) if:**
- Financial operation with compliance workflow
- Payment with KYC verification
- Transfer with fraud detection

---

## Status: Hybrid Architecture Defined

**Next Steps:**
1. Complete detailed task breakdowns for Phases 2-16
2. Update .cursorrules with hybrid patterns (Ory/Formance/Event Horizon)
3. Create Temporal workflow examples
4. Add integration test examples for hybrid scenarios

**Document Version:** 2.0 (Hybrid: Cell-Based + Formance + Event Horizon)
**Last Updated:** 2026-01-02
**Status:** IN PROGRESS - Hybrid architecture defined, Phase 4 (Event Horizon) detailed
