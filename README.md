# Docker Infrastructure Setup Guide
## Version 10.0 - FULLY AUTOMATED

Complete setup for Oxidized Backup and GitLab CE with **fully automated installation** and interactive configuration wizard.

---

## 🎯 What's New in Version 10.0

- ✅ **Interactive Configuration Wizard** - No manual config.env editing required
- ✅ **Fully Automated Installation** - Single command runs everything
- ✅ **Smart Reboot Detection** - Only reboots if Docker needs installation
- ✅ **Automatic CSR Generation** - For existing certificate mode
- ✅ **Certificate Verification Loop** - Waits until certs are valid
- ✅ **Auto-build & Start** - Containers built and started automatically
- ✅ **GitLab Integration** - SSH keys and projects created automatically

---

## 🚀 Quick Start (15 minutes for self-signed, 20 for existing certs)

### Prerequisites

- Ubuntu 24.04 LTS (fresh installation recommended)
- Root or sudo access
- Network configured with static IP
- DNS entries (if using real domains)

### Step 1: Download Files

```bash
# Create directory
mkdir -p ~/docker-infrastructure
cd ~/docker-infrastructure

# Download or copy these files:
# - master_setup.sh
# - config.env.example
# - scripts/ (entire directory)
```

### Step 2: Run Master Setup (THE ONLY COMMAND YOU NEED!)

```bash
sudo bash master_setup.sh
```

**That's it!** The script will:

1. ✅ Ask you configuration questions interactively
2. ✅ Generate config.env automatically
3. ✅ Validate all settings
4. ✅ Create directory structure
5. ✅ Generate all configurations
6. ✅ Install system packages
7. ✅ Install Docker (if needed - will reboot if necessary)
8. ✅ Create Docker networks
9. ✅ Setup certificates (auto-generate or wait for yours)
10. ✅ Configure firewall
11. ✅ Build Docker containers
12. ✅ Start all services
13. ✅ Setup GitLab integration (if both services enabled)
14. ✅ Verify everything is running

### Interactive Configuration Wizard

When you run `master_setup.sh`, you'll be asked:

```
=== Organization Settings ===
Organization Name [ORGNAME]: MyCompany
Domain [example.com]: mycompany.com

=== Installation Options ===
Install Oxidized? [Y/n]: Y
Install GitLab? [Y/n]: Y

=== Certificate Mode ===
1) Self-signed (automatic, for testing)
2) Existing (from Windows CA or other)
Choose [1]: 1

=== System Users ===
Admin username [administrator]: admin
Docker username [dockeruser]: dockeruser
Docker user password: ********

=== GitLab Settings ===
GitLab root password: ********
GitLab Oxidized user password [Ox1d1z3d!B@ckUp#2025]: ********

=== Device Credentials ===
Default device username [backup]: backup
Default device password: ********

=== Network Devices ===
Enter devices in format: IP:MODEL:USERNAME:PASSWORD
Example: 10.99.99.50:panos:backup:password
Leave empty when done.

Device 1: 10.99.99.50:panos:backup:mypassword
Device 2: 192.168.1.1:ios:admin:cisco123
Device 3: [ENTER to finish]

=== Network Settings ===
Allowed management network [192.168.71.0/28]: 192.168.1.0/24
```

The script will then automatically create `config.env` with your settings.

---

## 🔄 Two Installation Paths

### Path A: Self-Signed Certificates (Fully Automatic)

```bash
sudo bash master_setup.sh
```

**Follow prompts, choose option 1 for certificates.**

If Docker needs installation:
- System will reboot automatically
- After reboot: `cd /opt/docker-infrastructure && sudo ./scripts/00_continue_setup.sh`

If Docker already installed:
- Everything runs to completion
- Services start automatically
- Done!

**Total time:** ~15 minutes

### Path B: Existing Certificates (Semi-Automatic)

```bash
sudo bash master_setup.sh
```

**Follow prompts, choose option 2 for certificates.**

The script will:
1. Generate CSRs automatically
2. Display CSR locations
3. **PAUSE** and wait for you to:
   - Submit CSRs to your CA
   - Download signed certificates
   - Place them in `certificates/ssl/`
4. Verify certificates in a loop
5. Continue automatically once certs are valid

**Total time:** ~20 minutes + CA processing time

---

## 📊 What Gets Installed

### Services Installed (Based on Your Choices)

| Service | Purpose | Port |
|---------|---------|------|
| Oxidized | Network device backup | 8888 (internal), 443 (HTTPS) |
| GitLab CE | Git repository server | 2222 (SSH), 443 (HTTPS) |
| Nginx | Reverse proxy | 80, 443 |

### Directory Structure Created

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
│   ├── 00_continue_setup.sh (created if reboot needed)
│   ├── 01_initial_setup.sh
│   ├── 02_setup_networks.sh
│   ├── 03_certificate_setup.sh
│   ├── 04_generate_csr.sh
│   ├── 05_verify_certificates.sh
│   ├── 06_setup_ssh_and_gitlab.sh
│   ├── 07_setup_firewall.sh
│   ├── 08_check_status.sh
│   └── 09_backup.sh
├── logs/                    # All logs
├── config.env               # Generated configuration
├── docker-compose.yml       # Generated
└── README.md
```

---

## 🔍 Monitoring & Verification

### Check Status

```bash
cd /opt/docker-infrastructure
./scripts/08_check_status.sh
```

**Output shows:**
- Running containers
- Health status
- Networks
- Recent backups

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs oxidized --tail 50
docker logs gitlab-ce --tail 50
docker logs nginx-proxy --tail 50

# Oxidized wrapper log
docker exec oxidized cat /var/log/oxidized/wrapper_$(date +%Y%m%d).log

# Git push hook log
docker exec oxidized cat /var/log/oxidized/git_push_hook.log

# Setup logs
ls -lh /opt/docker-infrastructure/logs/
```

### Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Oxidized | `https://oxidized.yourdomain.com` | No auth required |
| GitLab | `https://gitlab.yourdomain.com` | root / (check logs) |

**Get GitLab root password:**

```bash
# From container
docker exec gitlab-ce cat /etc/gitlab/initial_root_password

# From logs
cat /opt/docker-infrastructure/logs/06_ssh_gitlab_*.log | grep "Password:"
```

---

## 🐛 Troubleshooting

### Script Stops with "Reboot Required"

**This is normal!** Docker was just installed.

```bash
# After reboot
cd /opt/docker-infrastructure
sudo ./scripts/00_continue_setup.sh
```

### Certificates Not Valid (Existing Mode)

The script will wait in a loop until certificates are valid.

**Check these files exist:**
```bash
ls -lh /opt/docker-infrastructure/certificates/ssl/
# Should show:
# oxidized.yourdomain.com.crt
# oxidized.yourdomain.com.key
# gitlab.yourdomain.com.crt (if GitLab installed)
# gitlab.yourdomain.com.key (if GitLab installed)
```

**Verify manually:**
```bash
cd /opt/docker-infrastructure
./scripts/05_verify_certificates.sh
```

### Container Won't Start

```bash
# Check logs
docker logs <container-name>

# Rebuild
docker compose down
docker compose build --no-cache
docker compose up -d

# Check status
docker ps -a
```

### Oxidized Not Backing Up Devices

```bash
# Check device connectivity
docker exec oxidized ping -c 3 10.99.99.50

# Check Oxidized config
docker exec oxidized cat /etc/oxidized/config

# Check router.db
docker exec oxidized cat /opt/oxidized/router.db

# Trigger manual backup
docker exec oxidized curl -X POST http://localhost:8888/reload

# Check logs
docker logs oxidized --tail 100
```

### Oxidized Can't Push to GitLab

```bash
# Test SSH connection
docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce

# Check Git remote
docker exec oxidized git -C /opt/oxidized/devices.git remote -v
# Should show: git@gitlab-ce:oxidized/network.git

# Check hook log
docker exec oxidized cat /var/log/oxidized/git_push_hook.log
```

### GitLab Web UI Not Accessible

```bash
# Check if running
docker ps | grep gitlab

# Check GitLab status
docker exec gitlab-ce gitlab-ctl status

# Reconfigure
docker exec gitlab-ce gitlab-ctl reconfigure

# Wait longer (GitLab takes 3-5 minutes to fully start)
```

### Port Already in Use

Edit `/opt/docker-infrastructure/config.env`:

```bash
# Change ports
NGINX_HTTP_PORT="8080"
NGINX_HTTPS_PORT="8443"
GITLAB_SSH_PORT="2223"

# Regenerate
cd /opt/docker-infrastructure
sudo bash master_setup.sh  # Will use existing config.env
```

---

## 🔄 Maintenance

### Add More Devices

```bash
cd /opt/docker-infrastructure

# Edit config.env
nano config.env

# Add devices
DEVICE_3="192.168.1.3:junos:admin:password:"
DEVICE_4="192.168.1.4:ios:admin:password:"

# Regenerate configuration
sudo bash master_setup.sh  # Uses existing config, only updates changed parts

# Or rebuild Oxidized manually
docker compose build --no-cache oxidized
docker compose up -d oxidized
```

### Update Services

```bash
cd /opt/docker-infrastructure

# Pull latest images
docker compose pull

# Restart
docker compose down
docker compose up -d
```

### Backup

```bash
cd /opt/docker-infrastructure

# Manual backup
./scripts/09_backup.sh

# Setup automated backups (cron)
crontab -e
# Add: 0 2 * * * /opt/docker-infrastructure/scripts/09_backup.sh
```

### Restore from Backup

```bash
cd /opt/docker-infrastructure

# Stop services
docker compose down

# Restore volumes
cd /opt/backups/YYYYMMDD_HHMMSS/
docker run --rm -v oxidized_data:/data -v $(pwd):/backup alpine tar xzf /backup/oxidized_data.tar.gz -C /data
docker run --rm -v gitlab_data:/data -v $(pwd):/backup alpine tar xzf /backup/gitlab_data.tar.gz -C /data

# Restore configs
cp -r nginx /opt/docker-infrastructure/
cp -r oxidized /opt/docker-infrastructure/
cp -r gitlab /opt/docker-infrastructure/

# Start
cd /opt/docker-infrastructure
docker compose up -d
```

---

## 🔐 Security Best Practices

1. ✅ **Use strong passwords** (12+ characters, mixed case, numbers, symbols)
2. ✅ **Use existing certificates** (not self-signed) in production
3. ✅ **Enable firewall** (UFW_ENABLED="true" in config)
4. ✅ **Restrict management network** (set ALLOWED_NETWORK correctly)
5. ✅ **Regular backups** (setup cron job)
6. ✅ **Update regularly** (docker compose pull)
7. ✅ **Monitor logs** (check for failed login attempts)
8. ✅ **Change default passwords** immediately after setup

---

## ❓ FAQ

**Q: Can I run this on an existing server with Docker?**

A: Yes! Set `SKIP_DOCKER_INSTALL="true"` in config.env before running, or if using the wizard, the script will detect existing Docker and skip installation.

**Q: Do I need both Oxidized and GitLab?**

A: No! You can install just Oxidized, just GitLab, or both. The wizard asks which services you want.

**Q: What if I make a mistake in the configuration wizard?**

A: Just delete `config.env` and run `master_setup.sh` again. Or edit `config.env` manually and re-run the script.

**Q: Can I change settings later?**

A: Yes! Edit `/opt/docker-infrastructure/config.env` and run `sudo bash master_setup.sh` again. It will regenerate configurations with new settings.

**Q: How long does GitLab take to start?**

A: 3-5 minutes for full initialization. The script waits automatically.

**Q: Can I use Let's Encrypt certificates?**

A: Yes! Choose "existing certificates" mode, use certbot to get Let's Encrypt certs, and place them in `certificates/ssl/`.

**Q: What if my server doesn't have internet access?**

A: You'll need to pre-install Docker and download all required packages offline. This script assumes internet connectivity.

---

## 📝 Configuration Reference

### config.env Sections

The wizard generates all of this automatically, but you can also edit manually:

```bash
# Organization
ORG_NAME="MyCompany"
DOMAIN="example.com"

# Services
INSTALL_OXIDIZED="true"
INSTALL_GITLAB="true"

# Certificate mode
CERT_MODE="selfsigned"  # or "existing"

# Users
ADMIN_USER="administrator"
DOCKER_USER="dockeruser"
DOCKER_USER_PASSWORD="SecurePassword123!"

# Passwords
GITLAB_ROOT_PASSWORD="GitLabRootPass123!"
GITLAB_OXIDIZED_PASSWORD="Ox1d1z3d!B@ckUp#2025"
DEVICE_DEFAULT_PASSWORD="DeviceBackupPass123!"

# Devices
DEVICE_1="10.99.99.50:panos:backup:password:"
DEVICE_2="192.168.1.1:ios:admin:cisco123:"

# Network
ALLOWED_NETWORK="192.168.1.0/24"
```

---

## ✅ Success Checklist

After installation completes, verify:

- [ ] All scripts executed without errors
- [ ] `docker ps` shows all containers running
- [ ] `docker network ls` shows oxinet, gitlabnet, nginxnet
- [ ] Services accessible in browser
- [ ] Oxidized backing up devices (check logs)
- [ ] GitLab receiving commits (if using both)
- [ ] Firewall configured: `sudo ufw status`
- [ ] Backup script works: `./scripts/09_backup.sh`

---

## 🎓 Advanced Topics

### Custom Network Ranges

In `config.env`:

```bash
OXINET_SUBNET="10.1.0.0/24"
OXINET_OXIDIZED_IP="10.1.0.10"
```

### Multiple Oxidized Instances

Change container name and IP in `config.env`, then regenerate.

### External Database

For GitLab, edit `gitlab/config/gitlab.rb` after setup to use external PostgreSQL.

---

## 📚 Additional Resources

- [Oxidized Documentation](https://github.com/ytti/oxidized)
- [GitLab Documentation](https://docs.gitlab.com)
- [Docker Documentation](https://docs.docker.com)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

## 🎉 That's It!

With Version 10.0, you get a **fully automated setup** from start to finish.

Just run `sudo bash master_setup.sh`, answer a few questions, and everything else is handled automatically!

**Questions? Issues?** Check the troubleshooting section or review logs in `/opt/docker-infrastructure/logs/`.

---

**Version:** 10.0  
**Last Updated:** 2025  
**License:** MIT