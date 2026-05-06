#!/bin/bash

################################################################################
# FinAegis Core Banking - cPanel Setup Script
# For use in cPanel hosting environments
# Requirements: PHP 8.3+, Composer, Node.js, MySQL/MariaDB
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    print_error "Unsupported OS: $OSTYPE"
    exit 1
fi

# Start setup
clear
print_header "FinAegis Core Banking - cPanel Setup"
echo ""
echo "This script will set up your application for cPanel hosting."
echo ""
echo "Requirements:"
echo "  • PHP 8.3 or higher"
echo "  • Composer installed"
echo "  • Node.js/npm installed"
echo "  • MySQL/MariaDB database created"
echo ""
read -p "Continue with setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled."
    exit 0
fi

# Check PHP version
print_header "Step 1: Checking PHP Version"
PHP_VERSION=$(php -v | grep -oP '\d+\.\d+' | head -1)
if (( $(echo "$PHP_VERSION >= 8.3" | bc -l) )); then
    print_success "PHP version $PHP_VERSION found"
else
    print_error "PHP 8.3+ required, found: $PHP_VERSION"
    exit 1
fi

# Check PHP extensions
print_header "Step 2: Checking PHP Extensions"
REQUIRED_EXTENSIONS=("gmp" "intl" "mbstring" "pdo" "json")
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -iq "$ext"; then
        print_success "Extension: $ext"
    else
        print_error "Missing extension: $ext"
        echo "  Enable in cPanel > Select PHP Version > Extensions"
    fi
done

# Check Composer
print_header "Step 3: Checking Composer"
if command -v composer &> /dev/null; then
    COMPOSER_VERSION=$(composer --version | grep -oP 'Composer \K[\d.]+' | head -1)
    print_success "Composer version $COMPOSER_VERSION found"
else
    print_error "Composer not found"
    echo "Install from: https://getcomposer.org/download/"
    exit 1
fi

# Check Node.js
print_header "Step 4: Checking Node.js"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    print_success "Node.js version $NODE_VERSION found"
else
    print_warning "Node.js not found"
    echo "npm run build will be skipped"
    SKIP_NPM=true
fi

# Install PHP dependencies
print_header "Step 5: Installing PHP Dependencies"
echo "Running: composer install --no-dev --optimize-autoloader"
composer install --no-dev --optimize-autoloader
if [ $? -eq 0 ]; then
    print_success "PHP dependencies installed"
else
    print_error "Failed to install PHP dependencies"
    exit 1
fi

# Install Node dependencies (if npm available)
if [ -z "$SKIP_NPM" ]; then
    print_header "Step 6: Installing Node Dependencies"
    echo "Running: npm install"
    npm install
    if [ $? -eq 0 ]; then
        print_success "Node dependencies installed"
    else
        print_error "Failed to install Node dependencies"
        exit 1
    fi

    # Build assets
    print_header "Step 7: Building Assets"
    echo "Running: npm run build"
    npm run build
    if [ $? -eq 0 ]; then
        print_success "Assets built successfully"
    else
        print_warning "Asset build had issues (may not be critical)"
    fi
else
    print_header "Step 6: Skipping Node Setup"
    print_warning "Node.js not available - skipping npm install and build"
fi

# Setup .env
print_header "Step 8: Environment Configuration"
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        print_success ".env file created from .env.example"
    else
        print_error ".env.example not found"
        exit 1
    fi
else
    print_warning ".env file already exists (skipping)"
fi

# Set permissions
print_header "Step 9: Setting File Permissions"
echo "Setting permissions..."
chmod -R 755 .
chmod -R 755 storage bootstrap/cache
chmod 600 .env .env.example
print_success "Permissions set correctly"

# Generate app key
print_header "Step 10: Generating Application Key"
echo "Running: php artisan key:generate"
php artisan key:generate
if [ $? -eq 0 ]; then
    print_success "Application key generated"
else
    print_error "Failed to generate application key"
    exit 1
fi

# Database setup
print_header "Step 11: Database Configuration"
echo ""
echo "Before continuing, ensure you have:"
echo "  1. Created a MySQL database in cPanel"
echo "  2. Created a MySQL user with all privileges"
echo "  3. Updated .env file with database credentials"
echo ""
read -p "Have you configured the database? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Please configure database in .env and run: php artisan migrate"
else
    echo "Running migrations..."
    php artisan migrate
    if [ $? -eq 0 ]; then
        print_success "Database migrations completed"
    else
        print_error "Database migrations failed"
        print_info "Check your .env database credentials"
    fi
fi

# Final setup message
echo ""
print_header "Setup Complete! 🎉"
echo ""
echo "Next steps:"
echo ""
echo "1. Update .env file with your configuration:"
echo "   nano .env"
echo ""
echo "2. If not done already, run migrations:"
echo "   php artisan migrate"
echo ""
echo "3. Seed database (optional):"
echo "   php artisan db:seed"
echo ""
echo "4. Create admin user:"
echo "   php artisan make:filament-user"
echo ""
echo "5. Configure your domain in cPanel:"
echo "   Set Document Root to: ~/public_html/app.privinvault/public"
echo "   (or your actual installation path)"
echo ""
echo "6. Access your application:"
echo "   Web: https://yourdomain.com"
echo "   Admin: https://yourdomain.com/admin"
echo ""
echo "For help, see CPANEL_DEPLOYMENT.md"
echo ""
print_success "Setup ready!"
echo ""
