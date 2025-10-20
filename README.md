# Docker Infrastructure Oxidized and Gitlab Setup Guide
## Version 11.0 - PURE SSH AUTHENTICATION

Complete automated setup for Oxidized Backup and GitLab CE with **SSH Deploy Key authentication** (NO tokens required).

---

## 🎯 What's New in Version 11.0

- ✅ **Pure SSH Authentication** - Deploy Keys only, no API tokens needed
- ✅ **Interactive Configuration Wizard** - No manual config.env editing required
- ✅ **Fully Automated Installation** - Single command runs everything
- ✅ **Smart Reboot Detection** - Only reboots if Docker needs installation
- ✅ **Automatic Password Generation** - Secure passwords generated automatically
- ✅ **Simplified GitLab Integration** - Manual web UI configuration with clear instructions
- ✅ **Fast Backup Interval** - 5-minute backup cycles (300 seconds)
- ✅ **Auto-build & Start** - Containers built and started automatically

---

## 🚀 Quick Start (15-20 minutes total)

### Prerequisites

- Ubuntu 24.04 LTS (fresh installation recommended)
- Root or sudo access
- Network configured with static IP
- DNS entries for your domains (or edit /etc/hosts)
- At least 4GB RAM (8GB recommended if using GitLab)

### Step 1: Download Files

```bash
# Create directory
mkdir -p ~/docker-infrastructure
cd ~/docker-infrastructure

# Download or copy all files:
# - master_setup.sh
# - config.env.example
# - scripts/ (entire directory with all .sh files)
# - README.md (this file)
```

### Step 2: Run Master Setup (THE ONLY COMMAND YOU NEED!)

```bash
sudo bash master_setup.sh
```

**That's it!** The script will guide you through everything.

---

## 📋 Interactive Configuration Wizard

When you run `master_setup.sh`, you'll be asked configuration questions:

```
╔══════════════════════════════════════════════╗
║  Docker Infrastructure Master Setup          ║
║  Version 11.0 - SSH ONLY (No Token)          ║
╚══════════════════════════════════════════════╝

=== Organization Settings ===
Organization Name [ORGNAME]: MyCompany
Domain [example.com]: mycompany.local

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

Generating secure passwords...

=== Device Credentials ===
Default device username [backup]: backup
Auto-generating device password...

=== Network Devices ===
Enter devices in format: IP:MODEL[:USERNAME[:PASSWORD]]
Example: 10.99.99.50:panos
         10.99.99.51:panos:admin
         10.99.99.52:ios:admin:custompass

Username and password are optional (will use defaults if not provided)
Leave empty when done.

Device 1: 10.99.99.50:panos
Device 2: 192.168.1.1:ios:admin
Device 3: [ENTER to finish]

=== Network Settings ===
Allowed management network [192.168.71.0/28]: 192.168.1.0/24
```

**All passwords are auto-generated** and displayed at the end of installation.

---

## 🔄 Installation Flow

### Automatic Process

1. ✅ **Configuration Generation** - Wizard creates config.env
2. ✅ **Directory Structure** - All folders created automatically
3. ✅ **System Setup** - Packages and Docker installed
4. ✅ **Network Creation** - Docker networks configured
5. ✅ **Certificate Setup** - Self-signed certs generated (or CSRs for existing)
6. ✅ **Firewall Configuration** - UFW rules applied
7. ✅ **Container Build** - Docker images built
8. ✅ **Service Startup** - All containers started
9. ✅ **GitLab Integration** - Manual SSH Deploy Key setup (guided)
10. ✅ **Status Verification** - Health checks performed

### Reboot Handling

If Docker needs to be installed, the system will:
- Install Docker
- Display a reboot prompt
- After reboot, simply run the same command again
- The script automatically continues from where it left off

---

## 🔐 SSH Authentication Method

### How It Works

**Version 11.0 uses PURE SSH authentication:**

1. **SSH Key Pair Generation** - Ed25519 key pair created automatically
2. **Deploy Key** - Public key added to GitLab project (manual step with guidance)
3. **SSH Push** - Oxidized pushes via SSH using the private key
4. **No Tokens** - No API tokens, no personal access tokens required

### Why SSH Only?

- ✅ **More Secure** - Deploy Keys have repository-specific access
- ✅ **Simpler** - No token expiration management
- ✅ **Standard Git** - Uses native Git SSH protocol
- ✅ **Write Access** - Deploy Key with write permission enables push
- ✅ **No API** - Doesn't require GitLab API access

---

## 📊 What Gets Installed

### Services (Based on Your Choices)

| Service | Purpose | Port | Notes |
|---------|---------|------|-------|
| Oxidized | Network device backup | 8888 (internal) | 5-minute intervals |
| GitLab CE | Git repository server | 2222 (SSH), 443 (HTTPS) | Full GitLab instance |
| Nginx | Reverse proxy | 80, 443 | SSL termination |

### Docker Networks

- **oxinet** (172.16.0.0/28) - Oxidized network
- **gitlabnet** (172.16.0.16/28) - GitLab network
- **nginxnet** (172.16.0.32/28) - Nginx network

### Directory Structure

```
/opt/docker-infrastructure/
├── certificates/
│   ├── ca/                  # CA certificates (self-signed mode)
│   ├── ssl/                 # Domain certificates
│   ├── csr/                 # Certificate requests (existing mode)
│   └── selfsigned/          # Self-signed CA and CSRs
├── nginx/
│   ├── nginx.conf           # Main Nginx config
│   └── conf.d/              # Site-specific configs
│       ├── oxidized.conf
│       └── gitlab.conf
├── oxidized/
│   ├── config/
│   │   ├── config           # Oxidized configuration
│   │   ├── router.db        # Device list
│   │   └── oxidized_wrapper.sh
│   ├── keys/                # SSH keys for GitLab
│   │   ├── gitlab           # Private key
│   │   └── gitlab.pub       # Public key (Deploy Key)
│   └── Dockerfile
├── gitlab/
│   └── config/
│       └── gitlab.rb        # GitLab configuration
├── scripts/
│   ├── 01_initial_setup.sh
│   ├── 02_setup_networks.sh
│   ├── 03_certificate_setup.sh
│   ├── 04_generate_csr.sh
│   ├── 05_verify_certificates.sh
│   ├── 06_setup_ssh_and_gitlab.sh  # SSH integration
│   ├── 07_setup_firewall.sh
│   ├── 08_check_status.sh
│   ├── 09_backup.sh
│   └── trigger_backup.sh
├── logs/                    # All installation and operation logs
├── config.env               # Generated configuration
├── docker-compose.yml       # Generated Docker Compose file
├── GENERATED_PASSWORDS.txt  # Auto-generated passwords (SAVE THIS!)
├── INSTALLATION_CONFIG.txt  # Configuration summary
└── README.md                # This file
```

---

## 🖼️ Example Setup with Screenshots

### Step-by-Step Visual Guide

This section provides a complete walkthrough with placeholders for screenshots.

#### 1. Initial Wizard

**Screenshot 1: Configuration Wizard Start**
```
<img width="1373" height="1390" alt="image" src="https://github.com/user-attachments/assets/0b7bdcde-a41b-4c7a-a070-6a26bc128153" />

```

**What you'll see:**
- Organization name prompt
- Domain configuration
- Service selection (Oxidized/GitLab)
- Certificate mode selection

---

#### 2. Automatic Installation Progress

**Screenshot 2: Installation Running**
```
<img width="1373" height="1390" alt="image" src="https://github.com/user-attachments/assets/4e803c37-0e2a-42dc-a8c7-cf5bb759ea69" />

```

**What happens:**
- Package installation
- Docker setup
- Network creation
- Certificate generation

---

#### 3. Reboot (If Needed)

**Screenshot 3: Reboot Prompt**
<img width="726" height="302" alt="image" src="https://github.com/user-attachments/assets/30a02b69-1d31-432b-b8fc-56e2046bfd28" />



**If Docker was installed:**
- System prompts for reboot
- After reboot, run the same command
- Script continues automatically

<img width="801" height="57" alt="image" src="https://github.com/user-attachments/assets/de54a257-087e-4a6b-a4c3-067436fbb2db" />
<img width="698" height="504" alt="image" src="https://github.com/user-attachments/assets/4c83a189-87fe-4974-9d05-d6bf406e6b20" />

---

#### 4. GitLab First Login

**Screenshot 4: GitLab Login Page**
<img width="1182" height="607" alt="image" src="https://github.com/user-attachments/assets/f4a477bc-5178-44d2-aef2-56d3e874b8ff" />


**Login with:**
- Username: `root`
- Password: (from GENERATED_PASSWORDS.txt)

---

#### 5. Create Oxidized User

**Screenshot 5: GitLab Admin - New User**
<img width="1920" height="1200" alt="image" src="https://github.com/user-attachments/assets/c8a9eb6f-bef1-485d-8787-bf8a305381b5" />


**Fill in:**
- Name: Oxidized Backup Service
- Username: oxidized
- Email: oxidized@example.com

**Screenshot 6: Set User Password**
<img width="751" height="823" alt="image" src="https://github.com/user-attachments/assets/6fc104e7-4534-42be-8a08-195aaf2170fa" />
<img width="1404" height="451" alt="image" src="https://github.com/user-attachments/assets/8c177db5-7ba8-488e-b922-1e9146ded89c" />
<img width="795" height="922" alt="image" src="https://github.com/user-attachments/assets/573db28b-5ee7-4232-ac5f-80997a3b5f89" />


---

#### 6. Login as Oxidized User

**Screenshot 7: Login as Oxidized**
<img width="816" height="530" alt="image" src="https://github.com/user-attachments/assets/e208290b-eb05-4d8f-9a7c-0d920194ea8e" />


**Screenshot 8: Change Password Prompt**
<img width="891" height="553" alt="image" src="https://github.com/user-attachments/assets/83c78f4d-f8bc-4d1b-9e61-8956e7983b03" />
<img width="720" height="496" alt="image" src="https://github.com/user-attachments/assets/6ce03c5f-9e07-44cf-ac57-bbd945e2c2a7" />
---

#### 7. Create Network Project

**Screenshot 9: New Project**
<img width="1132" height="553" alt="image" src="https://github.com/user-attachments/assets/ea6c1955-c773-4ac1-9a6f-e9ca164da8d2" />


**Screenshot 10: Create Blank Project**
<img width="986" height="434" alt="image" src="https://github.com/user-attachments/assets/ffb5e559-f037-4919-a0c0-997a967f0bce" />


**Screenshot 11: Project Settings**
<img width="1346" height="752" alt="image" src="https://github.com/user-attachments/assets/71173353-87a4-40cc-9fd9-03b2e93b5867" />


**Screenshot 12: Empty Project Created**
<img width="1920" height="1200" alt="image" src="https://github.com/user-attachments/assets/b0909447-234b-4aa6-b59a-547bb95cafe4" />

---

#### 8. Add SSH Deploy Key

**Screenshot 13: Project Settings - Repository**
<img width="1685" height="429" alt="image" src="https://github.com/user-attachments/assets/d236d64b-93e3-4a2d-92ad-873fca3cca38" />


**Screenshot 14: Add Deploy Key Form**
<img width="758" height="648" alt="image" src="https://github.com/user-attachments/assets/ce6b2c42-3da3-4242-8cf6-e027b5705502" />


**Screenshot 15: Deploy Key Added**
<img width="1160" height="431" alt="image" src="https://github.com/user-attachments/assets/0155f8a4-b604-4fc7-8b04-0c250c3157b9" />


---

#### 9. Verification

**Screenshot 16: SSH Connection Test**
<img width="653" height="652" alt="image" src="https://github.com/user-attachments/assets/2b1fff33-c258-460f-bf8e-d0f2709f97aa" />


**Screenshot 17: Initial Push Success**
<img width="867" height="505" alt="image" src="https://github.com/user-attachments/assets/bd531b9b-5048-49b3-8a2c-8750f2bc4c10" />

---

#### 10. First Device Backup

**Screenshot 18: Trigger Commit Change on PaloAlto**
<img width="1018" height="260" alt="image" src="https://github.com/user-attachments/assets/4ac59978-5de2-43bd-8ffd-652f8ec026c7" />


**Screenshot 19: Oxidized and GitLab Check new Backup**
Oxidized:
<img width="1037" height="278" alt="image" src="https://github.com/user-attachments/assets/81ead1b6-eb5e-4010-9594-d27d603d3246" />
<img width="1883" height="985" alt="image" src="https://github.com/user-attachments/assets/9db11530-9031-4882-90a8-23f98641eaf9" />

Gitlab:
<img width="894" height="286" alt="image" src="https://github.com/user-attachments/assets/98bc5f4f-cc07-4f6d-8fec-3be065163da9" />
<img width="1130" height="1019" alt="image" src="https://github.com/user-attachments/assets/2f17d8fa-fd5b-4f0e-aa27-1fb5ad445fef" />

**Screenshot 20: Device Config File**
<img width="1388" height="609" alt="image" src="https://github.com/user-attachments/assets/f98f412a-8338-4739-b006-510759940cd0" />


---

#### 11. Monitoring

**Screenshot 24: Check Status Script**
<img width="1076" height="492" alt="image" src="https://github.com/user-attachments/assets/a066e431-82c4-4c9f-98ed-7412e9a9710f" />

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
- Docker networks
- Recent backups

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs oxidized --tail 50 -f
docker logs gitlab-ce --tail 50
docker logs nginx-proxy --tail 50

# Oxidized wrapper log
docker exec oxidized cat /var/log/oxidized/wrapper_$(date +%Y%m%d).log

# Setup logs
ls -lh /opt/docker-infrastructure/logs/
tail -f /opt/docker-infrastructure/logs/master_setup_*.log
```

### Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Oxidized | `https://oxidized.yourdomain.com` | No authentication |
| GitLab | `https://gitlab.yourdomain.com` | root / (see GENERATED_PASSWORDS.txt) |

---

## 🐛 Troubleshooting

### Script Stops with "Reboot Required"

**This is normal!** Docker was just installed.

```bash
# After reboot, simply run:
cd /opt/docker-infrastructure
sudo bash master_setup.sh
```

The script detects the previous run and continues automatically.

---

### Certificates Not Valid (Existing Mode)

**For existing certificate mode:**

1. The script generates CSRs automatically in `certificates/csr/`
2. Submit CSRs to your Certificate Authority
3. Place signed certificates in `certificates/ssl/`
4. The script waits in a verification loop until certificates are valid

**Manual verification:**
```bash
cd /opt/docker-infrastructure
./scripts/05_verify_certificates.sh
```

---

### Container Won't Start

```bash
# Check logs
docker logs <container-name>

# Rebuild container
docker compose down
docker compose build --no-cache <service-name>
docker compose up -d

# Check container status
docker ps -a

# Check health
docker inspect <container-name> --format='{{.State.Health.Status}}'
```

---

### Oxidized Not Backing Up Devices

**Check connectivity:**
```bash
# Test device connectivity
docker exec oxidized ping -c 3 10.99.99.50

# Check Oxidized config
docker exec oxidized cat /etc/oxidized/config

# Check device list
docker exec oxidized cat /opt/oxidized/router.db
```

**Trigger manual backup:**
```bash
cd /opt/docker-infrastructure
./scripts/trigger_backup.sh all
```

**Check Oxidized logs:**
```bash
docker logs oxidized --tail 100 -f
```

**Common issues:**
- Wrong credentials in router.db
- Firewall blocking SSH/Telnet
- Device not supporting the configured model
- Network routing issues

---

### SSH Push to GitLab Fails

**Test SSH connection:**
```bash
docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce
```

**Expected output:**
```
Welcome to GitLab, @oxidized!
```

**If connection fails:**

1. **Verify Deploy Key is added:**
   - Go to GitLab project → Settings → Repository → Deploy Keys
   - Ensure "Oxidized Backup Key" is listed
   - Verify "Write access enabled" is YES

2. **Check key permissions:**
   ```bash
   ls -la /opt/docker-infrastructure/oxidized/keys/
   # Should show:
   # -rw------- gitlab (private key)
   # -rw-r--r-- gitlab.pub (public key)
   ```

3. **Check known_hosts:**
   ```bash
   docker exec oxidized cat /opt/oxidized/.ssh/known_hosts
   # Should contain gitlab-ce entry
   ```

4. **Check Git remote:**
   ```bash
   docker exec oxidized git -C /opt/oxidized/devices.git remote -v
   # Should show: git@gitlab-ce:oxidized/network.git
   ```

5. **Re-run GitLab integration:**
   ```bash
   cd /opt/docker-infrastructure
   ./scripts/06_setup_ssh_and_gitlab.sh
   ```

---

### GitLab Web UI Not Accessible

**GitLab takes 3-5 minutes to fully start.**

```bash
# Check if running
docker ps | grep gitlab

# Check GitLab status
docker exec gitlab-ce gitlab-ctl status

# Check health
docker inspect gitlab-ce --format='{{.State.Health.Status}}'

# Wait for healthy status
watch docker inspect gitlab-ce --format='{{.State.Health.Status}}'

# Reconfigure (if needed)
docker exec gitlab-ce gitlab-ctl reconfigure

# Restart (if needed)
docker compose restart gitlab-ce
```

**Check logs:**
```bash
docker logs gitlab-ce --tail 100
```

---

### Port Already in Use

**Edit configuration:**
```bash
nano /opt/docker-infrastructure/config.env

# Change ports:
NGINX_HTTP_PORT="8080"
NGINX_HTTPS_PORT="8443"
GITLAB_SSH_PORT="2223"
```

**Rebuild:**
```bash
cd /opt/docker-infrastructure
docker compose down
docker compose up -d
```

---

### Firewall Blocking Access

**Check firewall status:**
```bash
sudo ufw status verbose
```

**Allow additional ports if needed:**
```bash
sudo ufw allow from 192.168.1.0/24 to any port 443
sudo ufw reload
```

---

## 🔄 Maintenance

### Add More Devices

**Method 1: Edit config.env and regenerate**
```bash
cd /opt/docker-infrastructure
nano config.env

# Add devices:
DEVICE_3="192.168.1.3:junos:admin:password:"
DEVICE_4="192.168.1.4:ios:admin:password:"
DEVICE_5="10.0.0.1:panos"  # Uses default credentials

# Regenerate and rebuild
sudo bash master_setup.sh  # Uses existing config, only updates changed parts
```

**Method 2: Manual edit and rebuild**
```bash
# Edit router.db directly
docker exec -it oxidized nano /opt/oxidized/router.db

# Add line:
# 192.168.1.5:ios:admin:password:

# Reload Oxidized
docker compose restart oxidized

# Or trigger backup immediately
./scripts/trigger_backup.sh all
```

---

### Update Services

```bash
cd /opt/docker-infrastructure

# Pull latest images
docker compose pull

# Restart with new images
docker compose down
docker compose up -d

# Check status
./scripts/08_check_status.sh
```

---

### Backup Data

**Manual backup:**
```bash
cd /opt/docker-infrastructure
./scripts/09_backup.sh
```

**Backup creates:**
- Oxidized data volume backup
- GitLab data volume backup
- Configuration files
- Docker Compose file

**Backup location:**
```
/opt/backups/YYYYMMDD_HHMMSS/
├── oxidized_data.tar.gz
├── gitlab_data.tar.gz
├── nginx/
└── docker-compose.yml
```

**Setup automated backups (cron):**
```bash
sudo crontab -e

# Add line (daily at 2 AM):
0 2 * * * /opt/docker-infrastructure/scripts/09_backup.sh
```

---

### Restore from Backup

```bash
cd /opt/docker-infrastructure

# Stop services
docker compose down

# Restore volumes
BACKUP_DIR="/opt/backups/20250120_020000"  # Your backup date

docker run --rm \
  -v oxidized_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar xzf /backup/oxidized_data.tar.gz -C /data

docker run --rm \
  -v gitlab_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar xzf /backup/gitlab_data.tar.gz -C /data

# Restore configs
cp -r $BACKUP_DIR/nginx /opt/docker-infrastructure/
cp $BACKUP_DIR/docker-compose.yml /opt/docker-infrastructure/

# Start services
docker compose up -d

# Verify
./scripts/08_check_status.sh
```

---

### Change Passwords

**GitLab root password:**
```bash
# Login to GitLab web UI as root
# Go to: User Settings → Password
# Or use gitlab-rails console
docker exec -it gitlab-ce gitlab-rails console

# In console:
user = User.find_by(username: 'root')
user.password = 'new_password'
user.password_confirmation = 'new_password'
user.save!
```

**Device passwords:**
```bash
# Edit config.env
nano /opt/docker-infrastructure/config.env

# Update passwords
DEVICE_DEFAULT_PASSWORD="NewPassword123"
DEVICE_1="10.99.99.50:panos:backup:NewPassword123:"

# Regenerate configuration
cd /opt/docker-infrastructure
sudo bash master_setup.sh
```

**Docker user password:**
```bash
sudo passwd dockeruser
```

---

## 🔐 Security Best Practices

### Essential Security Measures

1. ✅ **Change Default Passwords**
   - Change all auto-generated passwords immediately after installation
   - Use a password manager (KeePass, 1Password, Bitwarden)

2. ✅ **Use Real Certificates in Production**
   - Self-signed certificates are OK for testing
   - Use certificates from your internal CA or Let's Encrypt for production

3. ✅ **Enable and Configure Firewall**
   - Set `UFW_ENABLED="true"` in config.env
   - Configure `ALLOWED_NETWORK` to restrict management access

4. ✅ **Restrict Network Access**
   - Use `ALLOWED_NETWORK` to limit who can access the services
   - Consider putting services behind VPN

5. ✅ **Regular Backups**
   - Setup automated daily backups with cron
   - Test restore procedure regularly
   - Store backups on separate system

6. ✅ **Update Regularly**
   - Pull latest Docker images monthly
   - Apply Ubuntu security updates

7. ✅ **Monitor Logs**
   - Check for failed login attempts
   - Monitor Oxidized backup failures
   - Review GitLab access logs

8. ✅ **Secure SSH Keys**
   - Protect private keys with proper permissions (600)
   - Never share private keys
   - Rotate keys periodically

9. ✅ **GitLab Security**
   - Enable 2FA for all GitLab users
   - Review project access regularly
   - Use Deploy Keys (not personal tokens)

10. ✅ **Device Credentials**
    - Use read-only accounts on devices when possible
    - Store credentials securely
    - Rotate device passwords periodically

---

### Security Checklist

After installation, verify:

- [ ] All auto-generated passwords saved securely
- [ ] Default passwords changed on first login
- [ ] GENERATED_PASSWORDS.txt deleted after saving
- [ ] Firewall enabled: `sudo ufw status`
- [ ] Only necessary ports exposed
- [ ] SSL certificates valid (not expired)
- [ ] GitLab 2FA enabled for users
- [ ] Device credentials use minimal privileges
- [ ] Backup script tested and working
- [ ] Logs reviewed for issues

---

## ❓ FAQ

### General

**Q: Can I run this on an existing server with Docker?**

A: Yes! The script detects existing Docker and skips installation. Just run `sudo bash master_setup.sh`.

---

**Q: Do I need both Oxidized and GitLab?**

A: No! You can install:
- Just Oxidized (device backups without Git repository)
- Just GitLab (Git server without network backups)
- Both (recommended for full functionality)

The wizard asks which services you want.

---

**Q: What if I make a mistake in the configuration wizard?**

A: Delete `config.env` and run `sudo bash master_setup.sh` again. Or edit `config.env` manually and re-run.

---

**Q: Can I change settings later?**

A: Yes! Edit `/opt/docker-infrastructure/config.env` and run `sudo bash master_setup.sh` again. It regenerates configurations with new settings.

---

**Q: What happens to my data if I rebuild?**

A: Docker volumes persist your data. Rebuilding containers doesn't delete:
- Oxidized device backups
- GitLab repositories
- GitLab users and settings

---

### Certificates

**Q: Can I use Let's Encrypt certificates?**

A: Yes! Choose "existing certificates" mode, use Certbot to get Let's Encrypt certs, and place them in `certificates/ssl/`.

```bash
# Example with Certbot
sudo certbot certonly --standalone -d oxidized.example.com
sudo cp /etc/letsencrypt/live/oxidized.example.com/fullchain.pem \
  /opt/docker-infrastructure/certificates/ssl/oxidized.example.com.crt
sudo cp /etc/letsencrypt/live/oxidized.example.com/privkey.pem \
  /opt/docker-infrastructure/certificates/ssl/oxidized.example.com.key
```

---

**Q: How do I renew certificates?**

A: For self-signed, regenerate by deleting certificates and running setup again. For external certificates, update files in `certificates/ssl/` and restart:
```bash
docker compose restart nginx
```

---

### Network & Connectivity

**Q: What if my server doesn't have internet access?**

A: You'll need to:
- Pre-install Docker manually
- Download all required Docker images offline
- Transfer files to the server

This script assumes internet connectivity.

---

**Q: Can I use different network ranges?**

A: Yes! Edit `config.env` before running setup:
```bash
OXINET_SUBNET="10.1.0.0/24"
GITLABNET_SUBNET="10.2.0.0/24"
NGINXNET_SUBNET="10.3.0.0/24"
```

---

**Q: How do I access from other networks?**

A: Configure firewall to allow access:
```bash
sudo ufw allow from 10.0.0.0/8 to any port 443
```

Or setup reverse proxy / VPN.

---

### Oxidized

**Q: How often does Oxidized backup devices?**

A: Every 5 minutes (300 seconds). Configurable in `config.env`:
```bash
OXIDIZED_INTERVAL="300"  # Seconds
```

---

**Q: Can I backup devices immediately?**

A: Yes!
```bash
# Backup all devices
./scripts/trigger_backup.sh all

# Backup specific device
./scripts/trigger_backup.sh 10.99.99.50
```

---

**Q: What device types are supported?**

A: Oxidized supports 130+ device types including:
- Palo Alto (panos)
- Cisco IOS (ios)
- Juniper JunOS (junos)
- Arista EOS (eos)
- FortiGate (fortios)
- Many more: https://github.com/ytti/oxidized#supported-os-types

---

**Q: How do I add support for a new device type?**

A: Check Oxidized documentation for model name, then add to router.db:
```bash
192.168.1.100:fortios:admin:password:
```

---

### GitLab

**Q: How long does GitLab take to start?**

A: 3-5 minutes for full initialization. The script waits automatically.

---

**Q: Can I use an external database for GitLab?**

A: Yes! Edit `gitlab/config/gitlab.rb` after setup to configure external PostgreSQL.

---

**Q: Why use Deploy Keys instead of Personal Access Tokens?**

A: Deploy Keys are:
- More secure (repository-specific)
- Simpler (no expiration management)
- Standard Git protocol
- No API access required

---

**Q: Can I have multiple Oxidized instances push to the same GitLab?**

A: Yes! Create separate projects and Deploy Keys for each instance.

---

### Performance

**Q: How much resources do I need?**

**Minimum (Oxidized only):**
- 2 CPU cores
- 2GB RAM
- 20GB disk

**Recommended (Oxidized + GitLab):**
- 4 CPU cores
- 8GB RAM
- 50GB disk

**For many devices (100+):**
- 4+ CPU cores
- 8GB+ RAM
- Adjust `OXIDIZED_THREADS` in config.env

---

**Q: How can I improve backup performance?**

A: Edit `config.env`:
```bash
OXIDIZED_THREADS="50"  # Increase parallel threads
OXIDIZED_TIMEOUT="10"  # Reduce timeout if devices respond quickly
```

---

## 🎓 Advanced Topics

### Multiple Oxidized Instances

To run multiple independent Oxidized instances:

1. Change container name and IP in `config.env`
2. Use different Docker networks
3. Create separate GitLab projects
4. Generate separate SSH keys

---

### External PostgreSQL for GitLab

After installation, edit `gitlab/config/gitlab.rb`:

```ruby
# Disable bundled PostgreSQL
postgresql['enable'] = false

# External PostgreSQL settings
gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_host'] = '10.0.0.100'
gitlab_rails['db_port'] = 5432
gitlab_rails['db_database'] = 'gitlabhq_production'
gitlab_rails['db_username'] = 'gitlab'
gitlab_rails['db_password'] = 'password'
```

Then reconfigure:
```bash
docker exec gitlab-ce gitlab-ctl reconfigure
```

---

### Custom Oxidized Models

Create custom device models in `oxidized/config/`:

```ruby
# Example: custom_model.rb
class CustomModel < Oxidized::Model
  prompt /^[\w.-]+[#>]\s?$/
  
  cmd :all do |cfg|
    cfg.each_line.to_a[1..-2].join
  end
  
  cmd 'show running-config' do |cfg|
    cfg
  end
end
```

---

### Oxidized Web Hooks

Add web hooks in `oxidized/config/config`:

```yaml
hooks:
  email_on_change:
    type: exec
    events: [post_store]
    cmd: '/usr/local/bin/send_email.sh "$OX_NODE_NAME"'
```

---

### GitLab CI/CD for Config Validation

Add `.gitlab-ci.yml` to the network project:

```yaml
validate:
  script:
    - echo "Validating configurations..."
    - ./validate_configs.sh
  only:
    - main
```

---

## 📚 Additional Resources

- **Oxidized:**
  - GitHub: https://github.com/ytti/oxidized
  - Documentation: https://github.com/ytti/oxidized/blob/master/docs/
  - Supported Devices: https://github.com/ytti/oxidized#supported-os-types

- **GitLab:**
  - Documentation: https://docs.gitlab.com
  - Deploy Keys: https://docs.gitlab.com/ee/user/project/deploy_keys/
  - SSH Keys: https://docs.gitlab.com/ee/user/ssh.html

- **Docker:**
  - Documentation: https://docs.docker.com
  - Compose: https://docs.docker.com/compose/
  - Networking: https://docs.docker.com/network/

- **Nginx:**
  - Documentation: https://nginx.org/en/docs/
  - SSL/TLS: https://nginx.org/en/docs/http/configuring_https_servers.html

---

## 📝 Configuration Reference

### Complete config.env Example

```bash
# Organization
ORG_NAME="MyCompany"
DOMAIN="example.local"

# Services
INSTALL_OXIDIZED="true"
INSTALL_GITLAB="true"

# Certificate Mode
CERT_MODE="selfsigned"  # or "existing"

# Certificate Details
CERT_COUNTRY="CH"
CERT_STATE="Basel"
CERT_CITY="Basel"
CERT_ORG="MyCompany"
CERT_KEY_SIZE="2048"

# System Users
ADMIN_USER="administrator"
DOCKER_USER="dockeruser"
DOCKER_USER_PASSWORD="SecurePassword123!"

# Directories
INSTALL_DIR="/opt/docker-infrastructure"
LOG_DIR="/opt/docker-infrastructure/logs"
BACKUP_DIR="/opt/backups"

# Docker Installation
SKIP_DOCKER_INSTALL="false"

# Oxidized Settings
OXIDIZED_INTERVAL="300"  # 5 minutes
OXIDIZED_THREADS="30"
OXIDIZED_TIMEOUT="20"
OXIDIZED_RETRIES="3"
OXIDIZED_GIT_USER="Oxidized"
OXIDIZED_GIT_EMAIL="oxidized@example.local"

# Device Credentials
DEVICE_DEFAULT_USERNAME="backup"
DEVICE_DEFAULT_PASSWORD="DeviceBackupPass123!"
DEVICE_DEFAULT_MODEL="panos"

# Devices
DEVICE_1="10.99.99.50:panos:backup:password:"
DEVICE_2="192.168.1.1:ios:admin:cisco123:"
DEVICE_3="192.168.1.2:junos:::"  # Uses defaults

# GitLab Settings
GITLAB_ROOT_PASSWORD="GitLabRootPass123!"
GITLAB_SSH_PORT="2222"
GITLAB_OXIDIZED_USER="oxidized"
GITLAB_OXIDIZED_PASSWORD="Ox1d1z3d!B@ckUp#2025"
GITLAB_PROJECT_NAMESPACE="oxidized"
GITLAB_PROJECT_NAME="network"

# Network Settings
ALLOWED_NETWORK="192.168.1.0/24"
SSH_PORT="22"
NGINX_HTTP_PORT="80"
NGINX_HTTPS_PORT="443"

# Docker Networks
OXINET_SUBNET="172.16.0.0/28"
OXINET_GATEWAY="172.16.0.1"
OXINET_OXIDIZED_IP="172.16.0.2"

GITLABNET_SUBNET="172.16.0.16/28"
GITLABNET_GATEWAY="172.16.0.17"
GITLABNET_GITLAB_IP="172.16.0.18"

NGINXNET_SUBNET="172.16.0.32/28"
NGINXNET_GATEWAY="172.16.0.33"
NGINXNET_NGINX_IP="172.16.0.34"

# Firewall
UFW_ENABLED="true"

# SSH Keys
SSH_KEY_TYPE="ed25519"
SSH_KEY_BITS="4096"

# Backup
BACKUP_RETENTION_DAYS="30"
BACKUP_SCHEDULE="0 2 * * *"
```

---

## ✅ Post-Installation Checklist

After installation completes, verify:

### Infrastructure
- [ ] All scripts executed without errors
- [ ] `docker ps` shows all containers running and healthy
- [ ] `docker network ls` shows oxinet, gitlabnet, nginxnet
- [ ] Firewall configured: `sudo ufw status verbose`

### Services
- [ ] Oxidized accessible: `https://oxidized.example.com`
- [ ] GitLab accessible: `https://gitlab.example.com`
- [ ] Can login to GitLab with root account
- [ ] Oxidized user created in GitLab
- [ ] Network project created and empty

### SSH Integration
- [ ] SSH keys generated in `oxidized/keys/`
- [ ] Public key added to GitLab as Deploy Key
- [ ] Deploy Key has write permissions enabled
- [ ] SSH connection test successful
- [ ] Initial push to GitLab successful
- [ ] README.md visible in GitLab project

### Device Backups
- [ ] Devices configured in router.db
- [ ] Can trigger manual backup: `./scripts/trigger_backup.sh all`
- [ ] Oxidized logs show successful backups
- [ ] Device configs appear in GitLab commits
- [ ] Automatic backups running every 5 minutes

### Security
- [ ] Passwords saved securely
- [ ] GENERATED_PASSWORDS.txt deleted (after saving)
- [ ] Default passwords changed on first login
- [ ] Firewall rules appropriate for environment
- [ ] SSL certificates valid (not expired)

### Monitoring
- [ ] Status script works: `./scripts/08_check_status.sh`
- [ ] Can view logs: `docker compose logs`
- [ ] Backup script works: `./scripts/09_backup.sh`
- [ ] Understand how to trigger immediate backups

---

## 🎉 Success!

You now have a **fully functional network device backup system** with:

- ✅ **Automated Backups** every 5 minutes
- ✅ **Git Version Control** with full history
- ✅ **SSH Authentication** (no tokens needed)
- ✅ **Web Interface** for Oxidized
- ✅ **Full GitLab** for repository management
- ✅ **Secure Setup** with SSL and firewall

### What's Next?

1. **Test the setup** - Verify backups are working
2. **Configure monitoring** - Setup alerts for failures
3. **Plan backups** - Schedule regular backups of the system
4. **Document specifics** - Note device-specific configurations
5. **Train team** - Ensure others know how to use the system

---

## 📞 Support & Contributing

### Getting Help

- Review the troubleshooting section
- Check logs in `/opt/docker-infrastructure/logs/`
- Verify configuration in `INSTALLATION_CONFIG.txt`
- Test components individually

### Found a Bug?

- Check if it's a known issue
- Gather relevant logs
- Document steps to reproduce
- Note your environment (Ubuntu version, Docker version)

---

**Version:** 11.0  
**Release Date:** January 2025  
**Authentication Method:** SSH Deploy Key Only (No Tokens)  
**License:** MIT

---

**End of Documentation**

**Example Setup**


For questions or issues, review the logs and troubleshooting sections above.
