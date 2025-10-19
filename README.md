# Docker Infrastructure Setup Guide
## Version 8.0 FINAL - Production Ready

Complete setup for Oxidized Backup and GitLab CE with flexible configuration.

---

## 📋 Features

- ✅ **Config.env based** - All settings in one file
- ✅ **Flexible installation** - Choose Oxidized, GitLab, or both
- ✅ **Certificate options** - Self-signed OR existing certificates
- ✅ **Docker networking** - Correct container communication
- ✅ **Complete automation** - All scripts generated automatically
- ✅ **Production ready** - Logging, backups, monitoring

---

## 🚀 Quick Start (20 minutes)

### Prerequisites

- Ubuntu 24.04 LTS (fresh installation)
- Root or sudo access
- Network configured with static IP
- DNS entries (for external domains)

### Step 1: Download Files

```bash
# Create directory
mkdir -p /tmp/docker-infrastructure
cd /tmp/docker-infrastructure

# Copy these 3 files here:
# - config.env
# - master_setup.sh
# - README.md (this file)
```

### Step 2: Configure

Edit `config.env` with your settings:

```bash
nano config.env
```

**Critical settings to review:**

```bash
# Organization
ORG_NAME="Simple Designer"
DOMAIN="simple-designer.ch"

# What to install
INSTALL_OXIDIZED="true"   # Set to "false" to skip
INSTALL_GITLAB="true"     # Set to "false" to skip

# Certificate mode
CERT_MODE="selfsigned"    # OR "existing"

# Users
ADMIN_USER="administrator"
DOCKER_USER="dockeruser"
DOCKER_USER_PASSWORD="Docker123!"

# Passwords
GITLAB_ROOT_PASSWORD="SuperSecureP@ssw0rd2025!"
DEVICE_DEFAULT_PASSWORD="backup1234!"

# Network IPs (adjust if needed)
OXINET_OXIDIZED_IP="172.16.0.2"
GITLABNET_GITLAB_IP="172.16.0.18"
```

### Step 3: Run Master Setup

```bash
cd /tmp/docker-infrastructure
sudo bash master_setup.sh
```

This will:
- Load config.env
- Validate all settings
- Create `/opt/docker-infrastructure`
- Generate all scripts and configurations
- Take ~2 minutes

### Step 4: Initial System Setup

```bash
cd /opt/docker-infrastructure
sudo ./scripts/01_initial_setup.sh
```

This installs:
- Base packages
- Docker Engine
- Creates users

**⚠️ REBOOT REQUIRED after this step!**

```bash
sudo reboot
```

### Step 5: Setup Networks

After reboot:

```bash
cd /opt/docker-infrastructure
./scripts/02_setup_networks.sh
```

Creates Docker networks (oxinet, gitlabnet, nginxnet)

### Step 6: Setup Certificates

#### Option A: Self-Signed (Quick)

```bash
./scripts/03_certificate_setup.sh
```

Done! Certificates auto-generated.

#### Option B: Existing Certificates (Production)

If using Windows CA or Let's Encrypt:

```bash
# Generate CSRs
./scripts/04_generate_csr.sh oxidized.simple-designer.ch
./scripts/04_generate_csr.sh gitlab.simple-designer.ch

# Submit CSRs to your CA, get signed certificates

# Copy signed certificates to:
# certificates/ssl/oxidized.simple-designer.ch.crt
# certificates/ssl/gitlab.simple-designer.ch.crt

# Verify
./scripts/05_verify_certificates.sh
```

### Step 7: Setup Firewall

```bash
./scripts/07_setup_firewall.sh
```

### Step 8: Build and Start

```bash
cd /opt/docker-infrastructure

# Build containers
docker compose build --no-cache

# Start services
docker compose up -d

# Watch logs
docker compose logs -f
```

### Step 9: Initialize GitLab (if installed)

Wait 5 minutes for services to fully start:

```bash
./scripts/08_init_gitlab.sh
```

This creates:
- Oxidized user in GitLab
- Network project
- Access token

### Step 10: Setup SSH Keys (if both services)

```bash
./scripts/06_setup_ssh_keys.sh
```

Follow prompts to add deploy key to GitLab.

---

## 📊 Installation Matrix

| Component | Self-Signed Cert | Existing Cert | Both Services | GitLab Only | Oxidized Only |
|-----------|-----------------|---------------|---------------|-------------|---------------|
| Scripts 01-02 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Script 03 | Auto-generate | Manual copy | ✅ | ✅ | ✅ |
| Script 04 | Skip | Generate CSR | ✅ | ✅ | ✅ |
| Script 05 | Verify | Verify | ✅ | ✅ | ✅ |
| Script 06 | N/A | N/A | ✅ only | ❌ | ❌ |
| Script 07 | Firewall | Firewall | ✅ | ✅ | ✅ |
| Script 08 | N/A | N/A | ✅ | ✅ | ❌ |
| Script 09 | Status | Status | ✅ | ✅ | ✅ |

---

## 🔧 Configuration Reference

### config.env Sections

#### 1. Organization Settings
```bash
ORG_NAME="Your Company"
DOMAIN="example.com"
```

#### 2. Installation Options
```bash
INSTALL_OXIDIZED="true"  # Install Oxidized
INSTALL_GITLAB="true"    # Install GitLab
```

#### 3. Certificate Mode
```bash
CERT_MODE="selfsigned"   # OR "existing"
```

**Self-signed:**
- Automatic certificate generation
- CA certificate created
- Good for testing/internal use

**Existing:**
- Use Windows CA, Let's Encrypt, etc.
- Generate CSRs with script 04
- Submit to your CA
- Copy signed certs to certificates/ssl/

#### 4. Network Configuration
```bash
# Oxidized Network
OXINET_SUBNET="172.16.0.0/28"
OXINET_OXIDIZED_IP="172.16.0.2"

# GitLab Network
GITLABNET_SUBNET="172.16.0.16/28"
GITLABNET_GITLAB_IP="172.16.0.18"
```

**Important:** These are Docker internal IPs, not your server IP.

#### 5. Device Configuration
```bash
# Default credentials for all devices
DEVICE_DEFAULT_USERNAME="backup"
DEVICE_DEFAULT_PASSWORD="backup1234!"
DEVICE_DEFAULT_MODEL="panos"

# Individual devices
DEVICE_1="10.99.99.50:panos:backup:password:"
DEVICE_2="192.168.1.1:ios:admin:password:"
```

---

## 🌐 Service Access

### After Installation

| Service | URL | Port | Notes |
|---------|-----|------|-------|
| Oxidized Web | https://oxidized.simple-designer.ch | 443 | Config backup UI |
| GitLab Web | https://gitlab.simple-designer.ch | 443 | Git repository |
| GitLab SSH | gitlab.simple-designer.ch | 2222 | Git push/pull |

### Default Credentials

#### GitLab Root
```bash
# Get initial password
docker exec gitlab-ce cat /etc/gitlab/initial_root_password

# Or check logs
cat logs/08_gitlab_init_*.log | grep Password
```

#### GitLab Oxidized User
- Username: `oxidized`
- Password: (from config.env `GITLAB_OXIDIZED_PASSWORD`)
- Default: `Ox1d1z3d!B@ckUp#2025`

#### System Users
- Admin: `administrator`
- Docker: `dockeruser` / `Docker123!`

---

## 📁 Directory Structure

```
/opt/docker-infrastructure/
├── certificates/
│   ├── ca/                  # CA certificates
│   ├── ssl/                 # Domain certificates
│   ├── csr/                 # Certificate requests
│   └── selfsigned/          # Self-signed certs
├── nginx/
│   ├── nginx.conf
│   └── conf.d/              # Site configs
├── oxidized/
│   ├── config/
│   │   ├── config           # Oxidized config
│   │   ├── router.db        # Device list
│   │   ├── oxidized_wrapper.sh
│   │   └── git_push_hook.sh
│   ├── keys/                # SSH keys
│   └── Dockerfile
├── gitlab/
│   └── config/
│       └── gitlab.rb
├── scripts/
│   ├── 01_initial_setup.sh
│   ├── 02_setup_networks.sh
│   ├── 03_certificate_setup.sh
│   ├── 04_generate_csr.sh
│   ├── 05_verify_certificates.sh
│   ├── 06_setup_ssh_keys.sh
│   ├── 07_setup_firewall.sh
│   ├── 08_init_gitlab.sh
│   ├── 09_check_status.sh
│   └── backup.sh
├── logs/                    # All operation logs
├── config.env               # Configuration
├── docker-compose.yml
└── README.md
```

---

## 🔍 Monitoring

### Check Status

```bash
# Quick status
cd /opt/docker-infrastructure
./scripts/09_check_status.sh

# Detailed container logs
docker logs oxidized --tail 50
docker logs gitlab-ce --tail 50
docker logs nginx-proxy --tail 50

# All logs
docker compose logs -f

# Oxidized wrapper log
docker exec oxidized cat /var/log/oxidized/wrapper_$(date +%Y%m%d).log

# Git push log
docker exec oxidized cat /var/log/oxidized/git_push_hook.log
```

### View Backups

```bash
# Oxidized backup repository
docker exec oxidized bash
cd /opt/oxidized/devices.git
git log --oneline
ls -la
```

### Resource Usage

```bash
docker stats --no-stream
```

---

## 🐛 Troubleshooting

### Problem: Docker not installed

```bash
# Check if script 01 completed
ls /usr/bin/docker

# If missing, re-run
./scripts/01_initial_setup.sh
sudo reboot
```

### Problem: User not in docker group

```bash
# Check groups
groups

# If 'docker' not listed
newgrp docker

# Or logout and login again
```

### Problem: Certificates don't match

```bash
# Verify all certificates
./scripts/05_verify_certificates.sh

# Check specific cert
openssl x509 -in certificates/ssl/oxidized.simple-designer.ch.crt -text -noout
```

### Problem: Oxidized not backing up

```bash
# Check if device is reachable
docker exec oxidized ping -c 3 10.99.99.50

# Check Oxidized logs
docker logs oxidized --tail 100

# Check config
docker exec oxidized cat /etc/oxidized/config

# Trigger manual backup
docker exec oxidized curl -X POST http://localhost:8888/reload
```

### Problem: GitLab not accessible

```bash
# Check if running
docker ps | grep gitlab

# Check health
docker exec gitlab-ce gitlab-ctl status

# Check logs
docker logs gitlab-ce --tail 100

# Reconfigure
docker exec gitlab-ce gitlab-ctl reconfigure
```

### Problem: Oxidized can't push to GitLab

```bash
# Check SSH keys exist
docker exec oxidized ls -la /etc/oxidized/keys/

# Test SSH connection (Docker networking)
docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce

# Check known_hosts
docker exec oxidized cat /opt/oxidized/.ssh/known_hosts

# Check Git remote
docker exec oxidized git -C /opt/oxidized/devices.git remote -v

# Expected: git@gitlab-ce:oxidized/network.git
```

### Problem: Wrong Git remote URL

If you see external domain instead of `gitlab-ce`:

```bash
# Fix remote URL
docker exec oxidized bash -c "
cd /opt/oxidized/devices.git
git remote remove origin
git remote add origin git@gitlab-ce:oxidized/network.git
"

# Rebuild oxidized
docker compose stop oxidized
docker compose build --no-cache oxidized
docker compose up -d oxidized
```

---

## 🔄 Maintenance

### Backup

```bash
# Manual backup
cd /opt/docker-infrastructure
./scripts/backup.sh

# Automated backups (cron)
crontab -e
# Add: 0 2 * * * /opt/docker-infrastructure/scripts/backup.sh
```

### Update Services

```bash
cd /opt/docker-infrastructure

# Pull latest images
docker compose pull

# Restart services
docker compose up -d

# Rebuild Oxidized (if config changed)
docker compose build --no-cache oxidized
docker compose up -d oxidized
```

### Add More Devices

```bash
# Edit config.env
nano config.env

# Add device
DEVICE_2="192.168.1.2:ios:admin:password:"

# Regenerate router.db
sudo bash master_setup.sh

# Rebuild Oxidized
docker compose build --no-cache oxidized
docker compose up -d oxidized
```

### View Logs

```bash
# All setup logs
ls -lh logs/

# Latest setup
tail -f logs/master_setup_*.log

# Live container logs
docker compose logs -f
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore volumes
cd /opt/backups/YYYYMMDD_HHMMSS/
docker run --rm -v oxidized_data:/data -v $(pwd):/backup alpine tar xzf /backup/oxidized_data.tar.gz -C /data

# Restore configs
cp -r nginx /opt/docker-infrastructure/
cp -r oxidized /opt/docker-infrastructure/

# Start services
cd /opt/docker-infrastructure
docker compose up -d
```

---

## 🔐 Security Best Practices

1. **Change default passwords** in config.env before deployment
2. **Use existing certificates** (not self-signed) for production
3. **Enable firewall** (`UFW_ENABLED="true"`)
4. **Restrict management network** (`ALLOWED_NETWORK`)
5. **Regular backups** (automate with cron)
6. **Update regularly** (docker compose pull)
7. **Monitor logs** (check for failed login attempts)
8. **Use strong passwords** (12+ characters, mixed case, numbers, symbols)

---

## 📞 Support

### Common Issues

- **Port conflicts:** Change ports in config.env
- **Out of memory:** Adjust `GITLAB_MEMORY_LIMIT`
- **Slow GitLab:** Increase server RAM (min 4GB recommended)
- **Device not backing up:** Check firewall, credentials, network
- **SSH issues:** Regenerate keys with script 06

### Log Locations

| Log Type | Location |
|----------|----------|
| Master setup | `logs/master_setup_*.log` |
| Scripts | `logs/XX_*_*.log` |
| Oxidized wrapper | Container: `/var/log/oxidized/wrapper_*.log` |
| Git push hook | Container: `/var/log/oxidized/git_push_hook.log` |
| Docker containers | `docker logs <container>` |

---

## 📝 Version History

- **v8.0** - Config.env based, selfsigned support, service selection
- **v7.x** - Docker networking fixes
- **v6.x** - Initial automated setup
- **v5.x** - Manual configuration

---

## ✅ Success Checklist

After installation, verify:

- [ ] All scripts executed without errors
- [ ] Docker containers running: `docker ps`
- [ ] Networks created: `docker network ls`
- [ ] Certificates valid: `./scripts/05_verify_certificates.sh`
- [ ] Firewall configured: `sudo ufw status`
- [ ] Services accessible via browser
- [ ] Oxidized backing up devices
- [ ] GitLab receiving commits (if using GitLab)
- [ ] Logs clean: `docker compose logs`
- [ ] Backup script works: `./scripts/backup.sh`

---

## 🎓 Advanced Configuration

### Custom Network Ranges

Edit in config.env:

```bash
OXINET_SUBNET="10.1.0.0/24"
OXINET_OXIDIZED_IP="10.1.0.10"
```

### Multiple Oxidized Instances

Change IPs and ports:

```bash
OXINET_OXIDIZED_IP="172.16.0.3"
OXIDIZED_REST_PORT="8889"
```

### External PostgreSQL

Modify gitlab.rb after setup:

```ruby
postgresql['enable'] = false
gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_host'] = 'postgres.example.com'
```

---

## 📚 Additional Resources

- Oxidized Documentation: https://github.com/ytti/oxidized
- GitLab Documentation: https://docs.gitlab.com
- Docker Documentation: https://docs.docker.com
- Nginx Documentation: https://nginx.org/en/docs/

---

**🎉 That's it! You now have a complete, production-ready infrastructure.**

For questions or issues, check the troubleshooting section or review the logs.