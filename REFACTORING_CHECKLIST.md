# Refactoring Checklist - Phase 0 & Phase 1 to Hexagonal Architecture

> **Quick Reference:** Step-by-step checklist for converting existing code to vendor-agnostic architecture
>
> **Use this for:** Each refactoring task from REFACTORING_TASKS.md
> **Status Tracking:** Check off items as you complete them

---

## 📋 Pre-Refactoring Setup (One-Time)

### Initial Setup
- [ ] Read REFACTORING_TASKS.md completely
- [ ] Read .cursorrules-refactoring completely
- [ ] Understand current Phase 0 & Phase 1 implementation
- [ ] Create refactoring branch: `git checkout -b refactor/phase-0-1-hexagonal`

### Directory Structure Setup
```bash
# Run this once to create all directories
./scripts/refactoring/refactor-to-hexagonal.sh create-structure
```

- [ ] Verify `internal/domain/shared/ports/` exists
- [ ] Verify `internal/domain/account/ports/` exists
- [ ] Verify `internal/infrastructure/adapters/` structure exists

### Generate DI Container (One-Time)
```bash
./scripts/refactoring/refactor-to-hexagonal.sh generate-container
```

- [ ] Verify `internal/infrastructure/config/container.go` exists
- [ ] Verify `internal/infrastructure/config/config.go` exists

---

## 🔄 Per-Task Refactoring Workflow

**Use this checklist for EACH task (e.g., R0.2.1, R1.1.1, etc.)**

### Phase 1: Analysis & Planning

#### 1. Read Existing Code
- [ ] Identify the service/component to refactor
- [ ] Read all source files thoroughly
- [ ] Identify all vendor dependencies (Formance, Ory, GORM, Redis, etc.)
- [ ] Document current behavior

**Commands:**
```bash
# Find vendor usages
./scripts/refactoring/refactor-to-hexagonal.sh find-usages

# Example: Analyze AccountService
cat internal/application/service/account_service.go

# Find Formance calls
grep -n "formanceClient" internal/application/service/account_service.go
```

#### 2. Define Interface Scope
- [ ] List ALL methods currently used from vendor
- [ ] Document method signatures
- [ ] Identify return types
- [ ] **DO NOT** add methods not currently used

**Example Documentation:**
```
AccountService uses Formance Wallets:
✅ Credit(walletID, amount, currency) → transaction
✅ Debit(walletID, amount, currency) → transaction
✅ GetBalance(walletID) → balance

NOT used yet (don't add to interface):
❌ Transfer()
❌ CreateWallet()
❌ GetHistory()
```

#### 3. Ensure Tests Pass (Baseline)
- [ ] Run existing tests
- [ ] Document test coverage
- [ ] Note any failing tests (fix later)

```bash
# Run tests for the service
go test ./internal/application/service/...

# Check coverage
go test -cover ./internal/application/service/...
```

---

### Phase 2: Create Port Interface

#### 4. Create Port Interface
- [ ] Create port file in correct domain: `internal/domain/{domain}/ports/{service}.go`
- [ ] Define interface with ONLY methods currently used
- [ ] Define domain types (vendor-agnostic value objects)
- [ ] Add comprehensive documentation

**Template:**
```bash
# Generate port template
./scripts/refactoring/refactor-to-hexagonal.sh generate-port account WalletService
```

**Manual Creation:**
```go
// internal/domain/account/ports/wallet.go
package ports

import (
    "context"
    "time"
    "github.com/shopspring/decimal"
)

// WalletService defines wallet operations interface
// This interface is defined BY domain, implemented BY infrastructure
type WalletService interface {
    Credit(ctx context.Context, req CreditRequest) (*WalletTransaction, error)
    Debit(ctx context.Context, req DebitRequest) (*WalletTransaction, error)
    GetBalance(ctx context.Context, walletID string) (*Balance, error)
}

// Domain types (vendor-agnostic)
type CreditRequest struct {
    WalletID  string
    Amount    Money
    Reference string
    Metadata  map[string]string
}

type Money struct {
    Amount   decimal.Decimal
    Currency string
}

type WalletTransaction struct {
    ID        string
    WalletID  string
    Type      TransactionType
    Amount    Money
    Balance   Money
    Reference string
    Metadata  map[string]string
    CreatedAt time.Time
}

// ... other types
```

**Checklist:**
- [ ] Interface methods match current usage
- [ ] Domain types are vendor-agnostic
- [ ] No vendor package imports
- [ ] Comprehensive documentation

---

### Phase 3: Create In-Memory Adapter (Testing First!)

#### 5. Create In-Memory Adapter
- [ ] Create adapter file: `internal/infrastructure/adapters/{type}/inmemory_{service}_adapter.go`
- [ ] Implement ALL interface methods
- [ ] Use maps/slices for in-memory storage
- [ ] Add mutex for thread safety
- [ ] Test the adapter independently

**Template:**
```bash
./scripts/refactoring/refactor-to-hexagonal.sh generate-adapter wallet InMemoryWallet
```

**Manual Creation:**
```go
// internal/infrastructure/adapters/wallet/inmemory_wallet_adapter.go
package wallet

import (
    "context"
    "fmt"
    "sync"
    "time"

    "github.com/google/uuid"
    "github.com/mstfajbr/finaegis-go/internal/domain/account/ports"
)

type InMemoryWalletAdapter struct {
    wallets      map[string]*WalletState
    transactions map[string]*ports.WalletTransaction
    mu           sync.RWMutex
}

type WalletState struct {
    ID       string
    Balance  ports.Money
    Metadata map[string]string
}

func NewInMemoryWalletAdapter() *InMemoryWalletAdapter {
    return &InMemoryWalletAdapter{
        wallets:      make(map[string]*WalletState),
        transactions: make(map[string]*ports.WalletTransaction),
    }
}

func (a *InMemoryWalletAdapter) Credit(ctx context.Context, req ports.CreditRequest) (*ports.WalletTransaction, error) {
    a.mu.Lock()
    defer a.mu.Unlock()

    wallet, exists := a.wallets[req.WalletID]
    if !exists {
        return nil, fmt.Errorf("wallet not found: %s", req.WalletID)
    }

    if wallet.Balance.Currency != req.Amount.Currency {
        return nil, fmt.Errorf("currency mismatch")
    }

    // Update balance
    wallet.Balance.Amount = wallet.Balance.Amount.Add(req.Amount.Amount)

    // Create transaction
    tx := &ports.WalletTransaction{
        ID:        uuid.New().String(),
        WalletID:  req.WalletID,
        Type:      ports.TransactionTypeCredit,
        Amount:    req.Amount,
        Balance:   wallet.Balance,
        Reference: req.Reference,
        Metadata:  req.Metadata,
        CreatedAt: time.Now(),
    }

    a.transactions[tx.ID] = tx

    return tx, nil
}

// Helper method for testing
func (a *InMemoryWalletAdapter) CreateWallet(ctx context.Context, req ports.CreateWalletRequest) error {
    a.mu.Lock()
    defer a.mu.Unlock()

    a.wallets[req.ID] = &WalletState{
        ID: req.ID,
        Balance: ports.Money{
            Amount:   decimal.Zero,
            Currency: req.Currency,
        },
        Metadata: req.Metadata,
    }
    return nil
}

// Implement other methods...
```

**Checklist:**
- [ ] All interface methods implemented
- [ ] Thread-safe (uses mutex)
- [ ] Simple in-memory storage (maps/slices)
- [ ] No external dependencies
- [ ] Helper methods for test setup

#### 6. Test In-Memory Adapter
- [ ] Write unit tests for in-memory adapter
- [ ] Test all interface methods
- [ ] Test error cases
- [ ] Verify thread safety

```go
// internal/infrastructure/adapters/wallet/inmemory_wallet_adapter_test.go
func TestInMemoryWalletAdapter_Credit(t *testing.T) {
    adapter := NewInMemoryWalletAdapter()

    // Setup: Create wallet
    walletID := uuid.New().String()
    err := adapter.CreateWallet(context.Background(), ports.CreateWalletRequest{
        ID:       walletID,
        Currency: "USD",
    })
    require.NoError(t, err)

    // Act: Credit wallet
    tx, err := adapter.Credit(context.Background(), ports.CreditRequest{
        WalletID: walletID,
        Amount: ports.Money{
            Amount:   decimal.NewFromInt(100),
            Currency: "USD",
        },
        Reference: "TEST-001",
    })

    // Assert
    require.NoError(t, err)
    assert.Equal(t, walletID, tx.WalletID)
    assert.Equal(t, decimal.NewFromInt(100), tx.Balance.Amount)

    // Verify balance
    balance, err := adapter.GetBalance(context.Background(), walletID)
    require.NoError(t, err)
    assert.Equal(t, decimal.NewFromInt(100), balance.Available.Amount)
}
```

**Checklist:**
- [ ] Tests pass: `go test ./internal/infrastructure/adapters/wallet/...`
- [ ] Coverage > 80%
- [ ] All methods tested
- [ ] Error cases tested

---

### Phase 4: Create Production Adapter

#### 7. Create Production Adapter (e.g., Formance)
- [ ] Create adapter file: `internal/infrastructure/adapters/{type}/formance_{service}_adapter.go`
- [ ] Import vendor SDK (ONLY in this file!)
- [ ] Implement translation logic (domain ↔ vendor)
- [ ] Handle vendor-specific errors
- [ ] Add logging

**Template:**
```bash
./scripts/refactoring/refactor-to-hexagonal.sh generate-adapter wallet FormanceWallet
```

**Manual Creation:**
```go
// internal/infrastructure/adapters/wallet/formance_wallet_adapter.go
package wallet

import (
    "context"
    "fmt"

    formance "github.com/formancehq/formance-sdk-go"
    "github.com/mstfajbr/finaegis-go/internal/domain/account/ports"
    "github.com/shopspring/decimal"
)

type FormanceWalletAdapter struct {
    client *formance.Client
}

func NewFormanceWalletAdapter(apiKey string, baseURL string) *FormanceWalletAdapter {
    client := formance.NewClient(formance.Config{
        APIKey:  apiKey,
        BaseURL: baseURL,
    })
    return &FormanceWalletAdapter{client: client}
}

func (a *FormanceWalletAdapter) Credit(ctx context.Context, req ports.CreditRequest) (*ports.WalletTransaction, error) {
    // 1. Translate domain request → vendor request
    formanceReq := &formance.CreditRequest{
        WalletID: req.WalletID,
        Amount: &formance.Monetary{
            Asset:  req.Amount.Currency,
            Amount: req.Amount.Amount.IntPart(),
        },
        Reference: req.Reference,
        Metadata:  req.Metadata,
    }

    // 2. Call vendor API
    resp, err := a.client.Wallets.Credit(ctx, formanceReq)
    if err != nil {
        return nil, fmt.Errorf("formance credit failed: %w", err)
    }

    // 3. Translate vendor response → domain response
    return &ports.WalletTransaction{
        ID:       resp.TransactionID,
        WalletID: req.WalletID,
        Type:     ports.TransactionTypeCredit,
        Amount:   req.Amount,
        Balance: ports.Money{
            Amount:   decimal.NewFromInt(resp.NewBalance.Amount),
            Currency: resp.NewBalance.Asset,
        },
        Reference: req.Reference,
        Metadata:  req.Metadata,
        CreatedAt: resp.CreatedAt,
    }, nil
}

// Implement other methods...
```

**Checklist:**
- [ ] Vendor SDK imported ONLY in adapter
- [ ] Translation logic: domain → vendor
- [ ] Translation logic: vendor → domain
- [ ] Error handling with context
- [ ] Logging (if applicable)

---

### Phase 5: Update Service to Use Interface

#### 8. Refactor Service Constructor
- [ ] Update service struct to use interface field
- [ ] Update constructor to accept interface parameter
- [ ] Remove direct vendor client field
- [ ] Update all method calls to use interface

**Before:**
```go
type AccountService struct {
    formanceClient *formance.Client
    accountRepo    accountdomain.AccountRepository
}

func NewAccountService(formanceClient *formance.Client, accountRepo accountdomain.AccountRepository) *AccountService {
    return &AccountService{
        formanceClient: formanceClient,
        accountRepo:    accountRepo,
    }
}
```

**After:**
```go
type AccountService struct {
    walletService ports.WalletService           // ✅ Interface!
    ledgerService ports.LedgerService           // ✅ Interface!
    authz         ports.AuthorizationProvider   // ✅ Interface!
    accountRepo   accountdomain.AccountRepository
    eventBus      sharedports.EventBus
    logger        sharedports.Logger
}

func NewAccountService(
    walletService ports.WalletService,
    ledgerService ports.LedgerService,
    authz ports.AuthorizationProvider,
    accountRepo accountdomain.AccountRepository,
    eventBus sharedports.EventBus,
    logger sharedports.Logger,
) *AccountService {
    return &AccountService{
        walletService: walletService,
        ledgerService: ledgerService,
        authz:         authz,
        accountRepo:   accountRepo,
        eventBus:      eventBus,
        logger:        logger,
    }
}
```

**Checklist:**
- [ ] Service struct uses interface fields
- [ ] Constructor accepts interface parameters
- [ ] No direct vendor client fields
- [ ] All imports updated

#### 9. Update Service Methods
- [ ] Replace vendor calls with interface calls
- [ ] Keep EXACT same behavior
- [ ] Don't add new logic
- [ ] Don't change error handling

**Before:**
```go
func (s *AccountService) Deposit(ctx context.Context, accountID string, amount decimal.Decimal) error {
    // Direct vendor call
    _, err := s.formanceClient.Wallets.Credit(ctx, &formance.CreditRequest{
        WalletID: accountID,
        Amount: &formance.Monetary{
            Amount: amount.IntPart(),
            Asset:  "USD",
        },
    })
    return err
}
```

**After:**
```go
func (s *AccountService) Deposit(ctx context.Context, accountID string, amount decimal.Decimal, currency string) error {
    // Get account
    account, err := s.accountRepo.FindByID(ctx, uuid.MustParse(accountID))
    if err != nil {
        return fmt.Errorf("account not found: %w", err)
    }

    // Call through interface (same behavior!)
    tx, err := s.walletService.Credit(ctx, ports.CreditRequest{
        WalletID: account.ExternalWalletID,
        Amount: ports.Money{
            Amount:   amount,
            Currency: currency,
        },
        Reference: fmt.Sprintf("DEPOSIT-%s", uuid.New().String()),
        Metadata: map[string]string{
            "account_id": accountID,
            "type":       "deposit",
        },
    })
    if err != nil {
        s.logger.Error("wallet credit failed",
            sharedports.Field{Key: "error", Value: err},
            sharedports.Field{Key: "account_id", Value: accountID},
        )
        return fmt.Errorf("deposit failed: %w", err)
    }

    // Publish event (if existed before)
    s.eventBus.Publish(ctx, "account.deposited", &AccountDepositedEvent{
        AccountID:     accountID,
        TransactionID: tx.ID,
        Amount:        amount,
        Currency:      currency,
    })

    return nil
}
```

**Checklist:**
- [ ] All vendor calls replaced with interface calls
- [ ] Behavior EXACTLY the same
- [ ] No new validation added
- [ ] No new features added
- [ ] Error handling unchanged

---

### Phase 6: Update DI Container

#### 10. Wire Adapter in Container
- [ ] Add adapter wiring method to container
- [ ] Support multiple adapter implementations
- [ ] Use configuration-based selection
- [ ] Set sensible defaults

```go
// internal/infrastructure/config/container.go
func (c *Container) wireWalletService(cfg Config) error {
    switch cfg.WalletProvider {
    case "formance":
        c.WalletService = wallet.NewFormanceWalletAdapter(
            cfg.FormanceConfig.APIKey,
            cfg.FormanceConfig.BaseURL,
        )
    case "tigerbeetle":
        c.WalletService = wallet.NewTigerBeetleWalletAdapter(
            cfg.TigerBeetleConfig.ClusterID,
            cfg.TigerBeetleConfig.Addresses,
        )
    case "inmemory":
        c.WalletService = wallet.NewInMemoryWalletAdapter()
    default:
        c.WalletService = wallet.NewFormanceWalletAdapter(
            cfg.FormanceConfig.APIKey,
            cfg.FormanceConfig.BaseURL,
        )
    }
    return nil
}
```

**Checklist:**
- [ ] Wiring method added
- [ ] Multiple implementations supported
- [ ] Configuration-based selection
- [ ] Default adapter specified

#### 11. Update Service Wiring
- [ ] Update application service wiring to use injected interfaces
- [ ] Remove old vendor client instantiation
- [ ] Inject all required interfaces

```go
func (c *Container) wireApplicationServices() {
    c.AccountService = service.NewAccountService(
        c.WalletService,   // Injected!
        c.LedgerService,   // Injected!
        c.AuthzProvider,   // Injected!
        c.AccountRepository,
        c.EventBus,
        c.Logger,
    )
}
```

**Checklist:**
- [ ] Service instantiation uses injected interfaces
- [ ] All dependencies provided
- [ ] No direct vendor clients

---

### Phase 7: Update Tests

#### 12. Refactor Unit Tests
- [ ] Replace mocks with in-memory adapters
- [ ] Remove vendor-specific test setup
- [ ] Update test assertions
- [ ] Ensure tests pass

**Before:**
```go
func TestAccountService_Deposit(t *testing.T) {
    mockFormanceClient := &MockFormanceClient{}
    mockFormanceClient.On("Wallets.Credit", mock.Anything, mock.Anything).
        Return(&formance.CreditResponse{}, nil)

    service := &AccountService{formanceClient: mockFormanceClient}
    // ...
}
```

**After:**
```go
func TestAccountService_Deposit(t *testing.T) {
    // Use in-memory adapters (no mocks!)
    walletAdapter := wallet.NewInMemoryWalletAdapter()
    ledgerAdapter := ledger.NewInMemoryLedgerAdapter()
    authzAdapter := authz.NewInMemoryAuthzAdapter()
    accountRepo := memory.NewInMemoryAccountRepository()
    eventBus := eventbus.NewInMemoryEventBusAdapter()
    logger := logger.NewInMemoryLoggerAdapter()

    service := service.NewAccountService(
        walletAdapter,
        ledgerAdapter,
        authzAdapter,
        accountRepo,
        eventBus,
        logger,
    )

    // Setup: Create test wallet
    walletID := uuid.New().String()
    walletAdapter.CreateWallet(context.Background(), ports.CreateWalletRequest{
        ID:       walletID,
        Currency: "USD",
    })

    // Create test account
    account := &accountdomain.Account{
        ID:               uuid.New(),
        ExternalWalletID: walletID,
    }
    accountRepo.Save(context.Background(), account)

    // Act
    err := service.Deposit(context.Background(), account.ID.String(), decimal.NewFromInt(100), "USD")

    // Assert
    require.NoError(t, err)

    // Verify wallet balance
    balance, err := walletAdapter.GetBalance(context.Background(), walletID)
    require.NoError(t, err)
    assert.Equal(t, decimal.NewFromInt(100), balance.Available.Amount)

    // Verify event published
    events := eventBus.GetPublishedEvents()
    assert.Len(t, events, 1)
    assert.Equal(t, "account.deposited", events[0].Topic)
}
```

**Checklist:**
- [ ] Mocks replaced with in-memory adapters
- [ ] Tests use real interface implementations
- [ ] Tests pass: `go test ./...`
- [ ] Coverage maintained or improved

#### 13. Add Integration Tests (Optional)
- [ ] Create integration test with real adapters
- [ ] Use test containers if needed
- [ ] Tag with `//go:build integration`

```go
//go:build integration
// +build integration

package integration_test

func TestAccountFlow_WithFormance(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    // Load test config (uses real Formance)
    cfg := loadTestConfig()
    container := config.NewContainer(cfg)

    // Run full flow test with real Formance adapter
    // ...
}
```

---

### Phase 8: Validation

#### 14. Run Validation Checks
- [ ] Check vendor imports in domain
- [ ] Check infrastructure imports in domain
- [ ] Find remaining direct vendor usages
- [ ] Run full validation suite

```bash
# Check vendor imports
./scripts/refactoring/refactor-to-hexagonal.sh check-imports

# Check infrastructure imports
./scripts/refactoring/refactor-to-hexagonal.sh check-infra

# Find vendor usages
./scripts/refactoring/refactor-to-hexagonal.sh find-usages

# Full validation
./scripts/refactoring/refactor-to-hexagonal.sh validate
```

**Checklist:**
- [ ] No vendor imports in `internal/domain/`
- [ ] No infrastructure imports in `internal/domain/`
- [ ] No direct vendor client usages in services
- [ ] All validation checks pass

#### 15. Run Tests
- [ ] Run all unit tests
- [ ] Check test coverage
- [ ] Run integration tests (if applicable)
- [ ] Fix any failures

```bash
# Run all tests
go test ./...

# Check coverage
go test -cover ./...

# Run specific domain tests
go test ./internal/domain/account/...

# Run integration tests
go test -tags=integration ./test/integration/...
```

**Checklist:**
- [ ] All tests pass
- [ ] Coverage ≥ 80%
- [ ] No test failures
- [ ] Integration tests pass (if applicable)

#### 16. Manual Testing
- [ ] Start dev server with in-memory adapters
- [ ] Test refactored functionality manually
- [ ] Verify behavior identical to before
- [ ] Check logs for errors

```bash
# Start with in-memory adapters
WALLET_PROVIDER=inmemory \
LEDGER_PROVIDER=inmemory \
AUTHZ_PROVIDER=inmemory \
go run cmd/api-server/main.go
```

**Checklist:**
- [ ] Service starts without errors
- [ ] Endpoints respond correctly
- [ ] Behavior matches pre-refactoring
- [ ] No errors in logs

---

### Phase 9: Documentation & Commit

#### 17. Update Documentation
- [ ] Add adapter documentation
- [ ] Update service documentation
- [ ] Document configuration options
- [ ] Update README if needed

#### 18. Commit Changes
- [ ] Stage all changes
- [ ] Write descriptive commit message
- [ ] Reference task ID
- [ ] Push to remote

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "refactor(R1.1.1): Extract WalletService interface from Formance

- Created WalletService interface in domain/account/ports/
- Implemented FormanceWalletAdapter in infrastructure/adapters/wallet/
- Implemented InMemoryWalletAdapter for testing
- Updated AccountService to use injected WalletService interface
- Updated DI container to wire wallet service
- Refactored tests to use in-memory adapter

BREAKING CHANGE: AccountService constructor signature changed
Before: NewAccountService(formanceClient)
After: NewAccountService(walletService, ledgerService, authz, repo, eventBus, logger)

All tests passing. Zero vendor imports in domain layer.
"

# Push
git push origin refactor/phase-0-1-hexagonal
```

**Checklist:**
- [ ] Commit message follows conventional commits
- [ ] Task ID referenced (e.g., R1.1.1)
- [ ] Changes clearly described
- [ ] Breaking changes noted
- [ ] Pushed to remote

---

## ✅ Task Completion Criteria

**A refactoring task is complete when ALL of the following are true:**

### Code Quality
- [ ] Port interface created in `domain/**/ports/`
- [ ] Production adapter created in `infrastructure/adapters/`
- [ ] In-memory adapter created for testing
- [ ] Service updated to use injected interface
- [ ] DI container wiring added
- [ ] No vendor imports in domain layer
- [ ] No infrastructure imports in domain layer

### Testing
- [ ] All unit tests pass
- [ ] Test coverage ≥ 80%
- [ ] Tests use in-memory adapters
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing completed

### Validation
- [ ] `./scripts/refactoring/refactor-to-hexagonal.sh validate` passes
- [ ] No direct vendor usages found
- [ ] Behavior identical to pre-refactoring

### Documentation & Git
- [ ] Code documented
- [ ] Changes committed with descriptive message
- [ ] Task marked complete in REFACTORING_TASKS.md

---

## 📊 Progress Tracking Template

Copy this for each task:

```markdown
### Task: R1.1.1 - Extract WalletService Interface

**Status:** 🚧 IN PROGRESS
**Started:** 2026-01-02
**Assignee:** [Your Name]

**Phase 1: Analysis** ✅ DONE
- [x] Read existing code
- [x] Identify vendor dependencies
- [x] Define interface scope
- [x] Ensure tests pass

**Phase 2: Port Interface** ✅ DONE
- [x] Create port interface
- [x] Define domain types
- [x] Add documentation

**Phase 3: In-Memory Adapter** 🚧 IN PROGRESS
- [x] Create adapter
- [ ] Write tests
- [ ] Verify tests pass

**Phase 4: Production Adapter** ⏳ TODO
- [ ] Create Formance adapter
- [ ] Implement translation logic
- [ ] Handle errors

**Phase 5: Service Update** ⏳ TODO
- [ ] Update service struct
- [ ] Update constructor
- [ ] Update method calls

**Phase 6: DI Container** ⏳ TODO
- [ ] Wire adapter
- [ ] Update service wiring

**Phase 7: Update Tests** ⏳ TODO
- [ ] Refactor unit tests
- [ ] Add integration tests

**Phase 8: Validation** ⏳ TODO
- [ ] Run validation checks
- [ ] Run all tests
- [ ] Manual testing

**Phase 9: Documentation** ⏳ TODO
- [ ] Update docs
- [ ] Commit changes

**Completed:** [Date]
**Notes:** [Any notes or blockers]
```

---

## 🎯 Quick Reference Commands

```bash
# Create directory structure
./scripts/refactoring/refactor-to-hexagonal.sh create-structure

# Generate port template
./scripts/refactoring/refactor-to-hexagonal.sh generate-port account WalletService

# Generate adapter template
./scripts/refactoring/refactor-to-hexagonal.sh generate-adapter wallet FormanceWallet

# Generate DI container
./scripts/refactoring/refactor-to-hexagonal.sh generate-container

# Find vendor usages
./scripts/refactoring/refactor-to-hexagonal.sh find-usages

# Check vendor imports
./scripts/refactoring/refactor-to-hexagonal.sh check-imports

# Full validation
./scripts/refactoring/refactor-to-hexagonal.sh validate

# Run tests
go test ./...
go test -cover ./...
go test -tags=integration ./test/integration/...

# Start with in-memory adapters
WALLET_PROVIDER=inmemory go run cmd/api-server/main.go
```

---

**Last Updated:** 2026-01-02
**For:** Phase 0 & Phase 1 Refactoring to Hexagonal Architecture

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
