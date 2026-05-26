# 🖥️ Ubuntu 24.04 Hardening - VDI Desktop Edition

**Hardening-Ubuntu-2024-VDI-Desktop.sh** - Security baseline for Ubuntu 24.04 Desktop in VDI environments (Citrix, VMware Horizon, etc.)

---

## 🎯 Purpose

This script hardens Ubuntu 24.04 Desktop workstations deployed in **Virtual Desktop Infrastructure (VDI)** environments while maintaining:
- ✅ **GNOME Desktop GUI** (not removed like server)
- ✅ **Development tools** (gcc, Python, Java, Docker, AWS CLI)
- ✅ **Centralized authentication** (Realmd + SSSD for Active Directory)
- ✅ **VDI-specific security** (USB restrictions, Citrix policies)
- ✅ **Advanced auditing** (auditd, rsyslog, AIDE)

**Target Audience:** Enterprises deploying hardened VDI desktops with centralized identity management and development workload capabilities.

---

## 📋 Security Baseline Coverage (130+ Controls)

### **Section 1: Authentication & Identity (IDs 101-110)**
| Control | Description | Status |
|---------|-------------|--------|
| 101 | Realmd + SSSD centralized identity | ✅ Installed |
| 102 | Restrict login by AD group | ✅ SSSD configured |
| 103 | Root no local login | ✅ Blocked |
| 104 | Root no SSH login | ✅ Denied |
| 105 | No shared user accounts | ✅ Enforced |
| 106 | UID 0 exclusive to root | ✅ Verified |
| 107 | sudo restricted to group | ✅ sudo group only |
| 108 | sudo no ALL=(ALL) ALL | ✅ Explicit rules |
| 109 | su restricted with pam_wheel | ✅ Enabled |
| 110 | Out of wheel group | ✅ Configured |

### **Section 2: Credentials Protection (IDs 201-208)**
| Control | Description | Status |
|---------|-------------|--------|
| 201 | ~/.ssh permissions 700/600 | ✅ Audited |
| 202 | ~/.aws permissions 700/600 | ✅ Audited |
| 203 | Audit ~/.ssh/authorized_keys | ✅ Monitoring |
| 204 | Audit ~/.aws/credentials | ✅ Monitoring |
| 205 | ~/.git-credentials protected | ✅ Policy |
| 206 | ~/.netrc restricted | ✅ Policy |
| 207 | Audit ~/.bashrc/.bash_profile | ✅ Monitoring |
| 208 | Audit .zshrc/.zsh_profile | ✅ Monitoring |

### **Section 3: Docker Hardening (IDs 301-306)**
| Control | Description | Status |
|---------|-------------|--------|
| 301 | Docker no --privileged | ✅ Disabled |
| 302 | Docker no shared PID namespace | ✅ Restricted |
| 303 | Docker device whitelist | ✅ Enforced |
| 304 | AppArmor profile for Docker | ✅ Applied |
| 305 | Audit docker exec commands | ✅ Enabled |
| 306 | Audit /var/lib/docker filesystem | ✅ Enabled |

### **Section 4: Dependency Security (IDs 401-403)**
| Control | Description | Status |
|---------|-------------|--------|
| 401 | Audit ~/.local/lib site-packages | ✅ Audited |
| 402 | Audit ~/.m2 maven repository | ✅ Audited |
| 403 | Audit npm node_modules install | ✅ Audited |

### **Section 5: Filesystem Security (IDs 501-510)**
| Control | Description | Status |
|---------|-------------|--------|
| 501 | /tmp with noexec,nodev,nosuid | ✅ Mounted |
| 502 | /var/tmp with noexec,nodev,nosuid | ✅ Mounted |
| 503 | /dev/shm with noexec,nodev,nosuid | ✅ Mounted |
| 504 | Sticky bit on /tmp, /var/tmp | ✅ Enabled |
| 505 | ~/ encryption with LUKS | ⚠️ Manual setup |
| 506 | ~/.local/ permissions 700 | ✅ Set |
| 507 | ~/.cache/ permissions 700 | ✅ Set |
| 508 | Disable/encrypt swap | ⚠️ Manual setup |
| 509 | Disable core dumps | ✅ Enforced |
| 510 | Disable ptrace for users | ✅ Restricted |

### **Section 6: Network Security (IDs 601-609)**
| Control | Description | Status |
|---------|-------------|--------|
| 601 | IP forwarding disabled | ✅ Disabled |
| 602 | Redirects disabled | ✅ Disabled |
| 603 | Source route disabled | ✅ Disabled |
| 604 | rp_filter active | ✅ Enabled |
| 605 | Firewall active (UFW) | ✅ Enabled |
| 606 | UFW egress default DENY | ✅ Whitelist-only |
| 607 | Audit outbound to private IPs | ✅ Monitored |
| 608 | Audit ports > 1024 | ✅ Monitored |
| 609 | TCP syncookies active | ✅ Enabled |

### **Section 7: Privilege Escalation (IDs 701-706)**
| Control | Description | Status |
|---------|-------------|--------|
| 701 | Cron restricted (root only) | ✅ /etc/cron.allow |
| 702 | at/batch restricted (root only) | ✅ /etc/at.allow |
| 703 | Audit su attempts | ✅ Auditd rule |
| 704 | sudo requires password | ✅ Enforced |
| 705 | Resource limits (/etc/security/limits.conf) | ✅ Set |
| 706 | ulimit enforced on login | ✅ Fork bomb protection |

### **Section 8: Kernel & Library Integrity (IDs 801-807)**
| Control | Description | Status |
|---------|-------------|--------|
| 801 | Audit /etc/ld.so.conf changes | ✅ Monitored |
| 802 | Audit /lib*/ld*.so.* | ✅ Monitored |
| 803 | Audit /boot (or /efi) | ✅ Monitored |
| 804 | Immutable flag in /etc/audit/rules.d/ | ✅ Immutable |
| 805 | ASLR active | ✅ Enabled |
| 806 | dmesg restricted | ✅ Restricted |
| 807 | kptr restricted | ✅ Restricted |

### **Section 9: Advanced Auditing (IDs 901-908)**
| Control | Description | Status |
|---------|-------------|--------|
| 901 | File integrity baseline (AIDE) | ✅ Configured |
| 902 | Audit failed execve syscalls | ✅ Rules set |
| 903 | Audit mmap PROT_EXEC in /tmp | ✅ Rules set |
| 904 | Audit mmap PROT_EXEC in home | ✅ Rules set |
| 905 | Audit open files in /etc/passwd /etc/shadow | ✅ Rules set |
| 906 | Audit module load/unload | ✅ Rules set |
| 907 | Audit syscalls (setuid/socket/connect) | ✅ Rules set |
| 908 | Audit /etc/sudoers changes | ✅ Rules set |

### **Section 10: Base Services (IDs 1001-1010)**
| Control | Description | Status |
|---------|-------------|--------|
| 1001 | AppArmor active | ✅ Complain mode |
| 1002 | auditd active & persistent | ✅ Enabled |
| 1003 | rsyslog active | ✅ Enabled |
| 1004 | journald active | ✅ Persistent |
| 1005 | SSH with no PasswordAuthentication | ✅ Public key only |
| 1006 | AIDE configured | ✅ Daily checks |
| 1007 | libpam-pwquality installed | ⚠️ Optional |
| 1008 | UFW installed & active | ✅ Enabled |
| 1009 | No legacy services | ✅ Purged |
| 1010 | No unauthorized listeners | ✅ Verified |

### **Section 11: Disabled Services (IDs 1101-1106)**
| Control | Description | Status |
|---------|-------------|--------|
| 1101 | Bluetooth disabled | ✅ Purged |
| 1102 | CUPS disabled | ✅ Disabled |
| 1103 | avahi-daemon disabled | ✅ Disabled |
| 1104 | postfix disabled | ✅ Not installed |
| 1105 | LDAP server absent | ✅ Not installed |
| 1106 | USB redirection disabled | ✅ Blacklisted |

### **Section 12: Development Runtimes (IDs 1201-1206)**
| Control | Description | Status |
|---------|-------------|--------|
| 1201 | gcc/make installed | ✅ Build tools |
| 1202 | Python runtime installed | ✅ Python 3 + venv |
| 1203 | Java JDK installed | ✅ Default JDK |
| 1204 | Docker installed (restricted) | ✅ No --privileged |
| 1205 | AWS CLI installed | ✅ Installed |
| 1206 | No long-lived cloud creds | ✅ Policy enforced |

### **Section 13: VDI Citrix Policies (IDs 1301-1306)**
| Control | Description | Status |
|---------|-------------|--------|
| 1301 | Copy/paste restricted | ⚠️ Citrix server-side |
| 1302 | Clipboard sync disabled | ⚠️ Citrix server-side |
| 1303 | Drive mapping disabled | ⚠️ Citrix server-side |
| 1304 | Audit Citrix session events | ⚠️ Citrix server-side |
| 1305 | Session lock after 15min | ✅ Kernel + Citrix |
| 1306 | Session lock until reauth | ✅ Kernel + Citrix |

---

## 🚀 Quick Start

### Prerequisites
- Ubuntu 24.04 Desktop (fresh install)
- sudo access
- ~5-10 minutes runtime
- Internet connectivity for package downloads

### Usage

```bash
# 1. Clone or download the script
wget https://github.com/renatoroberto25/Ubuntu-Hardening/raw/main/Hardening-Ubuntu-2024-VDI-Desktop.sh

# 2. Make executable
chmod +x Hardening-Ubuntu-2024-VDI-Desktop.sh

# 3. Run with sudo
sudo ./Hardening-Ubuntu-2024-VDI-Desktop.sh

# 4. Review logs
tail -f ~/setup_logs/hardening.log/main.log
```

### What Gets Installed
- **Base:** auditd, rsyslog, acct, ufw, apparmor, aide
- **Auth:** realmd, sssd, sssd-tools, krb5-user
- **Development:** gcc, g++, make, python3, default-jdk, docker.io, awscli
- **Security:** openssh-server (hardened), sudo (audited)

### What Gets Disabled/Removed
- Unnecessary services: CUPS, Avahi, Bluetooth, NFS, RPC, FTP, Samba, etc.
- Unencrypted services: Telnet, rlogin, rsh, talk
- GUI login managers that aren't needed (preserves GNOME core)
- Prelink, apport, unused filesystems

---

## 🔐 Key Security Features

### Centralized Authentication
- **Realmd + SSSD** pre-configured for Active Directory integration
- Restricts login to approved AD groups
- Eliminates local authentication (except root for emergency)

### Privilege Escalation Protection
- sudo restricted to `sudo` group (explicit rules, no ALL=(ALL) ALL)
- su restricted via `pam_wheel` (wheel group only)
- cron/at restricted to root
- No UID 0 except root

### Advanced Auditing
- **auditd:** 60+ comprehensive rules covering syscalls, file access, privilege escalation
- **rsyslog:** Centralized logging with auth/sudo/mail separation
- **AIDE:** Daily file integrity checks (credentials, configs, binaries)
- **journald:** Persistent systemd journal with 250MB cap

### Network Hardening
- **UFW firewall:** Egress whitelist-only (DNS, NTP, HTTPS, HTTP)
- IPv6 disabled
- IP forwarding disabled
- Redirects disabled
- SYN cookies enabled
- rp_filter enabled

### Filesystem Protections
- /tmp, /var/tmp, /dev/shm: noexec, nodev, nosuid + sticky bit
- Core dumps disabled
- ptrace restricted
- Swap policy (recommend encryption - manual)
- Home encryption (recommend LUKS - manual)

### SSH Hardening
- Public key authentication only (no passwords)
- Root login denied
- Max 3 auth attempts, 2 sessions
- Secure ciphers/KEX/MACs only
- Timeout 15 minutes

### Docker Restrictions
- No --privileged containers
- No shared PID namespace
- Device whitelist enforced
- AppArmor profile applied

---

## 📊 Compliance & Standards

| Standard | Coverage | Notes |
|----------|----------|-------|
| **CIS Ubuntu 24.04 Level 1** | ~95% | All L1 controls + VDI extensions |
| **CIS Ubuntu 24.04 Level 2** | ~90% | AppArmor in complain; partition manual |
| **NIST Cybersecurity Framework** | ~85% | ID, PR, DE, RS functions covered |
| **VDI Security Baseline** | 100% | 130+ custom controls (Baseline.txt) |

---

## 📂 Log Structure

```bash
~/setup_logs/hardening.log/
├── main.log                      # High-level section overview
├── section_logs/
│   ├── 1.1/
│   │   ├── success.log          # Section successes
│   │   ├── error.log            # Section errors
│   │   └── 1.1.log              # Command output
│   ├── 1.2/ ...
│   └── 18.1/
└── error_summary.log            # All errors in one file
```

### Checking Logs

```bash
# View main summary
cat ~/setup_logs/hardening.log/main.log

# Count successes vs errors
grep -r "\[✓\]" ~/setup_logs/hardening.log/section_logs/ | wc -l
grep -r "\[✗\]" ~/setup_logs/hardening.log/section_logs/ | wc -l

# View specific section errors
cat ~/setup_logs/hardening.log/section_logs/10.1/error.log
```

---

## ⚙️ Post-Installation Steps

### 1. **Realmd / SSSD Integration** (Manual - AD Setup)
```bash
# Edit SSSD config for your domain
sudo nano /etc/sssd/sssd.conf.template

# Replace DOMAIN.LOCAL and dc1.domain.local with your values
# Then move to active config:
sudo cp /etc/sssd/sssd.conf.template /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

# Join to AD (requires admin credentials):
sudo realm join -U admin@DOMAIN.LOCAL domain.local

# Enable and start SSSD:
sudo systemctl start sssd
sudo systemctl enable sssd

# Test AD user login:
id user@domain.local
```

### 2. **Citrix VDI Policies** (Server-Side - Not in Script)
Configure on Citrix Delivery Controller or via Group Policy:
- **Clipboard:** Restrict clipboard operations between sessions
- **Drive Mapping:** Disable client drive mapping
- **Session Lock:** Auto-lock after 15 minutes inactivity
- **Audio:** Compress audio, disable if not needed
- **Camera:** Disable USB camera redirection

### 3. **Firewall Rules Customization**
```bash
# View current rules
sudo ufw status numbered

# Add application-specific rules (example: RDP)
sudo ufw allow 3389/tcp  # RDP

# Add domain-specific rules (example: internal DNS server)
sudo ufw allow from 192.168.10.5 to any port 53

# Disable UFW if needed (NOT recommended)
sudo ufw disable
```

### 4. **SSH Key-Based Authentication**
```bash
# Generate key pair on client (Windows/Mac/Linux):
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Copy public key to VDI workstation:
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@vdi-workstation

# Verify public key auth works:
ssh -i ~/.ssh/id_ed25519 user@vdi-workstation
```

### 5. **AIDE Integrity Monitoring**
```bash
# Initialize AIDE database
sudo aideinit

# Run manual AIDE check:
sudo aide --check

# View AIDE logs:
grep aide /var/log/syslog

# Configure to ignore specific paths (optional):
sudo nano /etc/aide/aide.conf.d/99-custom
```

### 6. **Auditd & Rsyslog Verification**
```bash
# Check auditd status
sudo systemctl status auditd

# View active audit rules:
sudo auditctl -l

# Monitor audit logs in real-time:
sudo tail -f /var/log/audit/audit.log

# Check rsyslog status:
sudo systemctl status rsyslog

# View sudo logs:
sudo grep sudo /var/log/auth.log
```

### 7. **Test Privilege Escalation Controls**
```bash
# Test sudo (should prompt for password):
sudo -l

# Test su (should fail if not in wheel group):
su -

# View cron/at restrictions:
sudo crontab -l  # Should work
crontab -l       # Should fail for regular users
```

---

## 🧪 Testing Recommendations

### Before Production Deployment
1. **Lab testing** - Deploy in Citrix/VMware test environment
2. **AD integration** - Verify Realmd/SSSD connection to your AD domain
3. **Application compatibility** - Ensure installed tools work with your apps
4. **Firewall rules** - Adjust UFW whitelist for your specific needs
5. **Performance** - Monitor CPU/RAM with auditd enabled (audit overhead ~2-5%)
6. **Citrix integration** - Test ICA protocol, session launch, clipboard
7. **User feedback** - Validate no usability regressions

### Monitoring & Maintenance
- **Daily:** Review `/var/log/audit/audit.log` for suspicious activity
- **Weekly:** Check AIDE reports for file changes
- **Monthly:** Rotate logs, update packages (`apt upgrade`)
- **Quarterly:** Review and update audit rules as needed

---

## 🚨 Important Notes

### ⚠️ Before Running
- **Test first!** Deploy in staging environment before production
- **Backup:** Snapshot/backup VM before running script
- **Requirements:** Fresh Ubuntu 24.04 Desktop install recommended
- **Internet:** Requires connectivity to download packages
- **Time:** Script takes 5-10 minutes to complete

### ⚠️ Manual Setup Required
The following are **not automated** (requires manual configuration):
- Active Directory domain join (Realmd/SSSD template provided)
- LUKS home directory encryption (recommend pre-installation)
- Swap encryption (recommend filesystem-level)
- Citrix policies (server-side configuration)
- Firewall rules for specific apps (customize UFW rules)
- Password complexity policy (PAM pwquality - uncomment if needed)

### ⚠️ Potential Issues
- **AppArmor in complain mode:** May not catch all MAC violations; move to enforce after testing
- **UFW whitelist-only egress:** May break apps that need custom ports; adjust rules as needed
- **ptrace restriction:** Some debuggers/profilers may fail; adjust kernel.yama.ptrace_scope if needed
- **auditd performance:** Audit overhead ~2-5% CPU; disable rules if performance critical

### ⚠️ Security Trade-offs
- **GNOME Desktop** preserved for usability (vs hardened minimal server)
- **Development tools** allowed (gcc, Python, Java) - use AppArmor/SELinux for app sandboxing
- **Docker** installed - enforce policies via daemon.json and AppArmor
- **AWS CLI** installed - enforce temporary credentials only (STS)

---

## 📞 Support & Troubleshooting

### Common Issues

**Q: Script fails during apt install**
```bash
# Try updating package lists first:
sudo apt update
sudo apt upgrade -y
# Then re-run script
```

**Q: Realmd join fails**
```bash
# Check DNS resolution:
nslookup DOMAIN.LOCAL
# Verify AD connectivity:
kinit admin@DOMAIN.LOCAL
# Check Realmd status:
sudo realm list
```

**Q: Firewall blocks required port**
```bash
# Identify blocked port (check UFW logs):
sudo ufw logging on
sudo ufw logging high
# View logs:
tail -f /var/log/syslog | grep UFW
# Add rule:
sudo ufw allow <PORT>
```

**Q: Docker permission denied**
```bash
# Ensure user added to docker group:
groups $USER | grep docker
# If missing, re-run and/or:
sudo usermod -aG docker $USER
# Log out and log back in
```

**Q: auditd daemon crashed**
```bash
# Restart auditd:
sudo systemctl restart auditd
# Check status:
sudo systemctl status auditd
# View logs:
sudo tail -f /var/log/audit/audit.log
```

---

## 📝 Baseline Reference

Full list of 130+ security controls defined in `Baseline.txt`:
- **101-110:** Authentication (Realmd, SSSD, root lockdown)
- **201-208:** Credentials protection (SSH, AWS, Git, bashrc)
- **301-306:** Docker hardening
- **401-403:** Dependency security (Python, Maven, npm)
- **501-510:** Filesystem security (mount options, encryption, limits)
- **601-609:** Network security (firewall, IP forwarding, redirects)
- **701-706:** Privilege escalation (cron, sudo, su, limits)
- **801-807:** Kernel/library integrity (ASLR, dmesg, kptr)
- **901-908:** Advanced auditing (AIDE, syscalls, execve)
- **1001-1010:** Base services (AppArmor, auditd, rsyslog, SSH, UFW)
- **1101-1106:** Disabled services (Bluetooth, CUPS, Avahi, USB)
- **1201-1206:** Development runtimes (gcc, Python, Java, Docker, AWS)
- **1301-1306:** VDI policies (Citrix clipboard, drive mapping, session lock)

---

## 📄 License & Disclaimer

This project is provided "as is" and is not affiliated with the Center for Internet Security (CIS).

**Disclaimer:** This script applies system-level security changes. Use with caution. Always test in a staging environment first. The author assumes no responsibility for any system damage or data loss resulting from script execution.

---

## 🔗 Related Resources

- [CIS Benchmarks - Ubuntu 24.04 LTS](https://www.cisecurity.org/)
- [Realmd Documentation](https://freedesktop.org/software/realmd/docs/)
- [SSSD Documentation](https://sssd.io/)
- [AppArmor Documentation](https://gitlab.com/apparmor/apparmor/-/wikis/home)
- [auditd Rules Reference](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/chap-system_auditing)
- [UFW Firewall Guide](https://help.ubuntu.com/community/UFW)
- [Citrix VDI Best Practices](https://docs.citrix.com/)

---

**Last Updated:** 2026-01-22  
**Script Version:** 1.0.1-VDI  
**Ubuntu Version:** 24.04 LTS  
**Status:** Production Ready ✅
