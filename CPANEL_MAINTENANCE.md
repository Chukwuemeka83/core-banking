# cPanel Daily Maintenance & Operations Guide

## 📋 Daily Tasks (5 minutes)

### Check Application Health
```bash
cd ~/public_html/app.privinvault

# Check latest errors
tail -20 storage/logs/laravel.log

# Check disk space
df -h

# Check database
mysql -u yourusername_finaegis -p yourusername_finaegis -e "SELECT COUNT(*) FROM users;"
```

### Via cPanel Interface
1. **Metrics:** Check CPU, Memory, Bandwidth usage
2. **Error log:** Look for PHP errors
3. **Access log:** Verify normal traffic patterns

---

## 📅 Weekly Tasks (30 minutes)

### Database Backup
```bash
# Backup database
mysqldump -u yourusername_finaegis -p yourusername_finaegis yourusername_finaegis > ~/backups/db-$(date +%Y%m%d).sql

# Compress
gzip ~/backups/db-*.sql

# Keep last 4 weeks
find ~/backups -name "*.sql.gz" -mtime +28 -delete
```

### Check Updates
```bash
cd ~/public_html/app.privinvault

# See what's changed
git status

# Check for updates
git fetch origin
git log --oneline HEAD..origin/main
```

### Review Logs
- Check `storage/logs/laravel.log` for issues
- Review cPanel error logs
- Check database query performance

---

## 🔧 Monthly Tasks (1 hour)

### Security Update
```bash
cd ~/public_html/app.privinvault

# Update dependencies
composer update
npm update

# Check security vulnerabilities
composer audit
```

### Database Maintenance
```bash
# Via SSH
mysql -u yourusername_finaegis -p yourusername_finaegis << EOF
OPTIMIZE TABLE users;
OPTIMIZE TABLE transactions;
OPTIMIZE TABLE accounts;
EOF
```

### SSL Certificate Check
- Verify HTTPS is working: https://yourdomain.com
- Check AutoSSL renewal status in cPanel
- Enable auto-renewal if not enabled

### Performance Tuning
- Clear old logs: `find storage/logs -mtime +30 -delete`
- Clear cache: `php artisan cache:clear`
- Optimize database: Run OPTIMIZE commands above

---

## 🛡️ Emergency Procedures

### If Site Goes Down

**Step 1: Check Logs (2 min)**
```bash
cd ~/public_html/app.privinvault
cat storage/logs/laravel.log | tail -50
```

**Step 2: Enable Debugging (1 min)**
```bash
sed -i 's/APP_DEBUG=false/APP_DEBUG=true/' .env
```

**Step 3: Fix Common Issues (5 min)**
```bash
# Clear caches
php artisan cache:clear
php artisan config:clear
php artisan view:clear

# Check permissions
chmod -R 755 .
chmod -R 777 storage bootstrap/cache

# Regenerate key
php artisan key:generate
```

**Step 4: Check Database (2 min)**
```bash
mysql -u yourusername_finaegis -p yourusername_finaegis -e "SELECT COUNT(*) FROM users;"
```

**Step 5: Restart Services (1 min)**
- Via cPanel: Restart PHP-FPM
- Or restart via SSH (if available)

**Step 6: Disable Debugging (1 min)**
```bash
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' .env
```

### If Database Won't Start

**Via cPanel:**
1. Go to MySQL Databases
2. Check database status
3. Click "Restart MySQL" (if available)
4. Contact hosting support if persistent

### If High Traffic/Slow Performance

1. **Check metrics:** cPanel > Metrics
2. **Find slow queries:** phpMyAdmin > Slow log
3. **Clear caches:** `php artisan cache:clear`
4. **Reduce background jobs:** Pause queue workers if high CPU

---

## 📊 Monitoring Checklist

### Daily (via cPanel)
- [ ] Site accessible: https://yourdomain.com
- [ ] Admin panel works: https://yourdomain.com/admin
- [ ] No 500 errors in access log
- [ ] Database responding
- [ ] CPU usage < 70%
- [ ] Memory usage < 80%

### Weekly
- [ ] Backup database
- [ ] Review error logs
- [ ] Check disk space (> 20% free)
- [ ] Verify SSL certificate valid
- [ ] Test payment processing

### Monthly
- [ ] Update dependencies
- [ ] Security audit
- [ ] Database optimization
- [ ] Performance review
- [ ] Test disaster recovery

---

## 🔐 Security Checklist

### Monthly
- [ ] Review database backups
- [ ] Check file permissions
- [ ] Verify .env is not web-accessible
- [ ] Review admin users (remove inactive)
- [ ] Check .htaccess is in place
- [ ] Verify HTTPS is enforced
- [ ] Review access logs for suspicious activity
- [ ] Update dependencies for security patches

### Commands
```bash
# Check .env is protected
ls -la .env  # Should show: -rw------- (600)

# Verify storage not accessible
curl https://yourdomain.com/storage/
# Should return: 403 Forbidden

# Check for suspicious files
find . -name "*.php" -newer .env -type f

# Verify .htaccess protection
ls -la .htaccess
```

---

## 📝 Important Files & Locations

| File/Folder | Location | Permission | Purpose |
|------------|----------|-----------|----------|
| `.env` | Root | 600 | Configuration (keep secret!) |
| `storage/` | Root | 755 | Logs, cache, uploads |
| `bootstrap/cache/` | Root | 755 | Framework cache |
| `public/` | Root | 755 | Web-accessible files |
| `vendor/` | Root | 755 | Composer packages |
| `.htaccess` | Root | 644 | Security rules |
| `laravel.log` | storage/logs/ | 644 | Application logs |

---

## 🆘 Quick Command Reference

```bash
# Navigate to app
cd ~/public_html/app.privinvault

# Check status
php artisan tinker   # Interactive shell

# Database operations
php artisan migrate              # Run migrations
php artisan db:seed             # Seed data
php artisan db:seed --class=UsersTableSeeder  # Seed specific

# Cache management
php artisan cache:clear         # Clear all caches
php artisan config:cache        # Cache config (production)
php artisan view:clear          # Clear view cache
php artisan route:clear         # Clear route cache

# Maintenance
php artisan down                # Enable maintenance mode
php artisan up                  # Disable maintenance mode
php artisan tinker              # Enter interactive shell

# User management
php artisan make:filament-user  # Create admin

# Logs
tail -f storage/logs/laravel.log  # Watch logs in real-time

# Performance
php artisan optimize            # Optimize for production
php artisan view:cache          # Cache all views
```

---

**Keep Your Application Running Smoothly! 🚀**
