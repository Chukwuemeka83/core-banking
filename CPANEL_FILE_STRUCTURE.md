# cPanel File Structure Guide

## Understanding Your Application Directory

```
~/public_html/app.privinvault/          # Your main application directory
│
├── 📁 app/                             # Application code
│   ├── Models/                         # Database models
│   ├── Http/                           # Controllers, middleware, requests
│   ├── Console/                        # Artisan commands
│   ├── Services/                       # Business logic
│   └── ...
│
├── 📁 bootstrap/                       # Framework bootstrap files
│   ├── cache/                          # Framework cache (WRITABLE)
│   └── app.php
│
├── 📁 config/                          # Configuration files
│   ├── app.php                         # Main app config
│   ├── database.php                    # Database config
│   ├── cache.php                       # Cache config
│   └── ...
│
├── 📁 database/                        # Database files
│   ├── migrations/                     # Database migration files
│   ├── seeders/                        # Database seed files
│   └── factories/                      # Model factories for testing
│
├── 📁 public/                          # PUBLIC WEB ROOT 🌐
│   ├── index.php                       # Application entry point (CRITICAL)
│   ├── css/                            # Compiled CSS files
│   ├── js/                             # Compiled JavaScript files
│   ├── images/                         # Public images
│   └── .htaccess                       # Apache rewrite rules
│
├── 📁 resources/                       # Application views & assets
│   ├── views/                          # Blade templates
│   ├── css/                            # Source CSS (pre-compilation)
│   ├── js/                             # Source JavaScript (pre-compilation)
│   └── icons/                          # SVG icons
│
├── 📁 routes/                          # Route definitions
│   ├── web.php                         # Web routes
│   ├── api.php                         # API routes
│   └── console.php                     # Console commands
│
├── 📁 storage/                         # Writable storage (CRITICAL - 755)
│   ├── app/                            # Application files
│   ├── framework/                      # Framework files
│   ├── logs/                           # Application logs
│   │   └── laravel.log                 # Main error log 📋
│   ├── cache/                          # Cache files
│   └── uploads/                        # User uploads
│
├── 📁 tests/                           # Test files
│   ├── Unit/                           # Unit tests
│   ├── Feature/                        # Feature tests
│   └── Pest.php                        # Test configuration
│
├── 📁 node_modules/                    # JavaScript dependencies (hidden)
│   └── ... (many packages)
│
├── 📁 vendor/                          # PHP dependencies (hidden)
│   └── ... (many packages)
│
├── 📄 .env                             # Environment variables (SECRET - 600) 🔐
├── 📄 .env.example                     # Example environment file
├── 📄 .gitignore                       # Git ignore rules
├── 📄 .htaccess                        # Apache rewrite rules (security)
├── 📄 artisan                          # Laravel CLI tool
├── 📄 composer.json                    # PHP dependencies definition
├── 📄 composer.lock                    # PHP dependencies lock file
├── 📄 package.json                     # Node.js dependencies
├── 📄 package-lock.json                # Node.js dependencies lock
├── 📄 README.md                        # Project documentation
├── 📄 SETUP.md                         # Setup guide
├── 📄 CPANEL_DEPLOYMENT.md             # cPanel specific guide ⭐
└── 📄 CPANEL_MAINTENANCE.md            # cPanel maintenance guide ⭐
```

---

## 🔴 Critical Directories (In cPanel File Manager)

### 1. **storage/** (Must be Writable - 755)

**In cPanel File Manager:**
1. Right-click `storage` folder
2. Click "Change Permissions"
3. Set to `755`
4. Check "Apply to all files and folders recursively"
5. Click "Change"

**Why:** Laravel writes:
- Application logs
- Session files
- Cache data
- File uploads

**If not writable, you'll get errors:**
```
The stream or file "storage/logs/laravel.log" could not be opened in append mode
```

### 2. **bootstrap/cache/** (Must be Writable - 755)

**In cPanel File Manager:**
1. Right-click `bootstrap/cache` folder
2. Click "Change Permissions"
3. Set to `755`
4. Check "Apply to all files and folders recursively"
5. Click "Change"

**Why:** Laravel caches:
- Route cache
- Configuration cache
- View cache

---

## 🟡 Sensitive Files (Must NOT be Web-Accessible)

### 1. **.env** (Secret Configuration - 600)

**Content (DO NOT expose):**
```
APP_KEY=base64:...
DB_PASSWORD=your_password
API_KEYS=...
```

**In cPanel File Manager:**
1. Right-click `.env`
2. Click "Change Permissions"
3. Set to `600` (only owner can read/write)
4. Click "Change"

**Verify it's protected:**
```bash
ls -la .env
# Should show: -rw------- (600)

# Try to access via web (should be blocked)
curl https://yourdomain.com/.env
# Should return: 403 Forbidden
```

### 2. **.env.example** (Template - 644)

- Safe to expose (no secrets)
- Used as template for .env

### 3. **vendor/** (Composer packages)

**In cPanel File Manager:**
1. Right-click `vendor` folder
2. Click "Change Permissions"
3. Set to `755` (Read-only)
4. Check "Apply to all files and folders recursively"

**Why:** Contains third-party code (read-only is fine)

---

## 🟢 Web-Accessible Directory

### **public/** (Document Root)

This is the ONLY directory visible to web visitors.

**In cPanel:**
1. Go to "Addon Domains" or "Parked Domains"
2. Add your domain
3. Set "Document Root" to:
   ```
   /home/yourusername/public_html/app.privinvault/public
   ```
4. Or if installed elsewhere:
   ```
   /home/yourusername/app.privinvault/public
   ```
5. Click "Add Domain"

**Important files in public/:**
- `index.php` - Entry point (DO NOT DELETE)
- `.htaccess` - Rewrite rules (DO NOT DELETE)
- `css/app.css` - Compiled styles
- `js/app.js` - Compiled JavaScript

---

## 📊 File Permissions Quick Reference

| Path | Permission | Why | Access |
|------|-----------|-----|--------|
| `storage/` | 755 | Laravel needs to write | Not web-visible |
| `bootstrap/cache/` | 755 | Laravel caches files | Not web-visible |
| `vendor/` | 755 | Third-party code | Not web-visible |
| `public/` | 755 | Static files | WEB-VISIBLE |
| `.env` | 600 | SECRET config | Not web-visible |
| `.env.example` | 644 | Template file | Not web-visible |
| `app/`, `routes/`, etc. | 755 | Code files | Not web-visible |

---

## 🔐 Security Checklist

### Critical Protection
- [ ] `.env` file set to `600` (not accessible via web)
- [ ] `storage/` directory NOT web-accessible
- [ ] `vendor/` directory NOT web-accessible
- [ ] `.htaccess` prevents direct access to sensitive files
- [ ] `index.php` only in `public/` directory
- [ ] Database credentials in `.env` only

### Verify Protection
```bash
# .env should be protected
curl https://yourdomain.com/.env
# Response: 403 Forbidden ✓

# vendor should be protected
curl https://yourdomain.com/vendor/
# Response: 403 Forbidden ✓

# storage should be protected
curl https://yourdomain.com/storage/
# Response: 403 Forbidden ✓

# public/index.php should work
curl https://yourdomain.com/
# Response: 200 OK with HTML content ✓
```

---

## 🛠️ Working in cPanel File Manager

### Creating Files
1. Right-click in folder → "Create New File"
2. Enter filename
3. Click "Create"
4. Double-click to edit

### Uploading Files
1. Click "Upload" button (top of File Manager)
2. Select files or drag-drop
3. Wait for upload to complete
4. Set permissions if needed

### Editing Files
1. Right-click file → "Edit"
2. Make changes in editor
3. Click "Save" and "Close"

### Changing Permissions
1. Right-click file/folder
2. Click "Change Permissions"
3. Set appropriate value (755, 644, 600, etc.)
4. Check "Apply recursively" for folders
5. Click "Change"

### Viewing Logs
1. Navigate to `storage/logs/`
2. Right-click `laravel.log`
3. Click "View"
4. Scroll to bottom for latest errors

---

## 🚨 Common File Issues in cPanel

### Issue: "Permission denied" when writing to storage
```
Solution: Set storage/ to 755 permission
```

### Issue: ".env file exposed" warning
```
Solution: Set .env to 600 permission
```

### Issue: "artisan command not found"
```bash
# artisan might not be executable
chmod +x artisan
# Then run: php artisan ...
```

### Issue: Can't delete .htaccess
```
It's a protected file in cPanel
Instead:
1. Right-click it → Edit
2. Delete content
3. Save (or edit with appropriate rules)
```

---

## 📚 Using Files in Workflow

### Daily Development
1. Edit files in `app/`, `resources/`, `routes/`
2. Test locally or in cPanel
3. Run `php artisan` commands as needed
4. Push changes to Git

### Deploying Updates
1. SSH into cPanel: `ssh username@yourdomain.com`
2. Go to app: `cd public_html/app.privinvault`
3. Pull changes: `git pull origin main`
4. Update: `composer install && npm run build`
5. Migrate: `php artisan migrate`
6. Clear cache: `php artisan cache:clear`

### Backup Strategy
1. Database: Via cPanel > Backups or phpMyAdmin
2. Files: Via cPanel > Backup or File Manager (download)
3. Git: Push to GitHub regularly

---

**Key Takeaway:** Keep sensitive files (.env, vendor, storage) out of web root. Only public/ is web-accessible! 🔐
