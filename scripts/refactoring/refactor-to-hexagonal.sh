#!/bin/bash

# Refactoring Automation Script for Hexagonal Architecture Migration
# Purpose: Automate common refactoring tasks for Phase 0 & Phase 1
# Usage: ./scripts/refactoring/refactor-to-hexagonal.sh [command]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Helper functions
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function: Check for vendor imports in domain layer
check_vendor_imports() {
    info "Checking for vendor imports in domain layer..."

    local violations=0

    # Check for Formance imports
    if grep -r "github.com/formancehq" internal/domain/ 2>/dev/null; then
        error "Found Formance imports in domain layer!"
        violations=$((violations + 1))
    fi

    # Check for Ory imports
    if grep -r "github.com/ory" internal/domain/ 2>/dev/null; then
        error "Found Ory imports in domain layer!"
        violations=$((violations + 1))
    fi

    # Check for GORM imports
    if grep -r "gorm.io/gorm" internal/domain/ 2>/dev/null; then
        error "Found GORM imports in domain layer!"
        violations=$((violations + 1))
    fi

    # Check for Redis imports
    if grep -r "github.com/redis/go-redis" internal/domain/ 2>/dev/null; then
        error "Found Redis imports in domain layer!"
        violations=$((violations + 1))
    fi

    # Check for Event Horizon imports (should only be in adapters)
    if grep -r "github.com/looplab/eventhorizon" internal/domain/ 2>/dev/null | grep -v "// TODO: Refactor"; then
        warning "Found Event Horizon imports in domain layer (should be in adapters)"
        violations=$((violations + 1))
    fi

    if [ $violations -eq 0 ]; then
        success "No vendor imports found in domain layer!"
        return 0
    else
        error "Found $violations vendor import violation(s)"
        return 1
    fi
}

# Function: Check for infrastructure imports in domain layer
check_infrastructure_imports() {
    info "Checking for infrastructure imports in domain layer..."

    if grep -r "internal/infrastructure" internal/domain/ 2>/dev/null; then
        error "Found infrastructure imports in domain layer!"
        return 1
    else
        success "No infrastructure imports in domain layer!"
        return 0
    fi
}

# Function: Create ports directory structure
create_ports_structure() {
    info "Creating ports directory structure..."

    # Shared ports
    mkdir -p internal/domain/shared/ports

    # Domain-specific ports (based on GOLANG_MIGRATION_TASKS.md)
    for domain in account payment exchange treasury lending stablecoin wallet compliance governance ai; do
        mkdir -p "internal/domain/$domain/ports"
        success "Created ports directory for $domain domain"
    done

    success "Ports directory structure created!"
}

# Function: Create adapters directory structure
create_adapters_structure() {
    info "Creating adapters directory structure..."

    # Infrastructure adapters
    mkdir -p internal/infrastructure/adapters/{wallet,ledger,authz,identity,eventstore,eventbus,gateway,workflow,logger,config,isolation}

    success "Adapters directory structure created!"
}

# Function: Generate port interface template
generate_port_template() {
    local domain=$1
    local port_name=$2
    local file_path="internal/domain/$domain/ports/${port_name,,}.go"

    if [ -f "$file_path" ]; then
        warning "Port file already exists: $file_path"
        return 0
    fi

    cat > "$file_path" <<EOF
package ports

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/shopspring/decimal"
)

// ${port_name} defines the interface for ${port_name,,} operations
// This interface is defined BY the domain layer and implemented BY the infrastructure layer
type ${port_name} interface {
    // TODO: Define interface methods
}

// TODO: Define domain types (vendor-agnostic value objects)

EOF

    success "Generated port template: $file_path"
}

# Function: Generate adapter template
generate_adapter_template() {
    local adapter_type=$1
    local adapter_name=$2
    local file_path="internal/infrastructure/adapters/$adapter_type/${adapter_name,,}_adapter.go"

    if [ -f "$file_path" ]; then
        warning "Adapter file already exists: $file_path"
        return 0
    fi

    mkdir -p "internal/infrastructure/adapters/$adapter_type"

    cat > "$file_path" <<EOF
package ${adapter_type}

import (
    "context"
    "fmt"

    "github.com/mstfajbr/finaegis-go/internal/domain/shared/ports"
)

// ${adapter_name}Adapter implements the ${adapter_type} port
type ${adapter_name}Adapter struct {
    // TODO: Add vendor-specific client/dependencies
}

// New${adapter_name}Adapter creates a new ${adapter_name} adapter
func New${adapter_name}Adapter( /* TODO: Add config params */ ) *${adapter_name}Adapter {
    return &${adapter_name}Adapter{
        // TODO: Initialize
    }
}

// TODO: Implement interface methods

EOF

    success "Generated adapter template: $file_path"
}

# Function: Find direct vendor usages
find_vendor_usages() {
    info "Searching for direct vendor usages..."

    echo ""
    echo "=== Formance Client Usages ==="
    grep -rn "formanceClient" internal/application/ internal/domain/ 2>/dev/null || echo "None found"

    echo ""
    echo "=== Ory Kratos Client Usages ==="
    grep -rn "kratosClient" internal/application/ internal/domain/ 2>/dev/null || echo "None found"

    echo ""
    echo "=== Ory Keto Client Usages ==="
    grep -rn "ketoClient" internal/application/ internal/domain/ 2>/dev/null || echo "None found"

    echo ""
    echo "=== Direct Event Horizon Usages ==="
    grep -rn "eventhorizon\\.AggregateBase" internal/domain/ 2>/dev/null || echo "None found"

    echo ""
    echo "=== Direct GORM Usages ==="
    grep -rn "\\*gorm\\.DB" internal/domain/ internal/application/ 2>/dev/null || echo "None found"
}

# Function: Generate DI container template
generate_di_container() {
    local file_path="internal/infrastructure/config/container.go"

    if [ -f "$file_path" ]; then
        warning "Container file already exists: $file_path"
        return 0
    fi

    mkdir -p internal/infrastructure/config

    cat > "$file_path" <<EOF
package config

import (
    "fmt"

    // Shared ports
    sharedports "github.com/mstfajbr/finaegis-go/internal/domain/shared/ports"

    // Domain ports
    accountports "github.com/mstfajbr/finaegis-go/internal/domain/account/ports"

    // Adapters
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/wallet"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/ledger"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/authz"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/identity"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/eventstore"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/eventbus"
    "github.com/mstfajbr/finaegis-go/internal/infrastructure/adapters/logger"

    // Application services
    "github.com/mstfajbr/finaegis-go/internal/application/service"
)

// Container holds all application dependencies
type Container struct {
    // Shared infrastructure ports
    EventStore      sharedports.EventStore
    EventBus        sharedports.EventBus
    Logger          sharedports.Logger
    Config          sharedports.ConfigProvider
    TenantIsolation sharedports.TenantIsolationProvider

    // Domain-specific ports
    WalletService  accountports.WalletService
    LedgerService  accountports.LedgerService
    AuthzProvider  accountports.AuthorizationProvider
    IdentityProvider sharedports.IdentityProvider

    // Application services
    AccountService *service.AccountService
}

// NewContainer creates and wires all dependencies
func NewContainer(cfg Config) (*Container, error) {
    c := &Container{}

    // Wire adapters
    if err := c.wireLogger(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire logger: %w", err)
    }

    if err := c.wireEventStore(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire event store: %w", err)
    }

    if err := c.wireEventBus(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire event bus: %w", err)
    }

    if err := c.wireTenantIsolation(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire tenant isolation: %w", err)
    }

    if err := c.wireWalletService(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire wallet service: %w", err)
    }

    if err := c.wireLedgerService(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire ledger service: %w", err)
    }

    if err := c.wireAuthzProvider(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire authz provider: %w", err)
    }

    if err := c.wireIdentityProvider(cfg); err != nil {
        return nil, fmt.Errorf("failed to wire identity provider: %w", err)
    }

    // Wire application services
    c.wireApplicationServices()

    return c, nil
}

func (c *Container) wireLogger(cfg Config) error {
    switch cfg.LoggerProvider {
    case "zap":
        c.Logger = logger.NewZapLoggerAdapter(cfg.ZapConfig)
    case "inmemory":
        c.Logger = logger.NewInMemoryLoggerAdapter()
    default:
        c.Logger = logger.NewZapLoggerAdapter(cfg.ZapConfig)
    }
    return nil
}

func (c *Container) wireEventStore(cfg Config) error {
    switch cfg.EventStoreProvider {
    case "eventhorizon":
        c.EventStore = eventstore.NewEventHorizonAdapter(cfg.EventHorizonConfig)
    case "postgres":
        c.EventStore = eventstore.NewPostgresEventStoreAdapter(cfg.PostgresConfig)
    case "inmemory":
        c.EventStore = eventstore.NewInMemoryEventStoreAdapter()
    default:
        c.EventStore = eventstore.NewEventHorizonAdapter(cfg.EventHorizonConfig)
    }
    return nil
}

func (c *Container) wireEventBus(cfg Config) error {
    switch cfg.EventBusProvider {
    case "redis":
        c.EventBus = eventbus.NewRedisEventBusAdapter(cfg.RedisConfig)
    case "inmemory":
        c.EventBus = eventbus.NewInMemoryEventBusAdapter()
    default:
        c.EventBus = eventbus.NewRedisEventBusAdapter(cfg.RedisConfig)
    }
    return nil
}

func (c *Container) wireTenantIsolation(cfg Config) error {
    // TODO: Implement
    return nil
}

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

func (c *Container) wireLedgerService(cfg Config) error {
    switch cfg.LedgerProvider {
    case "formance":
        c.LedgerService = ledger.NewFormanceLedgerAdapter(
            cfg.FormanceConfig.APIKey,
            cfg.FormanceConfig.BaseURL,
        )
    case "custom":
        c.LedgerService = ledger.NewCustomLedgerAdapter(cfg.CustomLedgerConfig)
    case "inmemory":
        c.LedgerService = ledger.NewInMemoryLedgerAdapter()
    default:
        c.LedgerService = ledger.NewFormanceLedgerAdapter(
            cfg.FormanceConfig.APIKey,
            cfg.FormanceConfig.BaseURL,
        )
    }
    return nil
}

func (c *Container) wireAuthzProvider(cfg Config) error {
    switch cfg.AuthzProvider {
    case "ory-keto":
        c.AuthzProvider = authz.NewOryKetoAdapter(cfg.OryConfig.KetoURL)
    case "casbin":
        c.AuthzProvider = authz.NewCasbinAdapter(
            cfg.CasbinConfig.ModelPath,
            cfg.CasbinConfig.PolicyPath,
        )
    case "opa":
        c.AuthzProvider = authz.NewOPAAdapter(cfg.OPAConfig.URL)
    case "inmemory":
        c.AuthzProvider = authz.NewInMemoryAuthzAdapter()
    default:
        c.AuthzProvider = authz.NewOryKetoAdapter(cfg.OryConfig.KetoURL)
    }
    return nil
}

func (c *Container) wireIdentityProvider(cfg Config) error {
    switch cfg.IdentityProvider {
    case "ory-kratos":
        c.IdentityProvider = identity.NewOryKratosAdapter(cfg.OryConfig.KratosURL)
    case "auth0":
        c.IdentityProvider = identity.NewAuth0Adapter(
            cfg.Auth0Config.Domain,
            cfg.Auth0Config.ClientID,
            cfg.Auth0Config.ClientSecret,
        )
    case "keycloak":
        c.IdentityProvider = identity.NewKeycloakAdapter(cfg.KeycloakConfig.URL)
    case "inmemory":
        c.IdentityProvider = identity.NewInMemoryIdentityAdapter()
    default:
        c.IdentityProvider = identity.NewOryKratosAdapter(cfg.OryConfig.KratosURL)
    }
    return nil
}

func (c *Container) wireApplicationServices() {
    // TODO: Wire application services with injected dependencies
    // Example:
    // c.AccountService = service.NewAccountService(
    //     c.WalletService,
    //     c.LedgerService,
    //     c.AuthzProvider,
    //     c.EventBus,
    //     c.Logger,
    // )
}

EOF

    success "Generated DI container template: $file_path"
}

# Function: Generate config struct
generate_config_struct() {
    local file_path="internal/infrastructure/config/config.go"

    if [ -f "$file_path" ]; then
        warning "Config file already exists: $file_path"
        return 0
    fi

    cat > "$file_path" <<EOF
package config

// Config holds all application configuration
type Config struct {
    // Environment
    Environment string // "development", "staging", "production"

    // Adapter selection
    EventStoreProvider      string // "eventhorizon", "postgres", "inmemory"
    EventBusProvider        string // "redis", "inmemory"
    LoggerProvider          string // "zap", "logrus", "inmemory"
    TenantIsolationProvider string // "postgres", "inmemory"

    // Phase 1 specific
    WalletProvider   string // "formance", "tigerbeetle", "inmemory"
    LedgerProvider   string // "formance", "custom", "inmemory"
    AuthzProvider    string // "ory-keto", "casbin", "opa", "inmemory"
    IdentityProvider string // "ory-kratos", "auth0", "keycloak", "inmemory"

    // Vendor-specific configs
    EventHorizonConfig EventHorizonConfig
    PostgresConfig     PostgresConfig
    RedisConfig        RedisConfig
    ZapConfig          ZapConfig
    FormanceConfig     FormanceConfig
    OryConfig          OryConfig
    TigerBeetleConfig  TigerBeetleConfig
    CasbinConfig       CasbinConfig
    OPAConfig          OPAConfig
    Auth0Config        Auth0Config
    KeycloakConfig     KeycloakConfig
}

// EventHorizonConfig holds Event Horizon configuration
type EventHorizonConfig struct {
    // TODO: Add Event Horizon config fields
}

// PostgresConfig holds PostgreSQL configuration
type PostgresConfig struct {
    Host     string
    Port     int
    Database string
    Username string
    Password string
    SSLMode  string
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
    Host     string
    Port     int
    Password string
    DB       int
}

// ZapConfig holds Zap logger configuration
type ZapConfig struct {
    Level      string // "debug", "info", "warn", "error"
    OutputPath string
}

// FormanceConfig holds Formance configuration
type FormanceConfig struct {
    APIKey  string
    BaseURL string
}

// OryConfig holds Ory stack configuration
type OryConfig struct {
    KratosURL      string
    KetoURL        string
    OathkeeperURL  string
}

// TigerBeetleConfig holds TigerBeetle configuration
type TigerBeetleConfig struct {
    ClusterID uint128
    Addresses []string
}

// CasbinConfig holds Casbin configuration
type CasbinConfig struct {
    ModelPath  string
    PolicyPath string
}

// OPAConfig holds Open Policy Agent configuration
type OPAConfig struct {
    URL string
}

// Auth0Config holds Auth0 configuration
type Auth0Config struct {
    Domain       string
    ClientID     string
    ClientSecret string
}

// KeycloakConfig holds Keycloak configuration
type KeycloakConfig struct {
    URL          string
    Realm        string
    ClientID     string
    ClientSecret string
}

// LoadConfig loads configuration from environment variables
func LoadConfig() Config {
    // TODO: Implement config loading from env vars / config files
    return Config{}
}

EOF

    success "Generated config struct: $file_path"
}

# Function: Run validation checks
run_validation() {
    info "Running validation checks..."

    local failed=0

    echo ""
    echo "=== Validation Results ==="
    echo ""

    # Check 1: Vendor imports in domain
    if ! check_vendor_imports; then
        failed=$((failed + 1))
    fi
    echo ""

    # Check 2: Infrastructure imports in domain
    if ! check_infrastructure_imports; then
        failed=$((failed + 1))
    fi
    echo ""

    # Check 3: Ports directory exists
    if [ ! -d "internal/domain/shared/ports" ]; then
        error "Shared ports directory does not exist"
        failed=$((failed + 1))
    else
        success "Shared ports directory exists"
    fi
    echo ""

    # Check 4: Adapters directory exists
    if [ ! -d "internal/infrastructure/adapters" ]; then
        error "Adapters directory does not exist"
        failed=$((failed + 1))
    else
        success "Adapters directory exists"
    fi
    echo ""

    # Check 5: DI container exists
    if [ ! -f "internal/infrastructure/config/container.go" ]; then
        warning "DI container does not exist yet"
        failed=$((failed + 1))
    else
        success "DI container exists"
    fi
    echo ""

    if [ $failed -eq 0 ]; then
        success "All validation checks passed!"
        return 0
    else
        error "$failed validation check(s) failed"
        return 1
    fi
}

# Function: Show help
show_help() {
    cat <<EOF
Refactoring Automation Script for Hexagonal Architecture Migration

USAGE:
    ./scripts/refactoring/refactor-to-hexagonal.sh [COMMAND]

COMMANDS:
    check-imports          Check for vendor imports in domain layer
    check-infra            Check for infrastructure imports in domain layer
    create-structure       Create ports and adapters directory structure
    generate-port          Generate a port interface template
    generate-adapter       Generate an adapter template
    generate-container     Generate DI container template
    generate-config        Generate config struct template
    find-usages            Find direct vendor usages in code
    validate               Run all validation checks
    help                   Show this help message

EXAMPLES:
    # Check for vendor imports
    ./scripts/refactoring/refactor-to-hexagonal.sh check-imports

    # Create directory structure
    ./scripts/refactoring/refactor-to-hexagonal.sh create-structure

    # Generate WalletService port
    ./scripts/refactoring/refactor-to-hexagonal.sh generate-port account WalletService

    # Generate Formance wallet adapter
    ./scripts/refactoring/refactor-to-hexagonal.sh generate-adapter wallet FormanceWallet

    # Generate DI container
    ./scripts/refactoring/refactor-to-hexagonal.sh generate-container

    # Run validation
    ./scripts/refactoring/refactor-to-hexagonal.sh validate

EOF
}

# Main script logic
main() {
    local command=${1:-help}

    case $command in
        check-imports)
            check_vendor_imports
            ;;
        check-infra)
            check_infrastructure_imports
            ;;
        create-structure)
            create_ports_structure
            create_adapters_structure
            ;;
        generate-port)
            if [ -z "$2" ] || [ -z "$3" ]; then
                error "Usage: generate-port <domain> <PortName>"
                exit 1
            fi
            generate_port_template "$2" "$3"
            ;;
        generate-adapter)
            if [ -z "$2" ] || [ -z "$3" ]; then
                error "Usage: generate-adapter <adapter_type> <AdapterName>"
                exit 1
            fi
            generate_adapter_template "$2" "$3"
            ;;
        generate-container)
            generate_di_container
            generate_config_struct
            ;;
        generate-config)
            generate_config_struct
            ;;
        find-usages)
            find_vendor_usages
            ;;
        validate)
            run_validation
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
