# MediaWiki ProxmoxVE Installation Scripts

Two scripts following the [ProxmoxVE Community Scripts](https://github.com/community-scripts/ProxmoxVE) standards for installing MediaWiki with PostgreSQL, Redis, and Nginx.

## Files Created

1. **mediawiki.sh** - Container creation script (goes in `ct/` directory)
2. **mediawiki-install.sh** - Installation script (goes in `install/` directory)

## What Gets Installed

- **MediaWiki** - Latest stable version (automatically detected)
- **PostgreSQL** - Database backend with dedicated mediawiki database
- **Redis** - Session caching and performance optimization
- **Nginx** - Web server with optimized MediaWiki configuration
- **PHP 8.2** - With all required extensions (pgsql, redis, gd, intl, etc.)
- **ImageMagick** - For image processing

## Container Specifications

- **OS:** Debian 12
- **CPU:** 2 cores
- **RAM:** 2048 MB
- **Disk:** 8 GB
- **Type:** Unprivileged container
- **Tags:** wiki, documentation

## Features

✅ Automatic detection of latest MediaWiki version  
✅ Secure PostgreSQL setup with random password generation  
✅ Redis configured for session caching (256MB memory, LRU eviction)  
✅ Nginx optimized for MediaWiki with pretty URLs  
✅ PHP optimized for MediaWiki (256MB memory, 100MB uploads)  
✅ Database credentials saved to `/root/mediawiki.db`  
✅ Update script included for MediaWiki upgrades  

## Usage

### On ProxmoxVE Host

```bash
# Run the container creation script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/mediawiki.sh)"
```

### After Installation

1. Access the web installer at: `http://CONTAINER-IP/mw-config/index.php`

2. Use these database settings during installation:
   - **Database type:** PostgreSQL
   - **Database host:** localhost
   - **Database name:** mediawikidb
   - **Database username:** mediawiki
   - **Database password:** (found in `/root/mediawiki.db`)

3. For Redis session storage, add to `LocalSettings.php`:
   ```php
   $wgSessionCacheType = CACHE_REDIS;
   $wgObjectCaches['redis'] = [
       'class' => 'RedisBagOStuff',
       'servers' => [ '127.0.0.1:6379' ],
   ];
   ```

### Updating MediaWiki

Run the update script from inside the container:
```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/mediawiki.sh)" -s -- --update
```

## Database Credentials

Database credentials are automatically generated and saved to `/root/mediawiki.db`:
```
mediawikidb
mediawiki
<random_password>
```

## File Locations

- **MediaWiki:** `/var/www/mediawiki`
- **Nginx config:** `/etc/nginx/sites-available/mediawiki`
- **PHP config:** `/etc/php/8.2/fpm/php.ini`
- **PostgreSQL config:** `/etc/postgresql/*/main/`
- **Redis config:** `/etc/redis/redis.conf`
- **Database credentials:** `/root/mediawiki.db`
- **MediaWiki version:** `/root/mediawiki.version`

## Security Notes

- PostgreSQL is configured for local connections only
- Redis listens on localhost only
- Default Nginx configuration includes security headers
- Random password generated for database user
- Maintenance directory blocked from web access

## Nginx Configuration

The Nginx configuration includes:
- Pretty URLs (short URLs without index.php)
- 100MB upload limit
- PHP-FPM integration
- Static asset caching
- Maintenance directory protection
- Security headers

## Redis Configuration

Redis is configured with:
- 256MB memory limit
- LRU eviction policy
- Localhost-only binding
- Optimized for MediaWiki session caching

## Contribution

To submit these scripts to ProxmoxVE:

1. Submit to [ProxmoxVED](https://github.com/community-scripts/ProxmoxVED) (testing repository)
2. Place `mediawiki.sh` in `ct/` directory
3. Place `mediawiki-install.sh` in `install/` directory
4. Test thoroughly before submitting PR

## License

MIT License - Following ProxmoxVE Community Scripts standards

## Credits

- **MediaWiki:** https://www.mediawiki.org/
- **ProxmoxVE Community Scripts:** https://github.com/community-scripts/ProxmoxVE
