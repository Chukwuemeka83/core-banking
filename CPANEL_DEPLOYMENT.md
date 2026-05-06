# cPanel Deployment Guide - FinAegis Core Banking

**Version:** 1.0
**Last Updated:** 2026-05-06
**Target Platform:** cPanel File Manager

---

## 📋 Pre-Deployment Checklist

### cPanel Requirements
- ✅ PHP 8.3+ installed (check in cPanel > PHP Selector)
- ✅ MySQL/MariaDB available
- ✅ Composer installed (or will be installed)
- ✅ Node.js installed (or npm)
- ✅ SSH access enabled (recommended)
- ✅ Write permissions to home directory

### Verify PHP Version
```
1. Login to cPanel
2. Go to "Select PHP Version" or "PHP Selector"
3. Ensure PHP 8.3 is selected
4. Verify these extensions are enabled:
   - GMP (gmp)
   - Intl (intl)
   - Mbstring (mbstring)
   - PDO (pdo)
   - Redis (redis) - optional but recommended
```

---

## 🚀 Quick Installation (cPanel)

### Step 1: Upload Project Files

**Via cPanel File Manager:**
1. Login to cPanel
2. Open "File Manager"
3. Navigate to your home directory
4. Create a new folder: `app.privinvault` (or your preferred name)
5. Upload the repository files:
   - Extract the ZIP file locally first
   - Upload all files via cPanel File Manager
   - Or use Git: See "Step 2"

**Via SSH/Git (Recommended):**
```bash
cd ~/public_html  # or your deployment directory
git clone https://github.com/Chukwuemeka83/core-banking.git app.privinvault
cd app.privinvault
```

### Step 2: Install Dependencies

**Option A: Using cPanel Terminal (SSH)**
```bash
cd ~/public_html/app.privinvault

# Install PHP dependencies
composer install --no-dev --optimize-autoloader

# Install Node dependencies
npm install

# Build assets
npm run build
```

**Option B: Using cPanel File Manager + FTP**
1. Download Composer locally
2. Run locally: `composer install --no-dev --optimize-autoloader`
3. Run locally: `npm install && npm run build`
4. Upload vendor/ and node_modules/ folders via FTP

### Step 3: Environment Configuration

**Via cPanel File Manager:**
1. In File Manager, navigate to: `~/public_html/app.privinvault/`
2. Right-click `.env.example` → Copy
3. Rename copy to `.env`
4. Right-click `.env` → Edit → Add your configuration

**Key Configuration for cPanel:**
```env
APP_NAME="FinAegis Core Banking"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

# Database (Get from cPanel Database Wizard)
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=yourusername_finaegis
DB_USERNAME=yourusername_finaegis
DB_PASSWORD=your_secure_password

# Cache & Sessions (use file-based for cPanel)
CACHE_STORE=file
SESSION_DRIVER=file
QUEUE_CONNECTION=database

# Email (optional)
MAIL_MAILER=log
MAIL_FROM_ADDRESS="noreply@yourdomain.com"
MAIL_FROM_NAME="${APP_NAME}"

# Security
FORCE_HTTPS=true
SESSION_SECURE_COOKIES=true
```

### Step 4: Create Database

**Via cPanel:**
1. Login to cPanel
2. Go to "MySQL Databases"
3. Click "Create New Database"
4. Database Name: `yourusername_finaegis`
5. Go to "MySQL Users"
6. Create new user with strong password
7. Add user to database with ALL privileges
8. Note the credentials for `.env` file

### Step 5: Generate App Key

**Via cPanel Terminal (SSH):**
```bash
cd ~/public_html/app.privinvault
php artisan key:generate
```

**Via File Manager (Alternative):**
1. Use SSH or contact your hosting provider
2. Run the command above
3. Verify `.env` has `APP_KEY` set

### Step 6: Database Migrations

**Via SSH Terminal:**
```bash
cd ~/public_html/app.privinvault

# Run migrations
php artisan migrate

# Seed demo data (optional)
php artisan db:seed

# Create admin user
php artisan make:filament-user
# Follow prompts to create admin account
```

### Step 7: Set Permissions

**Via SSH:**
```bash
cd ~/public_html/app.privinvault

# Set proper permissions
chmod -R 755 .
chmod -R 755 storage bootstrap/cache
chown -R nobody:nobody storage bootstrap/cache
```

**Via cPanel File Manager:**
1. Select `storage` folder → Right-click → Change Permissions
2. Set to: `755` (Read, Write, Execute for all)
3. Repeat for `bootstrap/cache` folder

### Step 8: Configure Public Directory

**Via cPanel File Manager:**
1. Locate `public/` folder in your app directory
2. In cPanel, go to "Addon Domains" or "Parked Domains"
3. Add your domain and point Document Root to `/path/to/app.privinvault/public`

**Example paths:**
```
/home/yourusername/public_html/app.privinvault/public
or
/home/yourusername/app.privinvault/public
```

---

## 📱 cPanel-Specific File Management

### Folder Structure in cPanel
```
~/public_html/
├── app.privinvault/                 # Main application
│   ├── app/                         # Application code
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/                      # Web root (set as document root)
│   │   ├── index.php               # Entry point
│   │   ├── css/
│   │   ├── js/
│   │   └── ...
│   ├── resources/
│   ├── routes/
│   ├── storage/                    # MUST be writable (755)
│   │   ├── app/
│   │   ├── logs/
│   │   └── framework/
│   ├── .env                        # Configuration (secure, not web-accessible)
│   ├── .env.example
│   ├── artisan                     # Laravel CLI
│   ├── composer.json
│   ├── composer.lock
│   ├── package.json
│   └── ...
```

### Important: Storage Directory

**cPanel File Manager:**
1. Navigate to `~/public_html/app.privinvault/storage`
2. Right-click → "Change Permissions"
3. Set to `755` (Read, Write, Execute)
4. Check "Apply to all files and folders recursively"

**Why:** Laravel writes logs, sessions, and cache files here.

---

## 🔐 Security Configuration for cPanel

### 1. Protect .env File

**Via cPanel File Manager:**
1. Right-click `.env` file
2. Click "Change Permissions"
3. Set to `600` (only owner can read/write)
4. This prevents web access to sensitive data

### 2. Protect Configuration

**Via cPanel File Manager - Create `.htaccess` in root:**
1. Create file: `~/public_html/app.privinvault/.htaccess`
2. Add content:

```apache
# Protect sensitive files
<FilesMatch "^\.env|composer\.(json|lock)|artisan$">
    Order allow,deny
    Deny from all
</FilesMatch>

# Hide storage and bootstrap
<Directory "storage">
    Order allow,deny
    Deny from all
</Directory>

<Directory "bootstrap/cache">
    Order allow,deny
    Deny from all
</Directory>
```

### 3. Enable HTTPS

**Via cPanel:**
1. Go to "AutoSSL" or "SSL/TLS"
2. Install free SSL certificate (Let's Encrypt)
3. Update `APP_URL` in `.env` to use `https://`
4. Set `FORCE_HTTPS=true` in `.env`

---

## 📊 Database Management via cPanel

### phpMyAdmin (Access Database)

1. In cPanel, click "phpMyAdmin"
2. Select your database: `yourusername_finaegis`
3. View/manage tables, run queries
4. Export/import database backups

### Common Tasks

**Backup Database:**
```bash
# Via SSH
mysqldump -u yourusername_finaegis -p yourusername_finaegis > backup.sql

# Or via phpMyAdmin: Export > Download
```

**Restore Database:**
```bash
# Via SSH
mysql -u yourusername_finaegis -p yourusername_finaegis < backup.sql

# Or via phpMyAdmin: Import > Choose File
```

---

## 🔄 Managing Updates & Maintenance

### Update Application Code

**Via SSH (Recommended):**
```bash
cd ~/public_html/app.privinvault

# Pull latest changes
git pull origin main

# Update dependencies
composer install --no-dev --optimize-autoloader

# Build assets
npm run build

# Run new migrations (if any)
php artisan migrate

# Clear caches
php artisan cache:clear
php artisan config:clear
php artisan view:clear
```

### View Logs

**Via cPanel File Manager:**
1. Navigate to: `~/public_html/app.privinvault/storage/logs/`
2. Open latest `laravel.log` file
3. Check for errors

**Via SSH:**
```bash
cd ~/public_html/app.privinvault
tail -f storage/logs/laravel.log
```

### Clear Caches

**Via SSH:**
```bash
cd ~/public_html/app.privinvault

php artisan cache:clear
php artisan config:clear
php artisan view:clear
php artisan route:clear
```

---

## 🚨 Troubleshooting Common Issues

### Issue 1: "500 Internal Server Error"

**Fixes:**
```bash
# 1. Check error logs
cd ~/public_html/app.privinvault/storage/logs/
cat laravel.log

# 2. Check permissions
chmod -R 755 .
chmod -R 777 storage bootstrap/cache

# 3. Regenerate app key
php artisan key:generate

# 4. Clear caches
php artisan cache:clear
php artisan config:clear
```

### Issue 2: "Connection refused" (Database Error)

**Fixes:**
```bash
# 1. Verify credentials in .env
cat .env | grep DB_

# 2. Test database connection
mysql -h localhost -u yourusername_finaegis -p yourusername_finaegis -e "SELECT 1;"

# 3. Check database exists
mysql -u yourusername_finaegis -p yourusername_finaegis -e "SHOW TABLES;"
```

### Issue 3: "Permission denied" (File Upload/Log Writing)

**Fixes:**
```bash
# 1. Fix storage permissions
chmod -R 755 storage bootstrap/cache

# 2. Via cPanel File Manager:
#    - Select storage/ folder
#    - Right-click > Change Permissions
#    - Set to 755
#    - Check "Recursive"
```

### Issue 4: "Class not found" or Migrations Fail

**Fixes:**
```bash
# 1. Regenerate autoloader
composer dump-autoload -o

# 2. Run migrations again
php artisan migrate

# 3. Clear view cache
php artisan view:clear
```

### Issue 5: "White screen / No output"

**Fixes:**
```bash
# 1. Enable debug mode temporarily
sed -i 's/APP_DEBUG=false/APP_DEBUG=true/' .env

# 2. Check PHP error logs
# In cPanel: Logs > Error log

# 3. Check .htaccess syntax
# File Manager > .htaccess > Edit

# 4. Disable mod_security if blocking
# cPanel > ModSecurity
```

---

## 📝 Essential Commands Cheat Sheet

### Application Management
```bash
cd ~/public_html/app.privinvault

# Migrations
php artisan migrate                 # Run all pending migrations
php artisan migrate:rollback        # Rollback last batch
php artisan migrate:refresh         # Reset and re-run all

# Database
php artisan db:seed                 # Seed demo data
php artisan db:seed --class=UsersTableSeeder  # Seed specific class

# Cache
php artisan cache:clear             # Clear all caches
php artisan config:cache            # Cache config (production)
php artisan route:cache             # Cache routes (production)

# Admin
php artisan make:filament-user      # Create admin user

# Queue (if using)
php artisan queue:work              # Start queue worker

# Maintenance
php artisan down                    # Enable maintenance mode
php artisan up                      # Disable maintenance mode
```

### File Management (cPanel)
```
# Via File Manager:
1. Create .env from .env.example
2. Set storage/ permissions to 755
3. Set .env permissions to 600
4. Set public/ as document root
```

---

## 🎯 Next Steps

1. ✅ Follow steps 1-8 above
2. ✅ Access admin dashboard: `https://yourdomain.com/admin`
3. ✅ Login with credentials created in Step 6
4. ✅ Configure banking features
5. ✅ Set up SSL certificate
6. ✅ Monitor logs regularly

---

## 💡 Pro Tips for cPanel

### Tip 1: Regular Backups
```bash
# Daily backup script
cd ~/backups
mysqldump -u yourusername_finaegis -p yourusername_finaegis > backup-$(date +%Y%m%d).sql
```

### Tip 2: Monitor Performance
- Use cPanel "Metrics" to view CPU/Memory usage
- Check "Error log" for PHP warnings
- Monitor database size in phpMyAdmin

### Tip 3: Optimize for cPanel
- Use file-based caching (not Redis)
- Use database sessions (not file)
- Disable debug mode in production
- Enable opcode caching in PHP settings

### Tip 4: Auto-Updates
- Set up cron job to pull updates weekly:
```bash
0 2 * * 0 cd ~/public_html/app.privinvault && git pull origin main && composer install --no-dev --optimize-autoloader && npm run build && php artisan cache:clear
```

---

## 📞 Support & Resources

- **Laravel Docs:** https://laravel.com/docs
- **cPanel Docs:** https://docs.cpanel.net
- **phpMyAdmin:** https://www.phpmyadmin.net
- **Community:** Laravel Ecosystem Forums

---

**Happy Deployment! 🚀**
