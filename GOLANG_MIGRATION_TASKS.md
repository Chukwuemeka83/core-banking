# FinAegis Golang Migration - Cell-Based Multi-Tenant Architecture

> **Complete source of truth for PHP/Laravel to Golang migration**
>
> **Architecture:** Cell-Based (Shared-Nothing) + Ory Stack + Formance
>
> 174 comprehensive, AI-agent-executable atomic tasks covering 15 domains

---

## 🏗️ Architectural Overview

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

### **Technology Stack**

| Component | Solution | Scope |
|-----------|----------|-------|
| **Identity** | Ory Kratos | Tenant-scoped (per-realm authentication) |
| **Authorization** | Ory Keto | Global service with tenant namespaces (ReBAC) |
| **Gateway/Router** | Ory Oathkeeper | Global (routes by domain to tenant silos) |
| **Asset Engine** | Formance Wallets | Tenant-scoped (multi-asset balance management) |
| **Immutable Ledger** | Formance Ledger | Tenant-scoped (double-entry transaction log) |
| **Workflows** | Temporal | Global + Per-Tenant queues (sagas, provisioning) |
| **Database** | PostgreSQL 16 | Schema-per-tenant (physical isolation) |
| **Cache** | Redis 7 | Tenant-scoped (namespace per tenant) |
| **Observability** | OpenTelemetry + Jaeger + Prometheus | Global with tenant context |

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

**Total Tasks:** 174
**Total Estimated Hours:** 2,180 hours (~55 weeks)
**Completion Status:** 0% (Architecture redesigned - ready to implement)
**Last Updated:** 2026-01-01

### Phase Summary

| Phase | Domain | Tasks | Hours | Weeks |
|-------|--------|-------|-------|-------|
| 0 | Infrastructure & Ory/Formance Setup | 10 | 96 | 2.5 |
| 1 | Control Plane (Tenant Provisioning) | 8 | 84 | 2 |
| 2 | Ory Stack Integration | 12 | 120 | 3 |
| 3 | Formance Integration | 10 | 100 | 2.5 |
| 4 | Schema-per-Tenant Middleware | 6 | 48 | 1.5 |
| 5 | Account Domain (Cell-Based) | 8 | 80 | 2 |
| 6 | Payment Domain (Formance-Based) | 10 | 100 | 2.5 |
| 7 | Compliance & KYC | 18 | 220 | 5.5 |
| 8 | Exchange (Formance-Based) | 12 | 140 | 3.5 |
| 9 | Treasury (Formance-Based) | 14 | 180 | 4.5 |
| 10 | Lending (Formance-Based) | 10 | 120 | 3 |
| 11 | Stablecoin (Formance-Based) | 9 | 110 | 3 |
| 12 | Wallet/Blockchain | 12 | 160 | 4 |
| 13 | AI & Agent Coordination | 9 | 110 | 3 |
| 14 | CGO & Governance | 13 | 170 | 4.5 |
| 15 | Monitoring & Supporting | 13 | 142 | 3.5 |
| **TOTAL** | **All Domains** | **174** | **2,180** | **~55** |

---

## 🚨 Critical Directives

> **MUST FOLLOW:**
>
> 1. **Strict Plane Separation:** Control Plane NEVER accesses Tenant Plane data
> 2. **Schema Isolation:** Middleware MUST set `search_path` per request
> 3. **No Custom Auth:** Use Ory Kratos UUIDs as FK (NO password storage)
> 4. **No Custom Wallets:** Use Formance Wallets API (NO balance in Postgres)
> 5. **Formance as Source of Truth:** PostgreSQL stores mappings ONLY
> 6. **Ory Keto for Permissions:** Implement two-layer fallback strategy
> 7. **Tenant Provisioning via Temporal:** Atomic workflow with compensation
> 8. **All Entities Tenant-Scoped:** No global user/wallet tables

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

## Phase 4: Schema-per-Tenant Middleware

**Duration:** Week 11 (1.5 weeks)
**Goal:** Implement automatic schema isolation
**Dependencies:** Phase 0

### Tasks Overview (6 tasks, 48 hours)

- **4.1:** Tenant Context Extraction Middleware (X-Tenant-ID, domain)
- **4.2:** PostgreSQL Search Path Middleware (SET search_path)
- **4.3:** Tenant-Scoped Database Connection Pool
- **4.4:** Request-Level Tenant Context Propagation
- **4.5:** Cross-Tenant Query Prevention (circuit breaker)
- **4.6:** Integration Testing (schema isolation verification)

[Detailed tasks to be added]

---

## Phase 5: Account Domain (Cell-Based)

**Duration:** Weeks 12-13 (2 weeks)
**Goal:** Implement Account as logical container
**Dependencies:** Phase 2, Phase 3, Phase 4

### Tasks Overview (8 tasks, 80 hours)

- **5.1:** Account Model & Repository (B2C vs B2B support)
- **5.2:** Account Creation Service (with Kratos user linking)
- **5.3:** Account Member Management (OWNER, ADMIN, MEMBER, VIEWER)
- **5.4:** Account-Wallet Relationship (one-to-many)
- **5.5:** Account Query Service (list, get, search)
- **5.6:** Account Status Management (active, suspended, closed)
- **5.7:** Account REST API (CRUD + membership)
- **5.8:** Integration Tests (Account + Ory Keto permissions)

[Detailed tasks to be added]

---

## Phase 6-15: Remaining Domains

[Due to scope, detailed task breakdowns will be provided in subsequent revisions]

### Phase 6: Payment Domain (Formance-Based) - 10 tasks
### Phase 7: Compliance & KYC - 18 tasks
### Phase 8: Exchange (Formance-Based) - 12 tasks
### Phase 9: Treasury (Formance-Based) - 14 tasks
### Phase 10: Lending (Formance-Based) - 10 tasks
### Phase 11: Stablecoin (Formance-Based) - 9 tasks
### Phase 12: Wallet/Blockchain - 12 tasks
### Phase 13: AI & Agent Coordination - 9 tasks
### Phase 14: CGO & Governance - 13 tasks
### Phase 15: Monitoring & Supporting - 13 tasks

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

### Pattern 2: Formance Wallet Operations

```go
// Deposit to wallet
func (s *WalletService) Deposit(ctx context.Context, walletID uuid.UUID, amount decimal.Decimal, currency string) error {
    // Get wallet mapping
    wallet, err := s.repo.GetWallet(ctx, walletID)
    if err != nil {
        return err
    }

    // Call Formance Wallets API
    _, err = s.formanceClient.Wallets.Credit(ctx, &formance.CreditRequest{
        WalletID: wallet.FormanceWalletID,
        Amount: &formance.Monetary{
            Asset: currency,
            Amount: amount.IntPart(), // Convert to smallest unit
        },
        Metadata: map[string]string{
            "internal_wallet_id": walletID.String(),
            "operation": "deposit",
        },
    })

    return err
}
```

### Pattern 3: Ory Keto Two-Layer Permission Check

```go
func (s *PermissionService) CanDebitWallet(ctx context.Context, userID, walletID string) (bool, error) {
    // Layer 1: Check direct wallet permission
    allowed, err := s.ketoClient.Check(ctx, &keto.CheckRequest{
        Namespace: "wallets",
        Object: walletID,
        Relation: "can_debit",
        Subject: fmt.Sprintf("user:%s", userID),
    })
    if err != nil {
        return false, err
    }
    if allowed {
        return true, nil // Explicit permission
    }

    // Layer 2: Check account membership
    // Get parent account
    walletParent, _ := s.ketoClient.ListObjects(ctx, &keto.ListRequest{
        Namespace: "wallets",
        Object: walletID,
        Relation: "parent",
    })

    if len(walletParent) == 0 {
        return false, nil
    }

    accountID := walletParent[0]

    // Check if user is admin of account
    return s.ketoClient.Check(ctx, &keto.CheckRequest{
        Namespace: "accounts",
        Object: accountID,
        Relation: "admin",
        Subject: fmt.Sprintf("user:%s", userID),
    })
}
```

---

## Appendix B: Migration Checklist

### Before Starting

- [ ] Review architectural analysis (ARCHITECTURE_MIGRATION_ANALYSIS.md)
- [ ] Set up Ory stack locally (Docker Compose)
- [ ] Set up Formance stack locally
- [ ] Configure PostgreSQL multi-schema
- [ ] Review .cursorrules for Cell-Based patterns

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
- [ ] Verify Formance integration (if wallet-related)
- [ ] Verify Ory integration (if auth/authz-related)
- [ ] Run all tests
- [ ] Check coverage (>80%)
- [ ] Commit with conventional message

---

## Status: Phase 1 - Foundation Complete

**Next Steps:**
1. Complete detailed task breakdowns for Phases 2-15
2. Update .cursorrules with Ory/Formance patterns
3. Create Temporal workflow examples
4. Add integration test examples

**Document Version:** 1.0 (Cell-Based Architecture)
**Last Updated:** 2026-01-01
**Status:** IN PROGRESS - Core phases detailed, remaining phases outlined
