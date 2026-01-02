# Phase 0 & Phase 1 Refactoring Tasks

> **Purpose:** Convert existing Phase 0 & Phase 1 implementation from vendor-coupled to vendor-agnostic Hexagonal Architecture
>
> **Status:** 🔄 Refactoring in Progress
> **Created:** 2026-01-02
> **Target:** Zero vendor imports in domain layer, 100% adapter-based infrastructure

---

## 📋 Table of Contents

1. [Refactoring Overview](#refactoring-overview)
2. [Phase 0 Refactoring Tasks](#phase-0-refactoring-tasks)
3. [Phase 1 Refactoring Tasks](#phase-1-refactoring-tasks)
4. [Testing Strategy](#testing-strategy)
5. [Migration Path](#migration-path)
6. [Validation Checklist](#validation-checklist)

---

## 🎯 Refactoring Overview

### Current State (Before Refactoring)

```
❌ PROBLEMS:
- Domain layer imports vendor SDKs directly (github.com/formancehq/*, github.com/ory/*)
- Business logic tightly coupled to Formance, Ory implementations
- No interface abstractions for external services
- Difficult to test without external dependencies
- Impossible to swap vendors without rewriting business logic
- No DI container for dependency management
```

### Target State (After Refactoring)

```
✅ SOLUTIONS:
- Domain layer depends only on interfaces (ports)
- Vendor SDKs isolated in adapter layer
- Pluggable adapters (Formance, Ory, In-Memory, Alternative vendors)
- DI container for configuration-based adapter wiring
- Unit tests use in-memory adapters (no external deps)
- Business logic remains unchanged when swapping vendors
```

### Refactoring Principles

1. **🔌 Hexagonal Architecture** - Domain defines interfaces, infrastructure implements
2. **📦 Dependency Inversion** - High-level modules depend on abstractions
3. **🧪 Testability First** - Create in-memory adapters before production adapters
4. **🔄 Incremental Migration** - Refactor one service at a time, keep system running
5. **✅ Backward Compatibility** - Ensure existing features continue working

---

## 🏗️ Phase 0 Refactoring Tasks

### R0.1: Multi-Tenancy Middleware Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Hardcoded PostgreSQL schema switching
func TenantMiddleware(db *gorm.DB) gin.HandlerFunc {
    return func(c *gin.Context) {
        tenantID := extractTenantFromHeader(c)
        db.Exec("SET search_path TO ?", tenantID)
        c.Next()
    }
}
```

**Refactoring Tasks:**

- [ ] **R0.1.1** - Create `TenantIsolationProvider` interface in `domain/shared/ports/`
  ```go
  // internal/domain/shared/ports/tenant_isolation.go
  type TenantIsolationProvider interface {
      IsolateTenant(ctx context.Context, tenantID string) error
      GetCurrentTenant(ctx context.Context) (string, error)
      ReleaseTenant(ctx context.Context) error
  }
  ```

- [ ] **R0.1.2** - Create PostgreSQL adapter in `infrastructure/adapters/isolation/`
  ```go
  // internal/infrastructure/adapters/isolation/postgres_isolation_adapter.go
  type PostgresIsolationAdapter struct {
      db *gorm.DB
  }

  func (a *PostgresIsolationAdapter) IsolateTenant(ctx context.Context, tenantID string) error {
      return a.db.Exec("SET search_path TO ?", tenantID).Error
  }
  ```

- [ ] **R0.1.3** - Create in-memory adapter for testing
  ```go
  // internal/infrastructure/adapters/isolation/inmemory_isolation_adapter.go
  type InMemoryIsolationAdapter struct {
      currentTenant string
      mu            sync.RWMutex
  }
  ```

- [ ] **R0.1.4** - Update middleware to use injected interface
  ```go
  func TenantMiddleware(isolationProvider domain.TenantIsolationProvider) gin.HandlerFunc {
      return func(c *gin.Context) {
          tenantID := extractTenantFromHeader(c)
          if err := isolationProvider.IsolateTenant(c.Request.Context(), tenantID); err != nil {
              c.AbortWithStatus(http.StatusUnauthorized)
              return
          }
          c.Next()
      }
  }
  ```

- [ ] **R0.1.5** - Update tests to use in-memory adapter

---

### R0.2: Event Store Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Event Horizon dependency in domain
import "github.com/looplab/eventhorizon"

type AccountAggregate struct {
    *eventhorizon.AggregateBase  // Direct vendor dependency!
}
```

**Refactoring Tasks:**

- [ ] **R0.2.1** - Create `EventStore` interface in `domain/shared/ports/`
  ```go
  // internal/domain/shared/ports/event_store.go
  type EventStore interface {
      Save(ctx context.Context, events []DomainEvent, originalVersion int) error
      Load(ctx context.Context, aggregateID string) ([]DomainEvent, error)
      LoadFromVersion(ctx context.Context, aggregateID string, version int) ([]DomainEvent, error)
  }

  type DomainEvent interface {
      AggregateID() string
      AggregateType() string
      EventType() string
      EventData() interface{}
      Version() int
      Timestamp() time.Time
  }
  ```

- [ ] **R0.2.2** - Create vendor-agnostic `AggregateRoot` base in `domain/shared/`
  ```go
  // internal/domain/shared/aggregate_root.go
  type AggregateRoot struct {
      id              string
      version         int
      uncommittedEvents []DomainEvent
  }

  func (a *AggregateRoot) RecordEvent(event DomainEvent) {
      a.uncommittedEvents = append(a.uncommittedEvents, event)
      a.version++
  }
  ```

- [ ] **R0.2.3** - Create Event Horizon adapter in `infrastructure/adapters/eventstore/`
  ```go
  // internal/infrastructure/adapters/eventstore/eventhorizon_adapter.go
  type EventHorizonAdapter struct {
      eventStore eventhorizon.EventStore
  }

  func (a *EventHorizonAdapter) Save(ctx context.Context, events []domain.DomainEvent, version int) error {
      // Translate domain events to Event Horizon events
      ehEvents := make([]eventhorizon.Event, len(events))
      for i, evt := range events {
          ehEvents[i] = a.translateToEHEvent(evt)
      }
      return a.eventStore.Save(ctx, ehEvents, version)
  }
  ```

- [ ] **R0.2.4** - Create in-memory event store adapter
  ```go
  // internal/infrastructure/adapters/eventstore/inmemory_eventstore_adapter.go
  type InMemoryEventStoreAdapter struct {
      events map[string][]domain.DomainEvent
      mu     sync.RWMutex
  }
  ```

- [ ] **R0.2.5** - Refactor existing aggregates to use new base
  ```go
  // internal/domain/account/aggregate/account_aggregate.go
  type AccountAggregate struct {
      shared.AggregateRoot  // ✅ Vendor-agnostic base!
      balance    decimal.Decimal
      status     AccountStatus
      currency   string
  }
  ```

- [ ] **R0.2.6** - Update all event handlers to use new interfaces

---

### R0.3: Event Bus Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Redis dependency in handlers
import "github.com/redis/go-redis/v9"

func (h *AccountEventHandler) Handle(ctx context.Context, event Event) error {
    // Direct Redis call
    h.redis.Publish(ctx, "account.events", event.Marshal())
}
```

**Refactoring Tasks:**

- [ ] **R0.3.1** - Create `EventBus` interface in `domain/shared/ports/`
  ```go
  // internal/domain/shared/ports/event_bus.go
  type EventBus interface {
      Publish(ctx context.Context, topic string, event DomainEvent) error
      Subscribe(ctx context.Context, topic string, handler EventHandler) error
      Unsubscribe(ctx context.Context, topic string, handler EventHandler) error
  }

  type EventHandler interface {
      Handle(ctx context.Context, event DomainEvent) error
  }
  ```

- [ ] **R0.3.2** - Create Redis event bus adapter
  ```go
  // internal/infrastructure/adapters/eventbus/redis_eventbus_adapter.go
  type RedisEventBusAdapter struct {
      client *redis.Client
  }
  ```

- [ ] **R0.3.3** - Create in-memory event bus adapter
  ```go
  // internal/infrastructure/adapters/eventbus/inmemory_eventbus_adapter.go
  type InMemoryEventBusAdapter struct {
      handlers map[string][]domain.EventHandler
      mu       sync.RWMutex
  }
  ```

- [ ] **R0.3.4** - Update all event publishers to use interface

---

### R0.4: Logging Infrastructure Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct zap dependency everywhere
import "go.uber.org/zap"

func (s *AccountService) CreateAccount(ctx context.Context) error {
    zap.L().Info("creating account", zap.String("id", id))  // Direct vendor!
}
```

**Refactoring Tasks:**

- [ ] **R0.4.1** - Create `Logger` interface in `domain/shared/ports/`
  ```go
  // internal/domain/shared/ports/logger.go
  type Logger interface {
      Debug(msg string, fields ...Field)
      Info(msg string, fields ...Field)
      Warn(msg string, fields ...Field)
      Error(msg string, fields ...Field)
      With(fields ...Field) Logger
  }

  type Field struct {
      Key   string
      Value interface{}
  }
  ```

- [ ] **R0.4.2** - Create Zap adapter
  ```go
  // internal/infrastructure/adapters/logger/zap_logger_adapter.go
  type ZapLoggerAdapter struct {
      logger *zap.Logger
  }
  ```

- [ ] **R0.4.3** - Create in-memory logger for testing
  ```go
  // internal/infrastructure/adapters/logger/inmemory_logger_adapter.go
  type InMemoryLoggerAdapter struct {
      logs []LogEntry
      mu   sync.RWMutex
  }
  ```

- [ ] **R0.4.4** - Replace all direct zap imports with interface

---

### R0.5: Configuration Management Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct viper dependency in application code
import "github.com/spf13/viper"

func NewService() *Service {
    apiKey := viper.GetString("stripe.api_key")  // Direct vendor!
}
```

**Refactoring Tasks:**

- [ ] **R0.5.1** - Create `ConfigProvider` interface
  ```go
  // internal/domain/shared/ports/config.go
  type ConfigProvider interface {
      GetString(key string) string
      GetInt(key string) int
      GetBool(key string) bool
      GetDuration(key string) time.Duration
      Get(key string) interface{}
  }
  ```

- [ ] **R0.5.2** - Create Viper adapter
- [ ] **R0.5.3** - Create in-memory config adapter for testing
- [ ] **R0.5.4** - Update all services to inject config interface

---

### R0.6: Database Repository Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: GORM directly in domain layer
import "gorm.io/gorm"

type AccountRepository struct {
    db *gorm.DB  // Direct GORM dependency!
}
```

**Refactoring Tasks:**

- [ ] **R0.6.1** - Keep repository interfaces in domain (already good if exists)
  ```go
  // internal/domain/account/repository/account_repository.go (INTERFACE)
  type AccountRepository interface {
      Save(ctx context.Context, account *Account) error
      FindByID(ctx context.Context, id uuid.UUID) (*Account, error)
      FindByTenantAndUser(ctx context.Context, tenantID, userID uuid.UUID) ([]*Account, error)
  }
  ```

- [ ] **R0.6.2** - Move GORM implementations to infrastructure
  ```go
  // internal/infrastructure/persistence/gorm/account_repository_impl.go
  type GormAccountRepository struct {
      db *gorm.DB
  }

  func (r *GormAccountRepository) Save(ctx context.Context, account *domain.Account) error {
      // GORM-specific implementation
  }
  ```

- [ ] **R0.6.3** - Create in-memory repository implementations
  ```go
  // internal/infrastructure/persistence/memory/account_repository_impl.go
  type InMemoryAccountRepository struct {
      accounts map[uuid.UUID]*domain.Account
      mu       sync.RWMutex
  }
  ```

- [ ] **R0.6.4** - Ensure domain only imports repository interface, not implementation

---

### R0.7: Dependency Injection Container Creation

**New Infrastructure Needed:**

- [ ] **R0.7.1** - Create DI container structure
  ```go
  // internal/infrastructure/config/container.go
  type Container struct {
      // Ports (interfaces)
      eventStore           domain.EventStore
      eventBus             domain.EventBus
      logger               domain.Logger
      config               domain.ConfigProvider
      tenantIsolation      domain.TenantIsolationProvider

      // Repositories
      accountRepository    accountdomain.AccountRepository

      // Application services
      accountService       *application.AccountService
  }

  func NewContainer(cfg Config) (*Container, error) {
      c := &Container{}

      // Wire adapters based on configuration
      c.wireLogger(cfg)
      c.wireEventStore(cfg)
      c.wireEventBus(cfg)
      c.wireTenantIsolation(cfg)
      c.wireRepositories(cfg)
      c.wireServices()

      return c, nil
  }
  ```

- [ ] **R0.7.2** - Implement adapter wiring methods
  ```go
  func (c *Container) wireEventStore(cfg Config) {
      switch cfg.EventStoreProvider {
      case "eventhorizon":
          c.eventStore = adapters.NewEventHorizonAdapter(cfg.EventHorizonConfig)
      case "postgres":
          c.eventStore = adapters.NewPostgresEventStoreAdapter(cfg.PostgresConfig)
      case "inmemory":
          c.eventStore = adapters.NewInMemoryEventStoreAdapter()
      default:
          c.eventStore = adapters.NewEventHorizonAdapter(cfg.EventHorizonConfig)
      }
  }
  ```

- [ ] **R0.7.3** - Create configuration struct
  ```go
  // internal/infrastructure/config/config.go
  type Config struct {
      // Adapter selection
      EventStoreProvider        string // "eventhorizon", "postgres", "inmemory"
      EventBusProvider          string // "redis", "inmemory"
      LoggerProvider            string // "zap", "logrus", "inmemory"
      TenantIsolationProvider   string // "postgres", "inmemory"

      // Phase 1 specific
      WalletProvider            string // "formance", "tigerbeetle", "inmemory"
      LedgerProvider            string // "formance", "custom", "inmemory"
      AuthzProvider             string // "ory-keto", "casbin", "inmemory"
      IdentityProvider          string // "ory-kratos", "auth0", "inmemory"

      // Vendor-specific configs
      EventHorizonConfig EventHorizonConfig
      PostgresConfig     PostgresConfig
      RedisConfig        RedisConfig
      FormanceConfig     FormanceConfig
      OryConfig          OryConfig
  }
  ```

- [ ] **R0.7.4** - Update main.go to use container
  ```go
  // cmd/api-server/main.go
  func main() {
      cfg := loadConfig()

      container, err := config.NewContainer(cfg)
      if err != nil {
          log.Fatal(err)
      }

      router := setupRouter(container)
      router.Run(":8080")
  }
  ```

---

## 🏦 Phase 1 Refactoring Tasks

### R1.1: Account Domain - Wallet Integration Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Formance SDK import in domain/application layer
import formance "github.com/formancehq/formance-sdk-go"

type AccountService struct {
    formanceClient *formance.Client  // Direct vendor dependency!
}

func (s *AccountService) Deposit(ctx context.Context, accountID string, amount decimal.Decimal) error {
    // Direct Formance API call
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

**Refactoring Tasks:**

- [ ] **R1.1.1** - Create `WalletService` interface in `domain/account/ports/`
  ```go
  // internal/domain/account/ports/wallet.go
  package ports

  type WalletService interface {
      Credit(ctx context.Context, req CreditRequest) (*WalletTransaction, error)
      Debit(ctx context.Context, req DebitRequest) (*WalletTransaction, error)
      GetBalance(ctx context.Context, walletID string) (*Balance, error)
      Transfer(ctx context.Context, req TransferRequest) (*WalletTransaction, error)
      CreateWallet(ctx context.Context, req CreateWalletRequest) (*Wallet, error)
  }

  // Domain types (vendor-agnostic)
  type CreditRequest struct {
      WalletID  string
      Amount    Money
      Reference string
      Metadata  map[string]string
  }

  type DebitRequest struct {
      WalletID  string
      Amount    Money
      Reference string
      Metadata  map[string]string
  }

  type TransferRequest struct {
      FromWalletID string
      ToWalletID   string
      Amount       Money
      Reference    string
      Metadata     map[string]string
  }

  type WalletTransaction struct {
      ID        string
      WalletID  string
      Type      TransactionType // CREDIT, DEBIT, TRANSFER
      Amount    Money
      Balance   Money
      Reference string
      Metadata  map[string]string
      CreatedAt time.Time
  }

  type Balance struct {
      WalletID  string
      Available Money
      Pending   Money
      Total     Money
  }

  type Money struct {
      Amount   decimal.Decimal
      Currency string
  }
  ```

- [ ] **R1.1.2** - Create Formance wallet adapter
  ```go
  // internal/infrastructure/adapters/wallet/formance_wallet_adapter.go
  package wallet

  import formance "github.com/formancehq/formance-sdk-go"

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
      // Translate domain request to Formance request
      formanceReq := &formance.CreditRequest{
          WalletID: req.WalletID,
          Amount: &formance.Monetary{
              Asset:  req.Amount.Currency,
              Amount: req.Amount.Amount.IntPart(),
          },
          Reference: req.Reference,
          Metadata:  req.Metadata,
      }

      // Call Formance API
      resp, err := a.client.Wallets.Credit(ctx, formanceReq)
      if err != nil {
          return nil, fmt.Errorf("formance credit failed: %w", err)
      }

      // Translate Formance response to domain response
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

  // Implement other methods: Debit, GetBalance, Transfer, CreateWallet
  ```

- [ ] **R1.1.3** - Create in-memory wallet adapter
  ```go
  // internal/infrastructure/adapters/wallet/inmemory_wallet_adapter.go
  package wallet

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

      // Create transaction record
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

  // Implement other methods
  ```

- [ ] **R1.1.4** - Update AccountService to use WalletService interface
  ```go
  // internal/application/service/account_service.go
  package service

  type AccountService struct {
      walletService ports.WalletService  // ✅ Interface, not vendor!
      accountRepo   accountdomain.AccountRepository
      eventBus      shareddomain.EventBus
      logger        shareddomain.Logger
  }

  func NewAccountService(
      walletService ports.WalletService,
      accountRepo accountdomain.AccountRepository,
      eventBus shareddomain.EventBus,
      logger shareddomain.Logger,
  ) *AccountService {
      return &AccountService{
          walletService: walletService,
          accountRepo:   accountRepo,
          eventBus:      eventBus,
          logger:        logger,
      }
  }

  func (s *AccountService) Deposit(ctx context.Context, accountID string, amount decimal.Decimal, currency string) error {
      // Validate
      account, err := s.accountRepo.FindByID(ctx, uuid.MustParse(accountID))
      if err != nil {
          return fmt.Errorf("account not found: %w", err)
      }

      // Call wallet service through interface
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
              domain.Field{Key: "error", Value: err},
              domain.Field{Key: "account_id", Value: accountID},
          )
          return fmt.Errorf("deposit failed: %w", err)
      }

      // Publish domain event
      s.eventBus.Publish(ctx, "account.deposited", &AccountDepositedEvent{
          AccountID:     accountID,
          TransactionID: tx.ID,
          Amount:        amount,
          Currency:      currency,
      })

      return nil
  }
  ```

- [ ] **R1.1.5** - Update DI container to wire wallet service
  ```go
  // internal/infrastructure/config/container.go
  func (c *Container) wireWalletService(cfg Config) {
      switch cfg.WalletProvider {
      case "formance":
          c.walletService = wallet.NewFormanceWalletAdapter(
              cfg.FormanceConfig.APIKey,
              cfg.FormanceConfig.BaseURL,
          )
      case "tigerbeetle":
          c.walletService = wallet.NewTigerBeetleAdapter(
              cfg.TigerBeetleConfig.ClusterID,
              cfg.TigerBeetleConfig.Addresses,
          )
      case "inmemory":
          c.walletService = wallet.NewInMemoryWalletAdapter()
      default:
          c.walletService = wallet.NewFormanceWalletAdapter(
              cfg.FormanceConfig.APIKey,
              cfg.FormanceConfig.BaseURL,
          )
      }
  }
  ```

- [ ] **R1.1.6** - Update tests to use in-memory adapter
  ```go
  // internal/application/service/account_service_test.go
  func TestAccountService_Deposit(t *testing.T) {
      // Arrange
      walletAdapter := wallet.NewInMemoryWalletAdapter()
      accountRepo := memory.NewInMemoryAccountRepository()
      eventBus := eventbus.NewInMemoryEventBusAdapter()
      logger := logger.NewInMemoryLoggerAdapter()

      service := NewAccountService(walletAdapter, accountRepo, eventBus, logger)

      // Create test wallet
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

      balance, err := walletAdapter.GetBalance(context.Background(), walletID)
      require.NoError(t, err)
      assert.Equal(t, decimal.NewFromInt(100), balance.Available.Amount)
  }
  ```

---

### R1.2: Account Domain - Ledger Integration Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Formance Ledger import
import formance "github.com/formancehq/formance-sdk-go"

func (s *TransactionService) RecordTransaction(ctx context.Context, tx Transaction) error {
    // Direct Formance Ledger call
    _, err := s.formanceClient.Ledger.CreateTransaction(ctx, &formance.TransactionRequest{
        Postings: []formance.Posting{
            {
                Source:      tx.Source,
                Destination: tx.Destination,
                Amount:      tx.Amount.IntPart(),
                Asset:       tx.Currency,
            },
        },
    })
    return err
}
```

**Refactoring Tasks:**

- [ ] **R1.2.1** - Create `LedgerService` interface in `domain/account/ports/`
  ```go
  // internal/domain/account/ports/ledger.go
  type LedgerService interface {
      CreateTransaction(ctx context.Context, req CreateTransactionRequest) (*LedgerTransaction, error)
      GetTransaction(ctx context.Context, txID string) (*LedgerTransaction, error)
      GetBalance(ctx context.Context, accountID string) (*LedgerBalance, error)
      ListTransactions(ctx context.Context, filters TransactionFilters) ([]*LedgerTransaction, error)
  }

  type CreateTransactionRequest struct {
      Postings  []Posting
      Reference string
      Metadata  map[string]string
  }

  type Posting struct {
      Source      string
      Destination string
      Amount      Money
      Asset       string
  }

  type LedgerTransaction struct {
      ID        string
      Postings  []Posting
      Reference string
      Metadata  map[string]string
      Timestamp time.Time
  }

  type LedgerBalance struct {
      AccountID string
      Balances  map[string]decimal.Decimal // asset -> balance
  }
  ```

- [ ] **R1.2.2** - Create Formance ledger adapter
  ```go
  // internal/infrastructure/adapters/ledger/formance_ledger_adapter.go
  type FormanceLedgerAdapter struct {
      client *formance.Client
  }
  ```

- [ ] **R1.2.3** - Create in-memory ledger adapter
  ```go
  // internal/infrastructure/adapters/ledger/inmemory_ledger_adapter.go
  type InMemoryLedgerAdapter struct {
      transactions map[string]*ports.LedgerTransaction
      balances     map[string]map[string]decimal.Decimal // accountID -> asset -> balance
      mu           sync.RWMutex
  }
  ```

- [ ] **R1.2.4** - Update TransactionService to use interface
- [ ] **R1.2.5** - Wire ledger service in DI container
- [ ] **R1.2.6** - Update tests to use in-memory adapter

---

### R1.3: Account Domain - Authorization Integration Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Ory Keto import
import keto "github.com/ory/keto-client-go"

func (s *AccountService) CheckPermission(ctx context.Context, userID, accountID, action string) error {
    // Direct Keto API call
    result, _, err := s.ketoClient.PermissionApi.CheckPermission(ctx).
        Namespace("accounts").
        Object(accountID).
        Relation(action).
        SubjectId(userID).
        Execute()

    if !result.Allowed {
        return ErrPermissionDenied
    }
    return nil
}
```

**Refactoring Tasks:**

- [ ] **R1.3.1** - Create `AuthorizationProvider` interface in `domain/account/ports/`
  ```go
  // internal/domain/account/ports/authorization.go
  type AuthorizationProvider interface {
      CheckPermission(ctx context.Context, req PermissionCheckRequest) (bool, error)
      GrantPermission(ctx context.Context, req GrantPermissionRequest) error
      RevokePermission(ctx context.Context, req RevokePermissionRequest) error
      ListPermissions(ctx context.Context, subject string) ([]Permission, error)
  }

  type PermissionCheckRequest struct {
      Subject  string // "user:123"
      Resource string // "account:456"
      Action   string // "debit", "credit", "view"
  }

  type GrantPermissionRequest struct {
      Subject  string
      Resource string
      Action   string
  }

  type RevokePermissionRequest struct {
      Subject  string
      Resource string
      Action   string
  }

  type Permission struct {
      Subject  string
      Resource string
      Action   string
      GrantedAt time.Time
  }
  ```

- [ ] **R1.3.2** - Create Ory Keto adapter
  ```go
  // internal/infrastructure/adapters/authz/ory_keto_adapter.go
  type OryKetoAdapter struct {
      client *keto.APIClient
  }

  func (a *OryKetoAdapter) CheckPermission(ctx context.Context, req ports.PermissionCheckRequest) (bool, error) {
      result, _, err := a.client.PermissionApi.CheckPermission(ctx).
          Namespace("finaegis").
          Object(req.Resource).
          Relation(req.Action).
          SubjectId(req.Subject).
          Execute()

      if err != nil {
          return false, fmt.Errorf("keto check failed: %w", err)
      }

      return result.Allowed, nil
  }
  ```

- [ ] **R1.3.3** - Create Casbin adapter (alternative)
  ```go
  // internal/infrastructure/adapters/authz/casbin_adapter.go
  type CasbinAdapter struct {
      enforcer *casbin.Enforcer
  }

  func (a *CasbinAdapter) CheckPermission(ctx context.Context, req ports.PermissionCheckRequest) (bool, error) {
      allowed, err := a.enforcer.Enforce(req.Subject, req.Resource, req.Action)
      if err != nil {
          return false, fmt.Errorf("casbin enforce failed: %w", err)
      }
      return allowed, nil
  }
  ```

- [ ] **R1.3.4** - Create in-memory authorization adapter
  ```go
  // internal/infrastructure/adapters/authz/inmemory_authz_adapter.go
  type InMemoryAuthzAdapter struct {
      permissions map[string]bool // "subject:resource:action" -> allowed
      mu          sync.RWMutex
  }

  func (a *InMemoryAuthzAdapter) CheckPermission(ctx context.Context, req ports.PermissionCheckRequest) (bool, error) {
      a.mu.RLock()
      defer a.mu.RUnlock()

      key := fmt.Sprintf("%s:%s:%s", req.Subject, req.Resource, req.Action)
      allowed, exists := a.permissions[key]

      return allowed && exists, nil
  }
  ```

- [ ] **R1.3.5** - Update AccountService to use interface
  ```go
  type AccountService struct {
      walletService ports.WalletService
      authz         ports.AuthorizationProvider  // ✅ Interface!
      accountRepo   accountdomain.AccountRepository
      eventBus      shareddomain.EventBus
      logger        shareddomain.Logger
  }

  func (s *AccountService) Withdraw(ctx context.Context, userID, accountID string, amount decimal.Decimal) error {
      // Check permission through interface
      allowed, err := s.authz.CheckPermission(ctx, ports.PermissionCheckRequest{
          Subject:  fmt.Sprintf("user:%s", userID),
          Resource: fmt.Sprintf("account:%s", accountID),
          Action:   "debit",
      })
      if err != nil {
          return fmt.Errorf("permission check failed: %w", err)
      }
      if !allowed {
          return ErrPermissionDenied
      }

      // Proceed with withdrawal
      // ...
  }
  ```

- [ ] **R1.3.6** - Wire authz service in DI container
  ```go
  func (c *Container) wireAuthzService(cfg Config) {
      switch cfg.AuthzProvider {
      case "ory-keto":
          c.authzService = authz.NewOryKetoAdapter(cfg.OryConfig.KetoURL)
      case "casbin":
          c.authzService = authz.NewCasbinAdapter(cfg.CasbinConfig.ModelPath, cfg.CasbinConfig.PolicyPath)
      case "opa":
          c.authzService = authz.NewOPAAdapter(cfg.OPAConfig.URL)
      case "inmemory":
          c.authzService = authz.NewInMemoryAuthzAdapter()
      default:
          c.authzService = authz.NewOryKetoAdapter(cfg.OryConfig.KetoURL)
      }
  }
  ```

- [ ] **R1.3.7** - Update tests to use in-memory adapter

---

### R1.4: Account Domain - Identity Integration Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Ory Kratos import
import kratos "github.com/ory/kratos-client-go"

func (s *UserService) GetUser(ctx context.Context, userID string) (*User, error) {
    // Direct Kratos API call
    identity, _, err := s.kratosClient.V0alpha2Api.AdminGetIdentity(ctx, userID).Execute()
    if err != nil {
        return nil, err
    }
    return translateIdentity(identity), nil
}
```

**Refactoring Tasks:**

- [ ] **R1.4.1** - Create `IdentityProvider` interface
  ```go
  // internal/domain/shared/ports/identity.go
  type IdentityProvider interface {
      GetIdentity(ctx context.Context, identityID string) (*Identity, error)
      CreateIdentity(ctx context.Context, req CreateIdentityRequest) (*Identity, error)
      UpdateIdentity(ctx context.Context, identityID string, req UpdateIdentityRequest) (*Identity, error)
      DeleteIdentity(ctx context.Context, identityID string) error
      ListIdentities(ctx context.Context, filters IdentityFilters) ([]*Identity, error)
  }

  type Identity struct {
      ID        string
      Email     string
      Traits    map[string]interface{}
      CreatedAt time.Time
      UpdatedAt time.Time
  }
  ```

- [ ] **R1.4.2** - Create Ory Kratos adapter
- [ ] **R1.4.3** - Create Auth0 adapter (alternative)
- [ ] **R1.4.4** - Create in-memory identity adapter
- [ ] **R1.4.5** - Update services to use interface
- [ ] **R1.4.6** - Wire identity service in DI container

---

### R1.5: Account Domain - API Gateway Integration Refactoring

**Current Implementation Issues:**
```go
// ❌ BEFORE: Direct Ory Oathkeeper configuration
import oathkeeper "github.com/ory/oathkeeper-client-go"

func setupRoutes(router *gin.Engine) {
    // Direct Oathkeeper integration
    router.Use(OathkeeperMiddleware(oathkeeperClient))
}
```

**Refactoring Tasks:**

- [ ] **R1.5.1** - Create `APIGateway` interface
  ```go
  // internal/domain/shared/ports/gateway.go
  type APIGateway interface {
      ValidateRequest(ctx context.Context, req *http.Request) (*AuthContext, error)
      GetAuthContext(ctx context.Context) (*AuthContext, error)
  }

  type AuthContext struct {
      UserID    string
      TenantID  string
      SessionID string
      Scopes    []string
  }
  ```

- [ ] **R1.5.2** - Create Ory Oathkeeper adapter
- [ ] **R1.5.3** - Create in-memory gateway adapter
- [ ] **R1.5.4** - Update middleware to use interface

---

## 🧪 Testing Strategy

### Unit Test Refactoring

**Before (Mocking Nightmare):**
```go
// ❌ BEFORE: Mocking vendor-specific clients
func TestAccountService_Deposit(t *testing.T) {
    mockFormanceClient := &MockFormanceClient{}
    mockFormanceClient.On("Wallets.Credit", mock.Anything, mock.Anything).Return(&formance.CreditResponse{}, nil)

    service := &AccountService{formanceClient: mockFormanceClient}
    // ...
}
```

**After (Clean Interface Testing):**
```go
// ✅ AFTER: Use in-memory adapters
func TestAccountService_Deposit(t *testing.T) {
    walletAdapter := wallet.NewInMemoryWalletAdapter()
    accountRepo := memory.NewInMemoryAccountRepository()
    eventBus := eventbus.NewInMemoryEventBusAdapter()
    logger := logger.NewInMemoryLoggerAdapter()

    service := NewAccountService(walletAdapter, accountRepo, eventBus, logger)

    // Test with real in-memory implementations (no mocks!)
    err := service.Deposit(ctx, accountID, amount, currency)

    // Verify state in adapters
    balance, _ := walletAdapter.GetBalance(ctx, walletID)
    assert.Equal(t, expectedBalance, balance.Available.Amount)
}
```

### Integration Test Refactoring

- [ ] **R-TEST-1** - Create adapter-based integration tests
  ```go
  func TestAccountFlow_WithFormanceAdapter(t *testing.T) {
      if testing.Short() {
          t.Skip("skipping integration test")
      }

      // Use real Formance adapter for integration tests
      cfg := loadTestConfig()
      container := config.NewContainer(cfg) // Uses real adapters

      // Run full flow test
      // ...
  }
  ```

- [ ] **R-TEST-2** - Create test configuration presets
  ```yaml
  # config/test-unit.yaml
  event_store_provider: "inmemory"
  event_bus_provider: "inmemory"
  wallet_provider: "inmemory"
  ledger_provider: "inmemory"
  authz_provider: "inmemory"

  # config/test-integration.yaml
  event_store_provider: "eventhorizon"
  event_bus_provider: "redis"
  wallet_provider: "formance"
  ledger_provider: "formance"
  authz_provider: "ory-keto"
  ```

---

## 🔄 Migration Path

### Step-by-Step Refactoring Sequence

**Week 1: Foundation (Phase 0)**
1. ✅ Day 1-2: Create all port interfaces (R0.1.1, R0.2.1, R0.3.1, R0.4.1, R0.5.1)
2. ✅ Day 3-4: Create in-memory adapters for testing
3. ✅ Day 5: Create DI container skeleton (R0.7.1)

**Week 2: Phase 0 Adapters**
1. ✅ Day 1: Event store refactoring (R0.2.2-R0.2.6)
2. ✅ Day 2: Event bus refactoring (R0.3.2-R0.3.4)
3. ✅ Day 3: Logger refactoring (R0.4.2-R0.4.4)
4. ✅ Day 4: Config & tenant isolation (R0.5.2, R0.1.2)
5. ✅ Day 5: Repository refactoring (R0.6.2-R0.6.4)

**Week 3: Phase 1 Wallet & Ledger**
1. ✅ Day 1-2: Wallet service refactoring (R1.1.1-R1.1.3)
2. ✅ Day 3-4: Ledger service refactoring (R1.2.1-R1.2.3)
3. ✅ Day 5: Update services to use interfaces (R1.1.4, R1.2.4)

**Week 4: Phase 1 Auth & Final**
1. ✅ Day 1-2: Authorization refactoring (R1.3.1-R1.3.4)
2. ✅ Day 3: Identity & gateway refactoring (R1.4.1-R1.5.4)
3. ✅ Day 4: DI container wiring (R0.7.2-R0.7.4, R1.1.5, R1.2.5, R1.3.6)
4. ✅ Day 5: Full integration testing

### Backward Compatibility Strategy

```go
// Keep old implementation temporarily for gradual migration
func NewAccountServiceWithFormance(formanceClient *formance.Client) *AccountService {
    // Wrap old client in adapter
    walletAdapter := wallet.NewFormanceWalletAdapter(formanceClient.APIKey, formanceClient.BaseURL)

    return NewAccountService(
        walletAdapter,
        // ... other dependencies
    )
}

// Mark as deprecated
// Deprecated: Use NewAccountService with injected adapters instead
func NewAccountServiceLegacy(formanceClient *formance.Client) *AccountService {
    return NewAccountServiceWithFormance(formanceClient)
}
```

### Feature Flag Approach

```go
// Allow gradual rollout
type Config struct {
    UseHexagonalArchitecture bool   // Feature flag
    WalletProvider           string // "formance-legacy" or "formance-adapter"
}

func (c *Container) wireWalletService(cfg Config) {
    if !cfg.UseHexagonalArchitecture {
        // Use legacy implementation
        c.walletService = wallet.NewLegacyFormanceWrapper(formanceClient)
    } else {
        // Use new adapter
        c.walletService = wallet.NewFormanceWalletAdapter(cfg.FormanceConfig)
    }
}
```

---

## ✅ Validation Checklist

### Code Quality Validation

- [ ] **No vendor imports in domain layer**
  ```bash
  # Run this check - should return empty
  grep -r "github.com/formancehq" internal/domain/
  grep -r "github.com/ory" internal/domain/
  grep -r "gorm.io/gorm" internal/domain/
  grep -r "github.com/redis/go-redis" internal/domain/
  ```

- [ ] **All services use injected interfaces**
  ```bash
  # Should find no direct vendor client fields
  grep -r "formanceClient" internal/application/
  grep -r "kratosClient" internal/application/
  grep -r "ketoClient" internal/application/
  ```

- [ ] **DI container wires all adapters**
  ```go
  // Verify container has all adapter wiring methods
  container.wireWalletService(cfg)
  container.wireLedgerService(cfg)
  container.wireAuthzService(cfg)
  container.wireIdentityService(cfg)
  container.wireEventStore(cfg)
  container.wireEventBus(cfg)
  container.wireLogger(cfg)
  ```

### Testing Validation

- [ ] **All unit tests use in-memory adapters**
  ```bash
  # Should find no testcontainers in unit tests
  grep -r "testcontainers" internal/application/
  grep -r "testcontainers" internal/domain/
  ```

- [ ] **Unit tests run without external dependencies**
  ```bash
  # Should pass without Docker/Redis/Postgres
  go test ./internal/domain/... ./internal/application/...
  ```

- [ ] **Integration tests use real adapters**
  ```bash
  # Should use production adapters
  go test -tags=integration ./test/integration/...
  ```

### Architecture Validation

- [ ] **Dependency direction is correct**
  ```
  ✅ Domain → (defines) → Ports (interfaces)
  ✅ Infrastructure → (implements) → Ports
  ✅ Application → (uses) → Ports
  ❌ Domain → Infrastructure (should not exist!)
  ❌ Domain → External vendors (should not exist!)
  ```

- [ ] **Adapter substitution works**
  ```bash
  # Test with different providers
  WALLET_PROVIDER=inmemory go test ./...
  WALLET_PROVIDER=formance go test -tags=integration ./...
  WALLET_PROVIDER=tigerbeetle go test -tags=integration ./...
  ```

### Documentation Validation

- [ ] All ports have interface documentation
- [ ] All adapters have implementation notes
- [ ] DI container configuration documented
- [ ] Migration guide created
- [ ] ADR (Architecture Decision Record) created

---

## 📊 Progress Tracking

### Refactoring Dashboard

| Task ID | Description | Status | Assignee | Completion Date |
|---------|-------------|--------|----------|-----------------|
| R0.1.1 | TenantIsolationProvider interface | ⏳ TODO | - | - |
| R0.1.2 | PostgreSQL isolation adapter | ⏳ TODO | - | - |
| R0.2.1 | EventStore interface | ⏳ TODO | - | - |
| R0.2.2 | Vendor-agnostic AggregateRoot | ⏳ TODO | - | - |
| R0.3.1 | EventBus interface | ⏳ TODO | - | - |
| R0.7.1 | DI container structure | ⏳ TODO | - | - |
| R1.1.1 | WalletService interface | ⏳ TODO | - | - |
| R1.1.2 | Formance wallet adapter | ⏳ TODO | - | - |
| R1.1.3 | In-memory wallet adapter | ⏳ TODO | - | - |
| R1.2.1 | LedgerService interface | ⏳ TODO | - | - |
| R1.3.1 | AuthorizationProvider interface | ⏳ TODO | - | - |

**Legend:**
- ⏳ TODO - Not started
- 🚧 IN PROGRESS - Currently working
- ✅ DONE - Completed and tested
- ❌ BLOCKED - Blocked by dependencies

---

## 🎯 Success Criteria

### Phase 0 Refactoring Complete When:
- [ ] Zero vendor imports in `internal/domain/`
- [ ] All infrastructure services use adapters
- [ ] DI container wires all Phase 0 dependencies
- [ ] Unit tests run without external dependencies
- [ ] Integration tests pass with real adapters
- [ ] Code coverage ≥ 80%

### Phase 1 Refactoring Complete When:
- [ ] Account domain uses only interfaces
- [ ] Wallet/Ledger/Authz/Identity all adapter-based
- [ ] Can swap Formance for in-memory in tests
- [ ] Can swap Ory Keto for Casbin/OPA via config
- [ ] All existing features work identically
- [ ] Performance benchmarks show no regression

### Full Refactoring Success:
- [ ] Both Phase 0 & 1 criteria met
- [ ] Documentation complete
- [ ] Team trained on new architecture
- [ ] Production deployment successful
- [ ] Zero regressions in production

---

## 📚 References

- **Hexagonal Architecture**: https://alistair.cockburn.us/hexagonal-architecture/
- **Dependency Inversion Principle**: https://en.wikipedia.org/wiki/Dependency_inversion_principle
- **Clean Architecture**: Robert C. Martin - "Clean Architecture"
- **Domain-Driven Design**: Eric Evans - "Domain-Driven Design"

---

**Last Updated:** 2026-01-02
**Refactoring Owner:** Development Team
**Review Cycle:** Weekly progress review

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
