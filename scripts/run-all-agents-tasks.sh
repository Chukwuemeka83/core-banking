#!/usr/bin/env bash

################################################################################
# 🤖 FinAegis Core Banking - Full Agents Tasks Automation Script
# ============================================================================
# This script automates all tasks from AGENTS.md
# - Environment Setup
# - Dependency Installation
# - Database Migration & Seeding
# - Asset Building
# - Testing & Coverage
# - Code Quality Checks
# - API Documentation
# - Development Server Startup
#
# Usage:
#   chmod +x scripts/run-all-agents-tasks.sh
#   ./scripts/run-all-agents-tasks.sh [OPTIONS]
#
# Options:
#   --help          Show this help message
#   --skip-tests    Skip running tests
#   --skip-quality  Skip code quality checks
#   --skip-npm      Skip npm install
#   --skip-composer Skip composer install
#   --no-serve      Don't start dev servers
################################################################################

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TASKS_COMPLETED=0
TASKS_TOTAL=0
SKIP_TESTS=false
SKIP_QUALITY=false
SKIP_NPM=false
SKIP_COMPOSER=false
NO_SERVE=false
START_TIME=$(date +%s)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) show_help; exit 0 ;;
        --skip-tests) SKIP_TESTS=true; shift ;;
        --skip-quality) SKIP_QUALITY=true; shift ;;
        --skip-npm) SKIP_NPM=true; shift ;;
        --skip-composer) SKIP_COMPOSER=true; shift ;;
        --no-serve) NO_SERVE=true; shift ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

show_help() {
    grep "^#" "$0" | head -30
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((TASKS_COMPLETED++))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_task() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}→ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_requirements() {
    log_task "Phase 0: Checking Requirements"
    
    # Check PHP version
    if ! command -v php &> /dev/null; then
        log_error "PHP is not installed"
        exit 1
    fi
    PHP_VERSION=$(php -v | grep -oP 'PHP \K[0-9]+\.[0-9]+')
    log_success "PHP $PHP_VERSION found"
    ((TASKS_TOTAL++))
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    NODE_VERSION=$(node -v)
    log_success "$NODE_VERSION found"
    ((TASKS_TOTAL++))
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        exit 1
    fi
    log_success "Git found"
    ((TASKS_TOTAL++))
    
    cd "$PROJECT_ROOT"
    log_success "Working directory: $PROJECT_ROOT"
    ((TASKS_TOTAL++))
}

phase_environment() {
    log_task "Phase 1: Environment Setup"
    
    # Copy .env.example to .env
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        log_success "Created .env from .env.example"
    else
        log_warning ".env already exists, skipping"
    fi
    ((TASKS_TOTAL++))
    
    # Generate application key
    if ! grep -q "^APP_KEY=base64:" "$PROJECT_ROOT/.env"; then
        php artisan key:generate
        log_success "Generated application key"
    else
        log_warning "Application key already exists"
    fi
    ((TASKS_TOTAL++))
}

phase_dependencies() {
    log_task "Phase 2: Install Dependencies"
    
    # Composer install
    if [ "$SKIP_COMPOSER" = false ]; then
        if [ ! -d "$PROJECT_ROOT/vendor" ]; then
            log_info "Installing PHP dependencies via Composer..."
            composer install --no-interaction --prefer-dist 2>&1 | tail -20
            log_success "Composer dependencies installed"
        else
            log_warning "vendor directory exists, skipping composer install"
        fi
    fi
    ((TASKS_TOTAL++))
    
    # npm install
    if [ "$SKIP_NPM" = false ]; then
        if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
            log_info "Installing Node.js dependencies..."
            npm install 2>&1 | tail -20
            log_success "npm dependencies installed"
        else
            log_warning "node_modules directory exists, skipping npm install"
        fi
    fi
    ((TASKS_TOTAL++))
}

phase_database() {
    log_task "Phase 3: Database Setup & Migration"
    
    # Database migration
    log_info "Running database migrations..."
    php artisan migrate:fresh --seed --no-interaction
    log_success "Database migrated and seeded"
    ((TASKS_TOTAL++))
    
    # Seed Primary Basket (GCU)
    if php artisan db:seed --class=GCUBasketSeeder --no-interaction 2>/dev/null; then
        log_success "GCU Primary Basket seeded"
    else
        log_warning "GCU Basket seeding skipped (optional)"
    fi
    ((TASKS_TOTAL++))
    
    # Setup voting (optional)
    if php artisan voting:setup --no-interaction 2>/dev/null; then
        log_success "Voting system setup complete"
    else
        log_warning "Voting setup skipped (optional)"
    fi
    ((TASKS_TOTAL++))
}

phase_assets() {
    log_task "Phase 4: Build Frontend Assets"
    
    log_info "Building frontend assets..."
    npm run build
    log_success "Frontend assets built successfully"
    ((TASKS_TOTAL++))
}

phase_testing() {
    log_task "Phase 5: Testing & Coverage"
    
    if [ "$SKIP_TESTS" = false ]; then
        log_info "Running test suite with Pest..."
        ./vendor/bin/pest --parallel --no-interaction
        log_success "All tests passed"
        ((TASKS_TOTAL++))
        
        log_info "Generating coverage report (minimum 50%)..."
        ./vendor/bin/pest --parallel --coverage --min=50 --no-interaction
        log_success "Coverage report generated and verified"
        ((TASKS_TOTAL++))
    else
        log_warning "Tests skipped (--skip-tests flag)"
        ((TASKS_TOTAL+=2))
    fi
}

phase_quality() {
    log_task "Phase 6: Code Quality Checks"
    
    if [ "$SKIP_QUALITY" = false ]; then
        # PHPStan static analysis
        log_info "Running PHPStan analysis (Level 5)..."
        XDEBUG_MODE=off TMPDIR=/tmp/phpstan-$$ ./vendor/bin/phpstan analyse --memory-limit=2G
        log_success "PHPStan analysis passed"
        ((TASKS_TOTAL++))
        
        # PHP-CS-Fixer check
        log_info "Checking code style with PHP-CS-Fixer..."
        if ./vendor/bin/php-cs-fixer fix --dry-run --diff; then
            log_success "Code style check passed"
        else
            log_warning "Code style issues found, auto-fixing..."
            ./vendor/bin/php-cs-fixer fix
            log_success "Code style fixed"
        fi
        ((TASKS_TOTAL++))
    else
        log_warning "Quality checks skipped (--skip-quality flag)"
        ((TASKS_TOTAL+=2))
    fi
}

phase_documentation() {
    log_task "Phase 7: API Documentation"
    
    log_info "Generating L5 Swagger documentation..."
    php artisan l5-swagger:generate
    log_success "API documentation generated"
    log_info "  Access at: ${BLUE}http://localhost:8000/api/documentation${NC}"
    ((TASKS_TOTAL++))
}

phase_summary() {
    log_task "Phase 8: Execution Summary"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        ✓ All Tasks Completed Successfully!            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📊 Execution Statistics:"
    echo -e "  ${GREEN}✓ Tasks Completed${NC}: $TASKS_COMPLETED/$TASKS_TOTAL"
    echo -e "  ⏱️  Total Duration: ${MINUTES}m ${SECONDS}s"
    echo -e "  📍 Project Root: $PROJECT_ROOT"
    echo ""
    echo "🚀 Next Steps:"
    echo ""
    
    if [ "$NO_SERVE" = false ]; then
        echo -e "  ${CYAN}1. Start Laravel Development Server:${NC}"
        echo -e "     ${BLUE}php artisan serve${NC}"
        echo ""
        echo -e "  ${CYAN}2. Start Frontend Dev Server (in new terminal):${NC}"
        echo -e "     ${BLUE}npm run dev${NC}"
        echo ""
        echo -e "  ${CYAN}3. Start Queue Workers (in new terminal):${NC}"
        echo -e "     ${BLUE}php artisan queue:work --queue=events,ledger,transactions,transfers,webhooks${NC}"
        echo ""
        echo -e "  ${CYAN}4. Access Admin Dashboard:${NC}"
        echo -e "     ${BLUE}http://localhost:8000/admin${NC}"
        echo ""
        echo -e "  ${CYAN}5. Create Admin User:${NC}"
        echo -e "     ${BLUE}php artisan make:filament-user${NC}"
        echo ""
        echo -e "  ${CYAN}6. View API Documentation:${NC}"
        echo -e "     ${BLUE}http://localhost:8000/api/documentation${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}📚 Documentation:${NC}"
    echo "  - AGENTS-TASKS-GUIDE.md (This guide)"
    echo "  - AGENTS.md (Original agent instructions)"
    echo "  - CLAUDE.md (Claude AI guidance)"
    echo "  - docs/README.md (Full documentation index)"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}FinAegis Core Banking Platform - Ready for Development${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🤖 FinAegis - Full Agents Tasks Automation Script   ║${NC}"
    echo -e "${CYAN}║     Executing all tasks from AGENTS.md                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run all phases
    check_requirements
    phase_environment
    phase_dependencies
    phase_database
    phase_assets
    phase_testing
    phase_quality
    phase_documentation
    phase_summary
}

# Error handler
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main
