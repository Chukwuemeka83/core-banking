#!/bin/bash

################################################################################
# FinAegis Go - Financial Infrastructure Monorepo Bootstrap Script
#
# Purpose: Initialize a world-class Golang monorepo for GCC/MENA fintech
# Features: DDD, Event Sourcing, Multi-tenancy, Pluggable Architecture
# License: Commercial-ready (MIT/Apache 2.0 compatible)
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${1:-finaegis-go}"
GO_VERSION="1.23"
MODULE_PATH="github.com/finaegis/${PROJECT_NAME}"

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           FinAegis Go - Financial Infrastructure              ║"
    echo "║              Monorepo Bootstrap v1.0.0                        ║"
    echo "║                                                               ║"
    echo "║  Building for: Scalability | Extensibility | Pluggability    ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Go version
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go ${GO_VERSION} or later."
        exit 1
    fi

    GO_INSTALLED_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    log_info "Go version: ${GO_INSTALLED_VERSION}"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not installed. You'll need it for local development."
    else
        log_info "Docker: $(docker --version)"
    fi

    # Check make
    if ! command -v make &> /dev/null; then
        log_warn "Make not installed. Installing via package manager recommended."
    fi
}

# Create directory structure
create_directory_structure() {
    log_info "Creating directory structure for ${PROJECT_NAME}..."

    # Create project root
    mkdir -p "${PROJECT_NAME}"
    cd "${PROJECT_NAME}"

    # Root-level directories
    mkdir -p cmd              # Entry points (API servers, CLI tools, workers)
    mkdir -p internal         # Private application code
    mkdir -p pkg              # Public libraries (can be imported externally)
    mkdir -p api              # API definitions (OpenAPI, gRPC proto)
    mkdir -p deployments      # Deployment configs (k8s, docker-compose)
    mkdir -p scripts          # Build and utility scripts
    mkdir -p docs             # Documentation
    mkdir -p test             # Integration and E2E tests
    mkdir -p configs          # Configuration files
    mkdir -p migrations       # Database migrations
    mkdir -p build            # Build artifacts and CI

    # Internal application structure (DDD)
    mkdir -p internal/domain
    mkdir -p internal/infrastructure
    mkdir -p internal/interfaces
    mkdir -p internal/application
    mkdir -p internal/shared

    # Domain layer (Bounded Contexts)
    log_info "Creating domain structure..."

    # Core Financial Domains
    domains=(
        "account"           # Account management
        "ledger"            # Double-entry ledger (abstraction)
        "payment"           # Payment processing
        "exchange"          # Trading and exchange
        "lending"           # P2P lending
        "wallet"            # Digital wallets
        "treasury"          # Treasury management
        "stablecoin"        # Stablecoin operations
        "custody"           # Asset custody

        # Operational Domains
        "compliance"        # KYC/AML/Sanctions
        "fraud"             # Fraud detection
        "regulatory"        # Regulatory reporting
        "identity"          # Identity verification
        "notification"      # Notifications
        "webhook"           # Webhook delivery

        # Regional Domains
        "islamic_finance"   # Islamic banking
        "gcc_compliance"    # GCC-specific regulations

        # Supporting Domains
        "user"              # User management
        "tenant"            # Multi-tenancy
        "audit"             # Audit logging
        "pricing"           # Fee calculations
    )

    for domain in "${domains[@]}"; do
        mkdir -p "internal/domain/${domain}"/{aggregate,entity,valueobject,event,repository,service,saga}
    done

    # Infrastructure layer
    log_info "Creating infrastructure structure..."

    infra_components=(
        "persistence/postgres"
        "persistence/redis"
        "messaging/kafka"
        "messaging/nats"
        "eventstore/eventhorizon"
        "ledger/blnk"
        "ledger/formance"
        "ledger/internal"
        "payment/moov"
        "payment/stripe"
        "compliance/watchman"
        "blockchain/ethereum"
        "blockchain/bitcoin"
        "workflow/temporal"
        "workflow/embedded"
        "observability/otel"
        "cache"
        "queue"
        "search"
        "storage"
    )

    for component in "${infra_components[@]}"; do
        mkdir -p "internal/infrastructure/${component}"
    done

    # Application layer (Use Cases / CQRS)
    log_info "Creating application layer structure..."

    mkdir -p internal/application/{command,query,saga,workflow,dto}

    # Interface layer (API, gRPC, GraphQL)
    log_info "Creating interface layer structure..."

    mkdir -p internal/interfaces/{rest,grpc,graphql,cli,event}
    mkdir -p internal/interfaces/rest/{handler,middleware,dto}
    mkdir -p internal/interfaces/grpc/handler
    mkdir -p internal/interfaces/graphql/{resolver,schema}

    # Shared kernel
    log_info "Creating shared kernel..."

    shared_components=(
        "kernel/money"
        "kernel/currency"
        "kernel/decimal"
        "kernel/id"
        "kernel/time"
        "cqrs/command"
        "cqrs/query"
        "cqrs/bus"
        "events/bus"
        "events/store"
        "errors"
        "validator"
        "logger"
        "config"
        "http"
        "database"
        "tenancy"
    )

    for component in "${shared_components[@]}"; do
        mkdir -p "internal/shared/${component}"
    done

    # Public packages (pkg)
    log_info "Creating public packages..."

    pkg_components=(
        "sdk/client"        # API client SDK
        "sdk/webhook"       # Webhook verification
        "sdk/errors"        # Public error types
        "utils/iso20022"    # ISO20022 helpers
        "utils/iban"        # IBAN validation
        "utils/crypto"      # Cryptography utilities
    )

    for component in "${pkg_components[@]}"; do
        mkdir -p "pkg/${component}"
    done

    # API definitions
    log_info "Creating API definitions..."

    mkdir -p api/{openapi,proto,graphql}
    mkdir -p api/proto/{account,payment,exchange,lending,wallet}

    # Commands (Entry points)
    log_info "Creating command entry points..."

    commands=(
        "api-server"        # Main REST/gRPC API
        "worker"            # Background workers
        "migrator"          # Database migrator
        "cli"               # CLI tool
        "event-consumer"    # Event consumer
        "webhook-delivery"  # Webhook delivery service
    )

    for cmd in "${commands[@]}"; do
        mkdir -p "cmd/${cmd}"
    done

    # Deployment configs
    log_info "Creating deployment configurations..."

    mkdir -p deployments/{docker,kubernetes,helm,terraform}
    mkdir -p deployments/kubernetes/{base,overlays/{dev,staging,prod}}

    # Test structure
    log_info "Creating test structure..."

    mkdir -p test/{integration,e2e,fixtures,mocks}

    # Configuration templates
    mkdir -p configs/{dev,staging,prod}

    log_info "Directory structure created successfully!"
}

# Initialize Go modules
init_go_modules() {
    log_info "Initializing Go modules..."

    go mod init "${MODULE_PATH}"

    # Add core dependencies
    log_info "Adding core dependencies..."

    # Web frameworks
    go get -u github.com/gin-gonic/gin
    go get -u google.golang.org/grpc
    go get -u google.golang.org/protobuf/cmd/protoc-gen-go
    go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc

    # Database
    go get -u gorm.io/gorm
    go get -u gorm.io/driver/postgres
    go get -u github.com/redis/go-redis/v9

    # Event sourcing & CQRS
    go get -u github.com/looplab/eventhorizon

    # Utilities
    go get -u github.com/shopspring/decimal
    go get -u github.com/google/uuid
    go get -u github.com/spf13/viper
    go get -u github.com/spf13/cobra

    # Observability
    go get -u go.uber.org/zap
    go get -u go.opentelemetry.io/otel
    go get -u go.opentelemetry.io/otel/sdk

    # Testing
    go get -u github.com/stretchr/testify

    # Moov financial libraries
    go get -u github.com/moov-io/ach
    go get -u github.com/moov-io/iso20022

    log_info "Go modules initialized!"
}

# Create core files
create_core_files() {
    log_info "Creating core files..."

    # Create README
    cat > README.md << 'EOF'
# FinAegis Go - Financial Infrastructure Platform

> Modern, scalable financial infrastructure for GCC/MENA region

## Overview

FinAegis is a production-ready financial infrastructure platform built with Golang, designed for:

- **Wealth Management** - Portfolio tracking, rebalancing, robo-advisory
- **Multi-Asset Brokerage** - Stocks, crypto, commodities trading
- **Digital Wallets** - Multi-currency, blockchain-enabled
- **Remittance** - Cross-border payments, FX optimization
- **Treasury** - Cash management, yield optimization
- **Islamic Finance** - Sharia-compliant products

## Architecture

- **Domain-Driven Design** - 20+ bounded contexts
- **Event Sourcing** - Complete audit trail
- **CQRS** - Optimized read/write models
- **Multi-Tenancy** - B2B, B2B2C support
- **Pluggable** - Swap ledgers, payment gateways seamlessly

## Quick Start

```bash
# Start local development environment
make dev

# Run tests
make test

# Build all services
make build

# Deploy to staging
make deploy-staging
```

## Documentation

- [Architecture Overview](docs/architecture/README.md)
- [API Reference](docs/api/README.md)
- [Development Guide](docs/development/README.md)
- [Deployment Guide](docs/deployment/README.md)

## Technology Stack

- **Language**: Go 1.23+
- **Ledger**: Blnk (pluggable)
- **Payment**: Moov ISO20022/ACH
- **Compliance**: Moov Watchman
- **Workflow**: Temporal (optional)
- **Event Store**: Event Horizon
- **Database**: PostgreSQL + Redis
- **API**: REST (Gin) + gRPC
- **Observability**: OpenTelemetry + Prometheus

## License

Copyright © 2025 FinAegis. All rights reserved.

Built with ❤️ for the GCC/MENA fintech ecosystem.
EOF

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Test coverage
*.out
coverage.html
coverage.txt

# Build artifacts
build/
vendor/

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# Environment
.env
.env.local
.env.*.local
*.pem
*.key
!testdata/**/*.key

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Temporary files
tmp/
temp/

# Database
*.db
*.sqlite

# Configuration (except templates)
configs/**/*.yaml
!configs/**/*.template.yaml
!configs/**/*.example.yaml
EOF

    # Create Makefile
    cat > Makefile << 'EOF'
.PHONY: help dev build test clean install-tools proto migrate-up migrate-down lint

# Variables
PROJECT_NAME := finaegis-go
GO_VERSION := 1.23
DOCKER_COMPOSE := docker-compose -f deployments/docker/docker-compose.yml

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-tools: ## Install development tools
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/pressly/goose/v3/cmd/goose@latest
	go install github.com/swaggo/swag/cmd/swag@latest

dev: ## Start local development environment
	$(DOCKER_COMPOSE) up -d
	@echo "Development environment started!"
	@echo "PostgreSQL: localhost:5432"
	@echo "Redis: localhost:6379"
	@echo "API: http://localhost:8080"

dev-down: ## Stop local development environment
	$(DOCKER_COMPOSE) down

build: ## Build all services
	@echo "Building services..."
	@mkdir -p bin
	go build -o bin/api-server ./cmd/api-server
	go build -o bin/worker ./cmd/worker
	go build -o bin/migrator ./cmd/migrator
	go build -o bin/cli ./cmd/cli

build-docker: ## Build Docker images
	docker build -t $(PROJECT_NAME)/api-server:latest -f deployments/docker/Dockerfile.api .
	docker build -t $(PROJECT_NAME)/worker:latest -f deployments/docker/Dockerfile.worker .

test: ## Run tests
	go test -v -race -coverprofile=coverage.out ./...

test-integration: ## Run integration tests
	go test -v -tags=integration ./test/integration/...

test-coverage: test ## Generate test coverage report
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

lint: ## Run linters
	golangci-lint run ./...

proto: ## Generate protobuf code
	@echo "Generating protobuf code..."
	@for dir in api/proto/*; do \
		if [ -d "$$dir" ]; then \
			protoc --go_out=. --go_opt=paths=source_relative \
				--go-grpc_out=. --go-grpc_opt=paths=source_relative \
				$$dir/*.proto; \
		fi \
	done

migrate-up: ## Run database migrations up
	cd migrations && goose postgres "user=postgres password=postgres dbname=finaegis sslmode=disable" up

migrate-down: ## Run database migrations down
	cd migrations && goose postgres "user=postgres password=postgres dbname=finaegis sslmode=disable" down

migrate-create: ## Create new migration (usage: make migrate-create NAME=create_users_table)
	cd migrations && goose create $(NAME) sql

swagger: ## Generate Swagger documentation
	swag init -g cmd/api-server/main.go -o api/openapi

clean: ## Clean build artifacts
	rm -rf bin/
	rm -rf dist/
	rm -rf coverage.out coverage.html
	go clean -cache

deps: ## Download dependencies
	go mod download
	go mod tidy

run-api: ## Run API server locally
	go run cmd/api-server/main.go

run-worker: ## Run worker locally
	go run cmd/worker/main.go

docker-build-all: ## Build all Docker images
	$(DOCKER_COMPOSE) build

docker-push: ## Push Docker images to registry
	docker push $(PROJECT_NAME)/api-server:latest
	docker push $(PROJECT_NAME)/worker:latest

deploy-staging: ## Deploy to staging
	kubectl apply -k deployments/kubernetes/overlays/staging

deploy-prod: ## Deploy to production
	kubectl apply -k deployments/kubernetes/overlays/prod

security-scan: ## Run security scan
	gosec ./...

fmt: ## Format code
	go fmt ./...
	goimports -w .

vet: ## Run go vet
	go vet ./...

check: fmt vet lint test ## Run all checks

.DEFAULT_GOAL := help
EOF

    # Create go.work for monorepo (optional)
    cat > go.work << EOF
go ${GO_VERSION}

use .
EOF

    log_info "Core files created!"
}

# Create sample domain files
create_sample_domain() {
    log_info "Creating sample domain files..."

    # Ledger abstraction (critical for pluggability)
    cat > internal/shared/kernel/money/money.go << 'EOF'
package money

import (
	"github.com/shopspring/decimal"
)

// Money represents a monetary amount with currency
type Money struct {
	Amount   decimal.Decimal
	Currency string
}

// NewMoney creates a new Money instance
func NewMoney(amount decimal.Decimal, currency string) Money {
	return Money{
		Amount:   amount,
		Currency: currency,
	}
}

// Add adds two Money instances (same currency)
func (m Money) Add(other Money) (Money, error) {
	if m.Currency != other.Currency {
		return Money{}, ErrCurrencyMismatch
	}
	return Money{
		Amount:   m.Amount.Add(other.Amount),
		Currency: m.Currency,
	}, nil
}

// Subtract subtracts two Money instances
func (m Money) Subtract(other Money) (Money, error) {
	if m.Currency != other.Currency {
		return Money{}, ErrCurrencyMismatch
	}
	return Money{
		Amount:   m.Amount.Sub(other.Amount),
		Currency: m.Currency,
	}, nil
}

// IsZero checks if amount is zero
func (m Money) IsZero() bool {
	return m.Amount.IsZero()
}

// IsPositive checks if amount is positive
func (m Money) IsPositive() bool {
	return m.Amount.GreaterThan(decimal.Zero)
}

// IsNegative checks if amount is negative
func (m Money) IsNegative() bool {
	return m.Amount.LessThan(decimal.Zero)
}
EOF

    cat > internal/shared/kernel/money/errors.go << 'EOF'
package money

import "errors"

var (
	ErrCurrencyMismatch = errors.New("currency mismatch")
	ErrInvalidAmount    = errors.New("invalid amount")
)
EOF

    # Ledger abstraction interface
    cat > internal/domain/ledger/service/ledger.go << 'EOF'
package service

import (
	"context"
	"time"

	"github.com/finaegis/finaegis-go/internal/shared/kernel/money"
)

// LedgerService defines the interface for ledger operations
// This abstraction allows switching between Blnk, Formance, or internal ledger
type LedgerService interface {
	// Account operations
	CreateAccount(ctx context.Context, req CreateAccountRequest) (*Account, error)
	GetAccount(ctx context.Context, accountID string) (*Account, error)
	GetBalance(ctx context.Context, accountID string, asOf *time.Time) (money.Money, error)

	// Transaction operations
	RecordEntry(ctx context.Context, req RecordEntryRequest) (*Entry, error)
	Transfer(ctx context.Context, req TransferRequest) (*Transaction, error)

	// Query operations
	GetTransactionHistory(ctx context.Context, accountID string, filters TransactionFilters) ([]*Transaction, error)
	GetBalanceHistory(ctx context.Context, accountID string, from, to time.Time) ([]*BalanceSnapshot, error)
}

// CreateAccountRequest represents account creation request
type CreateAccountRequest struct {
	AccountID    string
	AccountType  string
	Currency     string
	Metadata     map[string]interface{}
	TenantID     string
}

// Account represents a ledger account
type Account struct {
	ID          string
	Type        string
	Currency    string
	Balance     money.Money
	Metadata    map[string]interface{}
	TenantID    string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// RecordEntryRequest represents an entry recording request
type RecordEntryRequest struct {
	AccountID    string
	EntryType    EntryType
	Amount       money.Money
	Reference    string
	Description  string
	Metadata     map[string]interface{}
	IdempotencyKey string
}

// EntryType defines debit or credit
type EntryType string

const (
	EntryTypeDebit  EntryType = "debit"
	EntryTypeCredit EntryType = "credit"
)

// Entry represents a ledger entry
type Entry struct {
	ID             string
	AccountID      string
	Type           EntryType
	Amount         money.Money
	Reference      string
	Description    string
	Metadata       map[string]interface{}
	TransactionID  string
	CreatedAt      time.Time
}

// TransferRequest represents a transfer request
type TransferRequest struct {
	FromAccountID  string
	ToAccountID    string
	Amount         money.Money
	Reference      string
	Description    string
	Metadata       map[string]interface{}
	IdempotencyKey string
}

// Transaction represents a ledger transaction
type Transaction struct {
	ID             string
	Entries        []*Entry
	Reference      string
	Description    string
	Metadata       map[string]interface{}
	Status         TransactionStatus
	CreatedAt      time.Time
	CompletedAt    *time.Time
}

// TransactionStatus defines transaction states
type TransactionStatus string

const (
	TransactionStatusPending   TransactionStatus = "pending"
	TransactionStatusCompleted TransactionStatus = "completed"
	TransactionStatusFailed    TransactionStatus = "failed"
)

// TransactionFilters for querying transactions
type TransactionFilters struct {
	FromDate   *time.Time
	ToDate     *time.Time
	Status     *TransactionStatus
	Reference  *string
	Limit      int
	Offset     int
}

// BalanceSnapshot represents balance at a point in time
type BalanceSnapshot struct {
	AccountID string
	Balance   money.Money
	Timestamp time.Time
}
EOF

    # Blnk implementation (pluggable)
    cat > internal/infrastructure/ledger/blnk/blnk.go << 'EOF'
package blnk

import (
	"context"

	"github.com/finaegis/finaegis-go/internal/domain/ledger/service"
)

// BlnkLedger implements LedgerService using Blnk
type BlnkLedger struct {
	// Blnk client configuration
}

// NewBlnkLedger creates a new Blnk ledger instance
func NewBlnkLedger() *BlnkLedger {
	return &BlnkLedger{}
}

// CreateAccount implements ledger account creation
func (b *BlnkLedger) CreateAccount(ctx context.Context, req service.CreateAccountRequest) (*service.Account, error) {
	// TODO: Implement Blnk account creation
	panic("not implemented")
}

// GetAccount retrieves account details
func (b *BlnkLedger) GetAccount(ctx context.Context, accountID string) (*service.Account, error) {
	// TODO: Implement
	panic("not implemented")
}

// GetBalance retrieves account balance
func (b *BlnkLedger) GetBalance(ctx context.Context, accountID string, asOf *time.Time) (money.Money, error) {
	// TODO: Implement
	panic("not implemented")
}

// RecordEntry records a ledger entry
func (b *BlnkLedger) RecordEntry(ctx context.Context, req service.RecordEntryRequest) (*service.Entry, error) {
	// TODO: Implement
	panic("not implemented")
}

// Transfer performs a transfer between accounts
func (b *BlnkLedger) Transfer(ctx context.Context, req service.TransferRequest) (*service.Transaction, error) {
	// TODO: Implement Blnk transfer logic
	panic("not implemented")
}

// GetTransactionHistory retrieves transaction history
func (b *BlnkLedger) GetTransactionHistory(ctx context.Context, accountID string, filters service.TransactionFilters) ([]*service.Transaction, error) {
	// TODO: Implement
	panic("not implemented")
}

// GetBalanceHistory retrieves balance history
func (b *BlnkLedger) GetBalanceHistory(ctx context.Context, accountID string, from, to time.Time) ([]*service.BalanceSnapshot, error) {
	// TODO: Implement
	panic("not implemented")
}
EOF

    # Multi-tenancy abstraction
    cat > internal/shared/tenancy/context.go << 'EOF'
package tenancy

import (
	"context"
	"errors"
)

type contextKey string

const tenantContextKey contextKey = "tenant_id"

var ErrNoTenantInContext = errors.New("no tenant in context")

// WithTenant adds tenant ID to context
func WithTenant(ctx context.Context, tenantID string) context.Context {
	return context.WithValue(ctx, tenantContextKey, tenantID)
}

// FromContext retrieves tenant ID from context
func FromContext(ctx context.Context) (string, error) {
	tenantID, ok := ctx.Value(tenantContextKey).(string)
	if !ok {
		return "", ErrNoTenantInContext
	}
	return tenantID, nil
}

// MustFromContext retrieves tenant ID or panics
func MustFromContext(ctx context.Context) string {
	tenantID, err := FromContext(ctx)
	if err != nil {
		panic(err)
	}
	return tenantID
}
EOF

    # CQRS Command Bus
    cat > internal/shared/cqrs/bus/command_bus.go << 'EOF'
package bus

import (
	"context"
	"errors"
	"reflect"
)

var ErrHandlerNotFound = errors.New("handler not found for command")

// Command marker interface
type Command interface {
	CommandName() string
}

// CommandHandler processes commands
type CommandHandler interface {
	Handle(ctx context.Context, cmd Command) error
}

// CommandBus dispatches commands to handlers
type CommandBus struct {
	handlers map[reflect.Type]CommandHandler
}

// NewCommandBus creates a new command bus
func NewCommandBus() *CommandBus {
	return &CommandBus{
		handlers: make(map[reflect.Type]CommandHandler),
	}
}

// Register registers a command handler
func (b *CommandBus) Register(cmd Command, handler CommandHandler) {
	cmdType := reflect.TypeOf(cmd)
	b.handlers[cmdType] = handler
}

// Dispatch dispatches a command to its handler
func (b *CommandBus) Dispatch(ctx context.Context, cmd Command) error {
	cmdType := reflect.TypeOf(cmd)
	handler, ok := b.handlers[cmdType]
	if !ok {
		return ErrHandlerNotFound
	}
	return handler.Handle(ctx, cmd)
}
EOF

    log_info "Sample domain files created!"
}

# Create Docker files
create_docker_files() {
    log_info "Creating Docker files..."

    # Development docker-compose
    cat > deployments/docker/docker-compose.yml << 'EOF'
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: finaegis-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: finaegis
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: finaegis-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    container_name: finaegis-kafka
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_LOG_DIRS: /tmp/kraft-combined-logs
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
    volumes:
      - kafka_data:/var/lib/kafka/data

  jaeger:
    image: jaegertracing/all-in-one:1.54
    container_name: finaegis-jaeger
    ports:
      - "16686:16686"  # UI
      - "4318:4318"    # OTLP HTTP
    environment:
      COLLECTOR_OTLP_ENABLED: true

  prometheus:
    image: prom/prometheus:latest
    container_name: finaegis-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

volumes:
  postgres_data:
  redis_data:
  kafka_data:
  prometheus_data:
EOF

    # API Server Dockerfile
    cat > deployments/docker/Dockerfile.api << 'EOF'
# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o /build/bin/api-server \
    ./cmd/api-server

# Runtime stage
FROM alpine:latest

# Install CA certificates for HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/bin/api-server .

# Copy configuration templates
COPY --from=builder /build/configs ./configs

# Change ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run
ENTRYPOINT ["/app/api-server"]
EOF

    # Worker Dockerfile
    cat > deployments/docker/Dockerfile.worker << 'EOF'
# Build stage
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git make gcc musl-dev

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o /build/bin/worker \
    ./cmd/worker

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

COPY --from=builder /build/bin/worker .
COPY --from=builder /build/configs ./configs

RUN chown -R app:app /app

USER app

ENTRYPOINT ["/app/worker"]
EOF

    # Prometheus config
    cat > deployments/docker/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'finaegis-api'
    static_configs:
      - targets: ['host.docker.internal:8080']
EOF

    log_info "Docker files created!"
}

# Create configuration templates
create_config_templates() {
    log_info "Creating configuration templates..."

    cat > configs/dev/config.yaml << 'EOF'
# Development Configuration
server:
  host: 0.0.0.0
  port: 8080
  mode: debug
  read_timeout: 30s
  write_timeout: 30s

database:
  postgres:
    host: localhost
    port: 5432
    user: postgres
    password: postgres
    database: finaegis
    ssl_mode: disable
    max_connections: 25
    max_idle_connections: 5

  redis:
    host: localhost
    port: 6379
    password: ""
    db: 0

# Ledger configuration (pluggable)
ledger:
  provider: internal  # Options: internal, blnk, formance
  internal:
    event_sourcing: true
  blnk:
    url: http://localhost:5001
    api_key: ""
  formance:
    url: http://localhost:3068
    organization: ""
    api_key: ""

# Payment providers (pluggable)
payment:
  providers:
    - name: moov
      enabled: true
      config:
        api_url: http://localhost:8082
    - name: stripe
      enabled: false
      config:
        api_key: sk_test_
        webhook_secret: whsec_

# Compliance
compliance:
  watchman:
    enabled: true
    url: http://localhost:9094
  kyc:
    provider: sumsub  # Options: sumsub, onfido, jumio
    api_key: ""

# Multi-tenancy
tenancy:
  mode: shared_schema  # Options: shared_schema, schema_per_tenant, db_per_tenant
  default_tenant: default

# Observability
observability:
  logging:
    level: debug
    format: json
  tracing:
    enabled: true
    endpoint: http://localhost:4318
    service_name: finaegis-api
  metrics:
    enabled: true
    port: 9091

# Messaging
messaging:
  provider: kafka  # Options: kafka, nats, rabbitmq
  kafka:
    brokers:
      - localhost:9092
    consumer_group: finaegis

# Feature flags
features:
  islamic_finance: true
  gcc_compliance: true
  robo_advisory: false
  social_trading: false
EOF

    log_info "Configuration templates created!"
}

# Create documentation
create_docs() {
    log_info "Creating documentation structure..."

    mkdir -p docs/{architecture,api,development,deployment,security}

    cat > docs/architecture/README.md << 'EOF'
# Architecture Overview

## Domain-Driven Design

FinAegis follows Domain-Driven Design principles with clear bounded contexts:

### Core Domains

1. **Account** - Account management and hierarchies
2. **Ledger** - Double-entry bookkeeping (abstracted)
3. **Payment** - Payment processing and rails
4. **Exchange** - Trading and liquidity
5. **Lending** - P2P lending platform
6. **Wallet** - Digital wallets and blockchain
7. **Treasury** - Portfolio and cash management

### Supporting Domains

8. **Compliance** - KYC/AML/Sanctions
9. **Fraud** - Fraud detection and prevention
10. **Identity** - Identity verification
11. **Tenant** - Multi-tenancy management

### Regional Domains

12. **Islamic Finance** - Sharia-compliant products
13. **GCC Compliance** - Regional regulations

## Hexagonal Architecture

```
┌─────────────────────────────────────────────┐
│           Interfaces Layer                  │
│  (REST, gRPC, GraphQL, CLI, Events)        │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│         Application Layer                   │
│  (Commands, Queries, Sagas, Workflows)     │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│           Domain Layer                      │
│  (Aggregates, Entities, Value Objects)     │
│  (Events, Services, Repositories)          │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│       Infrastructure Layer                  │
│  (Postgres, Redis, Kafka, External APIs)   │
└─────────────────────────────────────────────┘
```

## Event Sourcing & CQRS

- All state changes captured as events
- Separate read and write models
- Complete audit trail
- Replay capability

## Multi-Tenancy

Support for three isolation strategies:

1. **Shared Schema** - tenant_id column (default)
2. **Schema Per Tenant** - PostgreSQL schemas
3. **Database Per Tenant** - Separate databases

## Pluggability

### Ledger Abstraction

```go
type LedgerService interface {
    CreateAccount(...)
    Transfer(...)
    GetBalance(...)
}

// Implementations:
- InternalLedger (event-sourced)
- BlnkLedger (Blnk integration)
- FormanceLedger (Formance integration)
```

### Payment Abstraction

Similar pattern for payment providers, compliance services, etc.

## Scalability

- Horizontal scaling via stateless services
- Event-driven architecture
- Caching with Redis
- Database read replicas
- Async processing with Kafka
EOF

    cat > docs/development/README.md << 'EOF'
# Development Guide

## Prerequisites

- Go 1.23+
- Docker & Docker Compose
- Make
- PostgreSQL 16+ (for local dev)
- Redis 7+

## Getting Started

```bash
# Clone repository
git clone <repo>
cd finaegis-go

# Install development tools
make install-tools

# Start local environment
make dev

# Run migrations
make migrate-up

# Run tests
make test

# Run API server
make run-api
```

## Project Structure

```
.
├── cmd/                    # Entry points
├── internal/               # Private application code
│   ├── domain/            # Domain layer (DDD)
│   ├── infrastructure/    # Infrastructure implementations
│   ├── interfaces/        # API handlers
│   ├── application/       # Use cases (CQRS)
│   └── shared/            # Shared kernel
├── pkg/                    # Public libraries
├── api/                    # API definitions
├── migrations/             # Database migrations
├── deployments/            # Deployment configs
└── test/                   # Integration tests
```

## Coding Standards

- Follow Go best practices
- Use `gofmt` and `goimports`
- Write tests for all business logic
- Document public APIs
- Use meaningful variable names

## Testing

```bash
# Unit tests
make test

# Integration tests
make test-integration

# Coverage report
make test-coverage

# Run specific test
go test -v ./internal/domain/account/...
```

## Adding a New Domain

1. Create domain structure:
   ```bash
   mkdir -p internal/domain/mydomain/{aggregate,entity,event,service}
   ```

2. Define domain interfaces

3. Implement aggregates with event sourcing

4. Create commands and queries

5. Add integration tests

## Database Migrations

```bash
# Create migration
make migrate-create NAME=add_users_table

# Run migrations
make migrate-up

# Rollback
make migrate-down
```
EOF

    log_info "Documentation created!"
}

# Main execution
main() {
    print_banner

    check_prerequisites

    echo ""
    read -p "Project name (default: finaegis-go): " input_name
    if [ ! -z "$input_name" ]; then
        PROJECT_NAME="$input_name"
    fi

    read -p "Go module path (default: github.com/finaegis/${PROJECT_NAME}): " input_module
    if [ ! -z "$input_module" ]; then
        MODULE_PATH="$input_module"
    fi

    echo ""
    log_info "Creating project: ${PROJECT_NAME}"
    log_info "Module path: ${MODULE_PATH}"
    echo ""

    create_directory_structure

    # Navigate into project directory
    cd "${PROJECT_NAME}"

    init_go_modules
    create_core_files
    create_sample_domain
    create_docker_files
    create_config_templates
    create_docs

    # Initialize git
    git init
    git add .
    git commit -m "Initial commit: Bootstrap FinAegis Go monorepo

🚀 Generated with FinAegis Bootstrap Script v1.0.0

Features:
- Domain-Driven Design with 20+ domains
- Event Sourcing & CQRS
- Pluggable ledger abstraction
- Multi-tenancy support
- GCC/MENA compliance ready
- Production-ready infrastructure"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║           🎉  Project Created Successfully!  🎉               ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Next steps:"
    echo "  1. cd ${PROJECT_NAME}"
    echo "  2. make install-tools"
    echo "  3. make dev"
    echo "  4. make migrate-up"
    echo "  5. make run-api"
    echo ""
    log_info "Documentation: docs/"
    log_info "API will run on: http://localhost:8080"
    echo ""
    log_info "Happy coding! 🚀"
}

# Run main function
main "$@"
