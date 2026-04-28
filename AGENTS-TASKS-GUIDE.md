# 🤖 Agents Tasks Execution Guide

This document outlines all tasks from `AGENTS.md` that have been automated and organized for execution.

## 📋 Task Categories

### ✅ PHASE 1: Environment Setup
- [x] Copy `.env.example` to `.env`
- [x] Generate application key via `php artisan key:generate`

### ✅ PHASE 2: Install Dependencies
- [x] Install PHP dependencies via `composer install`
- [x] Install Node.js dependencies via `npm install`

### ✅ PHASE 3: Database & Migration
- [x] Run migrations: `php artisan migrate:fresh --seed`
- [x] Seed Primary Basket: `php artisan db:seed --class=GCUBasketSeeder`
- [x] Setup voting system: `php artisan voting:setup` (optional)

### ✅ PHASE 4: Build Frontend Assets
- [x] Build assets: `npm run build`

### ✅ PHASE 5: Testing
- [x] Run tests: `./vendor/bin/pest --parallel`
- [x] Generate coverage: `./vendor/bin/pest --parallel --coverage --min=50`

### ✅ PHASE 6: Code Quality
- [x] PHPStan analysis: `XDEBUG_MODE=off ./vendor/bin/phpstan analyse --memory-limit=2G`
- [x] PHP-CS-Fixer check: `./vendor/bin/php-cs-fixer fix --dry-run`
- [x] Auto-fix code style: `./vendor/bin/php-cs-fixer fix`

### ✅ PHASE 7: API Documentation
- [x] Generate L5 Swagger: `php artisan l5-swagger:generate`
- [x] Access at: `http://localhost:8000/api/documentation`

### ✅ PHASE 8: Development Server (Manual)
- [ ] Start Laravel: `php artisan serve`
- [ ] Start Frontend Dev: `npm run dev`
- [ ] Start Queue Workers: `php artisan queue:work --queue=events,ledger,transactions,transfers,webhooks`

## 🚀 How to Run All Tasks

### Option 1: Automated Bash Script (Recommended)
```bash
# Make script executable
chmod +x scripts/run-all-agents-tasks.sh

# Run the script
./scripts/run-all-agents-tasks.sh
```

**Output:**
- Colored console output with task progress
- Detailed success/error messages
- Summary report at the end
- Development server startup instructions

### Option 2: Manual Step-by-Step

```bash
# 1. Clone repository
git clone https://github.com/Chukwuemeka83/core-banking.git
cd core-banking

# 2. Setup environment
cp .env.example .env
php artisan key:generate

# 3. Install dependencies
composer install
npm install

# 4. Database setup
php artisan migrate:fresh --seed
php artisan db:seed --class=GCUBasketSeeder

# 5. Build assets
npm run build

# 6. Run tests
./vendor/bin/pest --parallel

# 7. Code quality checks
XDEBUG_MODE=off ./vendor/bin/phpstan analyse --memory-limit=2G
./vendor/bin/php-cs-fixer fix

# 8. Generate documentation
php artisan l5-swagger:generate

# 9. Start development servers (in separate terminals)
php artisan serve
npm run dev
php artisan queue:work --queue=events,ledger,transactions,transfers,webhooks
```

### Option 3: GitHub Actions (CI/CD)

The workflow `.github/workflows/agents-full-validation.yml` automatically runs all tasks on:
- Push to `main` or `develop`
- Pull requests to `main` or `develop`
- Manual trigger via `workflow_dispatch`

**Access:**
- Go to: `https://github.com/Chukwuemeka83/core-banking/actions`
- Check the "🤖 Full Agents Validation Pipeline" workflow

## 📊 Task Execution Matrix

| Task | Category | Status | Command | Duration |
|------|----------|--------|---------|----------|
| Env Setup | Setup | ✅ | `cp .env.example .env` | <1s |
| App Key | Setup | ✅ | `php artisan key:generate` | <1s |
| Composer | Dependencies | ✅ | `composer install` | 2-5m |
| NPM Install | Dependencies | ✅ | `npm install` | 1-3m |
| DB Migrate | Database | ✅ | `php artisan migrate:fresh` | 1-2m |
| Seed DB | Database | ✅ | `php artisan db:seed` | <1s |
| Seed GCU | Database | ✅ | `php artisan db:seed --class=...` | <1s |
| Build Assets | Frontend | ✅ | `npm run build` | 1-2m |
| Tests | Testing | ✅ | `./vendor/bin/pest --parallel` | 5-10m |
| Coverage | Testing | ✅ | `--coverage --min=50` | 5-10m |
| PHPStan | Quality | ✅ | `./vendor/bin/phpstan analyse` | 3-5m |
| PHP-CS-Fixer | Quality | ✅ | `./vendor/bin/php-cs-fixer fix` | <1m |
| Swagger Docs | Documentation | ✅ | `php artisan l5-swagger:generate` | <1s |

## 🎯 What's Included

### ✨ Bash Script Features
- **Colored Output**: Easy-to-read progress with color-coded messages
- **Error Handling**: Stops on first error with clear messages
- **Task Counting**: Tracks completed vs failed tasks
- **Time Tracking**: Reports execution start/end times
- **Helpful Instructions**: Shows how to start dev servers
- **Access Points**: Lists all development URLs

### 🔄 GitHub Actions Features
- **Parallel Jobs**: Independent tasks run simultaneously
- **Caching**: Speeds up repeated runs
- **Coverage Reports**: Uploads to Codecov
- **Security Checks**: Detects secrets and vulnerabilities
- **Auto-Commit**: Fixes code style automatically
- **Artifacts**: Uploads API documentation
- **Concurrency**: Cancels outdated runs

## 📈 Performance Optimization

### Local Execution
- **Total Time**: ~15-25 minutes (depends on system)
- **Bottleneck**: Composer + NPM install
- **Optimization**: Reuse vendor/node_modules directories

### CI/CD Execution
- **Total Time**: ~30-45 minutes (includes cache overhead)
- **Parallel Jobs**: 6 jobs run simultaneously
- **Cache Benefits**: First run slower, subsequent faster

## 🔒 Security Considerations

All tasks include security checks:
- ✅ Secret detection in code
- ✅ Vulnerability scanning (Composer)
- ✅ Static analysis (PHPStan level 5)
- ✅ Code style enforcement
- ✅ Database credential validation

## 📝 Logging & Reports

### Bash Script Logs
- Console output with timestamps
- Detailed error messages
- Summary report

### GitHub Actions Logs
- Per-job logs
- Detailed error stack traces
- Artifacts (API docs, coverage)
- Workflow summary

## 🆘 Troubleshooting

### PHP Version Issues
```bash
php -v  # Should be 8.3+
composer install  # May require specific PHP version
```

### Node.js Version Issues
```bash
node -v  # Should be 14+
npm -v   # Should be 6+
```

### Database Issues
```bash
# Reset database
php artisan migrate:refresh
php artisan db:seed --class=GCUBasketSeeder
```

### Test Failures
```bash
# Run specific test
./vendor/bin/pest tests/Unit/YourTest.php

# Run with verbose output
./vendor/bin/pest -v
```

### PHPStan Issues
```bash
# Generate baseline for known issues
./vendor/bin/phpstan analyse --generate-baseline
```

## 📚 Documentation References

- **Main README**: `README.md`
- **Architecture Guide**: `docs/02-ARCHITECTURE/ARCHITECTURE.md`
- **API Reference**: `docs/04-API/REST_API_REFERENCE.md`
- **AI Framework**: `docs/13-AI-FRAMEWORK/00-Overview.md`
- **User Guide**: `docs/11-USER-GUIDES/DEMO-USER-GUIDE.md`

## ✅ Completion Checklist

Use this checklist to track your progress:

- [ ] Clone repository
- [ ] Install dependencies (PHP & Node)
- [ ] Setup database
- [ ] Build assets
- [ ] Run all tests
- [ ] Pass PHPStan analysis
- [ ] Fix code style
- [ ] Generate API docs
- [ ] Start dev servers
- [ ] Access admin dashboard
- [ ] Create admin user

## 🎉 Next Steps

After all tasks complete:

1. **Create Admin User**: `php artisan make:filament-user`
2. **Access Dashboard**: `http://localhost:8000/admin`
3. **Review API Docs**: `http://localhost:8000/api/documentation`
4. **Check Test Coverage**: Review coverage reports
5. **Read Documentation**: Start with architecture guide

## 🤝 Contributing

All tasks follow the project's contribution guidelines:
- Commit message format: Conventional commits
- Code style: PSR-12 with PHP-CS-Fixer
- Testing: Minimum 50% coverage
- Quality: PHPStan level 5

## 📞 Support

For issues or questions:
- Check GitHub Issues: `https://github.com/Chukwuemeka83/core-banking/issues`
- Review documentation in `/docs` folder
- Check AGENTS.md for additional context

---

**Last Updated**: 2026-04-28
**Status**: ✅ All tasks automated and documented
