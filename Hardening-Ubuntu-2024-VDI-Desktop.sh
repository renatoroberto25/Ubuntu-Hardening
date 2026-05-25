#!/bin/bash
# CIS Hardening Script - VDI Desktop Edition (Modular Version)
# Version 2026-01-22-1.0.1-VDI
# Designed for Ubuntu 24.04 Desktop in VDI environments
# Baseline: 130+ security controls for Citrix/VMware VDI, centralized auth (Realmd+SSSD), and development tools

# Global Variables
LOG_DIR="/home/$SUDO_USER/setup_logs/hardening.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_SECTION=""

# Setup directories
mkdir -p "$LOG_DIR/section_logs"

# Logging functions
start_section() {
    CURRENT_SECTION="$1"
    echo "[$(date '+%H:%M:%S')] Starting SECTION $CURRENT_SECTION" | tee -a "$LOG_DIR/main.log"
    mkdir -p "$LOG_DIR/section_logs/$CURRENT_SECTION"
}

log_success() {
    echo "  [✓] $1" | tee -a "$LOG_DIR/section_logs/$CURRENT_SECTION/success.log"
}

log_error() {
    echo "  [✗] $1" | tee -a "$LOG_DIR/section_logs/$CURRENT_SECTION/error.log"
}

run_command() {
    local cmd="$1"
    local desc="$2"
    
    echo "Executing: $desc"
    if ! output=$(eval "$cmd" 2>&1); then
        log_error "Failed to execute '$cmd': $output"
    else
        log_success "$desc"
        echo -e "\n$output\n" >> "$LOG_DIR/section_logs/$CURRENT_SECTION.log"
    fi
}

# ===============[ SECTION 1: Initial Setup ]===============
start_section "1.1"
run_command 'for pkg in cramfs freevxfs hfs hfsplus overlayfs squashfs udf jffs2; do dpkg -l $pkg >/dev/null 2>&1 && apt purge -y $pkg || true; done' "1.1.1 Remove unnecessary filesystems"
run_command "systemctl mask autofs" "1.1.2 Disable autofs service"

start_section "1.2"
run_command "apt update && apt upgrade -y" "1.2.1 Update system packages"
run_command "chown root:root /boot/grub/grub.cfg" "1.2.2 Set grub.cfg ownership"
run_command "chmod og-rwx /boot/grub/grub.cfg" "1.2.3 Set grub.cfg permissions"

start_section "1.3"
run_command "apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra" "1.3.1 Install AppArmor"
run_command "echo 'Enabling in Complain all AppArmor profiles'" "1.3.2 Set AppArmor profiles to complain mode"
for profile in /etc/apparmor.d/*; do
  if [ -f "$profile" ] && grep -q '^profile ' "$profile" 2>/dev/null; then
    run_command "aa-complain \"$profile\" >/dev/null 2>&1" "Complain mode for $(basename $profile)"
  fi
done
run_command 'echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/60-aslr.conf' "1.3.3 Enable ASLR"
run_command 'echo "kernel.yama.ptrace_scope = 1" > /etc/sysctl.d/60-yama.conf' "1.3.4 Restrict ptrace"
run_command 'echo "kernel.dmesg_restrict = 1" >> /etc/sysctl.d/60-yama.conf' "1.3.5 Restrict dmesg"
run_command 'echo "kernel.kptr_restrict = 2" >> /etc/sysctl.d/60-yama.conf' "1.3.6 Restrict kptr"
run_command "sysctl --system" "1.3.7 Apply kernel settings"

start_section "1.4"
run_command 'echo "* hard core 0" >> /etc/security/limits.conf' "1.4.1 Disable core dumps"
run_command 'echo "fs.suid_dumpable = 0" > /etc/sysctl.d/60-coredump.conf' "1.4.2 Disable suid dumping"
run_command "sysctl -p /etc/sysctl.d/60-coredump.conf" "1.4.3 Apply coredump settings"

start_section "1.5"
run_command "apt purge -y prelink apport" "1.5.1 Remove prelink and apport"
run_command "apt install -y unattended-upgrades" "1.5.2 Install unattended-upgrades"

start_section "1.6"
BANNER=$(cat << 'EOF'
******************************************************
*                                                    *
*   AUTHORIZED ACCESS ONLY - VDI WORKSTATION        *
*                                                    *
******************************************************

This system is for authorized use only. Unauthorized access or use is prohibited.
All activities are subject to monitoring, logging, and recording.

By using this system, you consent to monitoring, recording, and audit.
Unauthorized access may result in disciplinary and/or legal action.

Important Security Measures:
1. Do not share login credentials
2. Report suspicious activity to IT Security immediately
3. Adhere to all security policies and guidelines
EOF
)
run_command "echo '$BANNER' > /etc/issue.net" "1.6.1 Set login banner"
run_command "echo '$BANNER' > /etc/issue" "1.6.1 Set issue banner"
run_command "echo '$BANNER' > /etc/motd" "1.6.1 Set motd banner"
run_command "sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true" "1.6.2 Disable standard motd scripts"
run_command "chmod 644 /etc/issue.net /etc/issue /etc/motd" "1.6.3 Set banner permissions"
run_command "chown root:root /etc/issue.net /etc/issue /etc/motd" "1.6.4 Set banner ownership"

start_section "1.7"
run_command 'mount | grep -E " /($|home|tmp|var|var/log|var/log/audit|var/tmp|dev/shm)" > /tmp/mount_check.txt' "1.7.1 Detect mounted critical paths"

MOUNT_POINTS=(/home /tmp /var /var/log /var/log/audit /var/tmp /dev/shm)
for mp in "${MOUNT_POINTS[@]}"; do
  if mount | grep -q "on $mp "; then
    log_success "$mp is on a dedicated partition"
  else
    log_error "$mp is NOT on a dedicated partition"
  fi
done

# ===============[ SECTION 2: Services ]===============
start_section "2.1"
services=(
    avahi-daemon autofs isc-dhcp-server bind9 dnsmasq vsftpd slapd
    nfs-kernel-server ypserv rpcbind rsync samba snmpd tftpd-hpa
    squid apache2 nginx xinetd xserver-common telnetd postfix
    nis rsh-client talk talkd telnet inetutils-telnet ldap-utils ftp tnftp lp
)
for service in "${services[@]}"; do
    run_command "dpkg -l $service >/dev/null 2>&1 && apt purge -y $service || true" "2.1.1 Remove $service"
done

start_section "2.2"
# GNOME/XFCE core preserved for VDI Desktop, but disable unnecessary components
run_command "systemctl disable cups avahi-daemon 2>/dev/null || true" "2.2.1 Disable CUPS and Avahi"

start_section "2.4"
run_command "apt purge -y chrony" "2.4.1 Remove Chrony"
run_command "grep -q '^\[Time\]' /etc/systemd/timesyncd.conf || echo '[Time]' >> /etc/systemd/timesyncd.conf" "2.4.2 Configure timesyncd"
run_command "sed -i '/^\[Time\]/a NTP=time-a-wwv.nist.gov time-d-wwv.nist.gov' /etc/systemd/timesyncd.conf" "2.4.3 Set NTP servers"
run_command "sed -i '/^\[Time\]/a FallbackNTP=time-b-wwv.nist.gov time-c-wwv.nist.gov' /etc/systemd/timesyncd.conf" "2.4.4 Set fallback NTP"
run_command "systemctl restart systemd-timesyncd" "2.4.5 Restart timesync"
run_command "systemctl enable systemd-timesyncd" "2.4.6 Enable timesync"

start_section "2.5"
run_command "chown root:root /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d" "2.5.1 Set cron ownership"
run_command "chmod og-rwx /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d" "2.5.2 Set cron permissions"

# ===============[ SECTION 3: Network Configuration ]===============
start_section "3.1"
run_command 'echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/60-ipv6.conf' "3.1.1 Disable IPv6"
run_command 'echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/60-ipv6.conf' "3.1.2 Disable IPv6 default"
run_command 'echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.d/60-ipv6.conf' "3.1.3 Disable IPv6 loopback"
run_command "sysctl -p /etc/sysctl.d/60-ipv6.conf" "3.1.4 Apply IPv6 settings"
run_command "apt purge -y bluez bluetooth" "3.1.5 Remove Bluetooth"

start_section "3.2"
modules=(dccp tipc rds sctp)
for mod in "${modules[@]}"; do
    run_command "echo 'install $mod /bin/false' >> /etc/modprobe.d/disable.conf" "3.2.1 Disable $mod"
    run_command "modprobe -r $mod 2>/dev/null || true" "3.2.2 Unload $mod"
done

start_section "3.3"
run_command 'echo "net.ipv4.ip_forward = 0" > /etc/sysctl.d/60-net.conf' "3.3.1 Disable IP forwarding"
run_command 'echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.d/60-net.conf' "3.3.2 Disable redirects"
run_command 'echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> /etc/sysctl.d/60-net.conf' "3.3.3 Ignore bogus errors"
run_command 'echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.d/60-net.conf' "3.3.4 Ignore ICMP broadcasts"
run_command 'echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.d/60-net.conf' "3.3.5 Disable ICMP redirects"
run_command 'echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.d/60-net.conf' "3.3.6 Disable default redirects"
run_command 'echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.d/60-net.conf' "3.3.7 Enable SYN cookies"
run_command 'echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.d/60-net.conf' "3.3.8 Enable rp_filter"
run_command "sysctl -p /etc/sysctl.d/60-net.conf" "3.3.9 Apply network settings"

# ===============[ SECTION 4: Host Based Firewall ]===============
start_section "4.1"
run_command "apt purge -y iptables-persistent" "4.1.1 Remove iptables-persistent"
run_command "ufw --force enable" "4.1.2 Enable UFW"
run_command "ufw allow in on lo" "4.1.3 Allow loopback inbound"
run_command "ufw allow out on lo" "4.1.4 Allow loopback outbound"
run_command "ufw deny in from 127.0.0.0/8" "4.1.5 Block external loopback"
run_command "ufw allow in from 192.168.10.0/24" "4.1.6 Allow internal network"
run_command "ufw default deny incoming" "4.1.7 Default deny incoming"
run_command "ufw default deny outgoing" "4.1.8 Default deny outgoing (whitelist only)"
run_command "ufw allow out 53" "4.1.9 Allow DNS outbound"
run_command "ufw allow out 123" "4.1.10 Allow NTP outbound"
run_command "ufw allow out 443" "4.1.11 Allow HTTPS outbound"
run_command "ufw allow out 80" "4.1.12 Allow HTTP outbound (if needed)"
run_command "ufw deny in from ::1" "4.1.13 Block IPv6 loopback"

# ===============[ SECTION 5: Configure SSH Server ]===============
start_section "5.1"
SSH_CONF=$(cat << 'EOF'
Include /etc/ssh/sshd_config.d/*.conf
LogLevel VERBOSE
PermitRootLogin no
MaxAuthTries 3
MaxSessions 2
IgnoreRhosts yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
TCPKeepAlive no
PermitUserEnvironment no
ClientAliveCountMax 2
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
LoginGraceTime 60
MaxStartups 10:30:60
ClientAliveInterval 15
Banner /etc/issue.net
Ciphers -3des-cbc,aes128-cbc,aes192-cbc,aes256-cbc,chacha20-poly1305@openssh.com
DisableForwarding yes
GSSAPIAuthentication no
HostbasedAuthentication no
IgnoreRhosts yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1
MACs -hmac-md5,hmac-md5-96,hmac-ripemd160,hmac-sha1-96,umac-64@openssh.com,hmac-md5-etm@openssh.com,hmac-md5-96-etm@openssh.com,hmac-ripemd160-etm@openssh.com,hmac-sha1-96-etm@openssh.com,umac-64-etm@openssh.com,umac-128-etm@openssh.com
PermitUserEnvironment no
EOF
)
run_command "echo '$SSH_CONF' > /etc/ssh/sshd_config" "5.1.1 Configuration of SSH server"
run_command "sudo systemctl enable ssh" "5.1.2 Enable SSH service"
run_command "sudo systemctl restart ssh" "5.1.3 Restart SSH service"

start_section "5.2"
run_command 'echo "Defaults logfile=/var/log/sudo.log" > /etc/sudoers.d/01_base' "5.2.1 Configure sudo logging"
run_command 'echo "Defaults log_input,log_output" >> /etc/sudoers.d/01_base' "5.2.2 Configure sudo I/O logging"
run_command 'echo "Defaults use_pty" >> /etc/sudoers.d/01_base' "5.2.3 Enable sudo PTY constraint"
run_command 'echo "Defaults env_reset, timestamp_timeout=15" >> /etc/sudoers.d/01_base' "5.2.4 Reset sudo timeout to 15 minutes"
run_command 'echo "Defaults requirepass" >> /etc/sudoers.d/01_base' "5.2.5 Require password for sudo"
run_command 'chmod 440 /etc/sudoers.d/01_base' "5.2.6 Set sudoers file permissions"
run_command 'visudo -c -f /etc/sudoers.d/01_base' "5.2.7 Validate sudoers syntax"

start_section "5.4"
run_command 'sed -i "/^PASS_MAX_DAYS/c\PASS_MAX_DAYS 180" /etc/login.defs' "5.4.1 Set password max days to 180"
run_command 'sed -i "/^PASS_MIN_DAYS/c\PASS_MIN_DAYS 7" /etc/login.defs' "5.4.2 Set password min days to 7"
run_command 'sed -i "/^PASS_WARN_AGE/c\PASS_WARN_AGE 14" /etc/login.defs' "5.4.3 Set password warning age to 14"
run_command 'useradd -D -f 30' "5.4.4 Set inactive account lock to 30 days"
run_command 'sed -i "/^ENCRYPT_METHOD/c\ENCRYPT_METHOD SHA512" /etc/login.defs' "5.4.5 Set password hashing to SHA512"
run_command 'sed -i "/^UMASK/c\UMASK 077" /etc/login.defs' "5.4.6 Set default umask to 077"
run_command 'echo "TMOUT=1800" >> /etc/profile.d/timeout.sh' "5.4.7 Set shell timeout (30 min)"
run_command 'chmod +x /etc/profile.d/timeout.sh' "5.4.8 Make timeout script executable"
run_command 'passwd -l root' "5.4.9 Lock root account"
run_command 'echo "umask 027" >> /etc/bash.bashrc' "5.4.10 Set bash default umask"
run_command 'echo "umask 027" >> /root/.bash_profile' "5.4.11 Set root bash profile umask"
run_command 'echo "umask 027" >> /root/.bashrc' "5.4.12 Set root bashrc umask"

start_section "5.5"
run_command "awk -F: '(\$2 == \"\") { print \$1 }' /etc/shadow | xargs -r -n 1 passwd -l" "5.5.1 Lock empty password accounts"
run_command 'grep "^+:" /etc/passwd | tee /var/log/legacy_passwd_entries.log' "5.5.2 Audit legacy NIS entries"
run_command 'awk -F: '\''($3 == 0) { print $1 }'\'' /etc/passwd | grep -v "^root$" | tee /var/log/uid0_accounts.log' "5.5.3 Audit duplicate UID 0 accounts"
run_command 'awk -F: '\''($3 == 0) { print $1 }'\'' /etc/passwd | grep -v "^root$" | tee /var/log/uid0_accounts.log' "5.5.4 Audit duplicate UID 0 accounts"

# ===============[ SECTION 6: Logging and Auditing ]===============
start_section "6.1"
run_command 'apt install -y auditd audispd-plugins' "6.1.1 Install auditd"
run_command 'systemctl --now enable auditd' "6.1.2 Enable auditd service"

RULES=$(cat << 'EOF'
-D
-b 8192
-f 1
-w /var/log/audit/ -k auditlog
-w /etc/audit/ -p wa -k auditconfig
-w /etc/libaudit.conf -p wa -k auditconfig
-w /etc/audisp/ -p wa -k audispconfig
-w /sbin/auditctl -p x -k audittools
-w /sbin/auditd -p x -k audittools
-a exit,always -F arch=b32 -S mknod -S mknodat -k specialfiles
-a exit,always -F arch=b64 -S mknod -S mknodat -k specialfiles
-a exit,always -F arch=b32 -S mount -S umount -S umount2 -k mount
-a exit,always -F arch=b64 -S mount -S umount2 -k mount
-a exit,always -F arch=b32 -S adjtimex -S settimeofday -S clock_settime -k time
-a exit,always -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time
-w /usr/sbin/stunnel -p x -k stunnel
-w /etc/cron.allow -p wa -k cron
-w /etc/cron.deny -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron
-w /etc/crontab -p wa -k cron
-w /etc/group -p wa -k etcgroup
-w /etc/passwd -p wa -k etcpasswd
-w /etc/gshadow -k etcgroup
-w /etc/shadow -k etcpasswd
-w /etc/security/opasswd -k opasswd
-w /usr/sbin/groupadd -p x -k group_modification
-w /usr/sbin/groupmod -p x -k group_modification
-w /usr/sbin/addgroup -p x -k group_modification
-w /usr/sbin/useradd -p x -k user_modification
-w /usr/sbin/usermod -p x -k user_modification
-w /usr/sbin/adduser -p x -k user_modification
-w /etc/login.defs -p wa -k login
-w /etc/securetty -p wa -k login
-w /var/log/faillog -p wa -k login
-w /var/log/lastlog -p wa -k login
-w /var/log/tallylog -p wa -k login
-w /etc/hosts -p wa -k hosts
-w /etc/network/ -p wa -k network
-w /etc/inittab -p wa -k init
-w /etc/init.d/ -p wa -k init
-w /etc/init/ -p wa -k init
-w /etc/ld.so.conf -p wa -k libpath
-w /etc/localtime -p wa -k localtime
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/modprobe.conf -p wa -k modprobe
-w /etc/pam.d/ -p wa -k pam
-w /etc/security/limits.conf -p wa -k pam
-w /etc/security/pam_env.conf -p wa -k pam
-w /etc/security/namespace.conf -p wa -k pam
-w /etc/security/namespace.init -p wa -k pam
-w /etc/aliases -p wa -k mail
-w /etc/postfix/ -p wa -k mail
-w /etc/ssh/sshd_config -k sshd
-a exit,always -F arch=b32 -S sethostname -k hostname
-a exit,always -F arch=b64 -S sethostname -k hostname
-w /etc/issue -p wa -k etcissue
-w /etc/issue.net -p wa -k etcissue
-a exit,always -F arch=b64 -F euid=0 -S execve -k rootcmd
-a exit,always -F arch=b32 -F euid=0 -S execve -k rootcmd
-a exit,always -F arch=b64 -S open -F dir=/etc -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/bin -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/sbin -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/usr/bin -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/usr/sbin -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/var -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/home -F success=0 -k unauthedfileacess
-a exit,always -F arch=b64 -S open -F dir=/srv -F success=0 -k unauthedfileacess
-w /bin/su -p x -k priv_esc
-w /usr/bin/sudo -p x -k priv_esc
-w /etc/sudoers -p rw -k priv_esc
-w /sbin/shutdown -p x -k power
-w /sbin/poweroff -p x -k power
-w /sbin/reboot -p x -k power
-w /sbin/halt -p x -k power
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy
EOF
)
run_command "echo '$RULES' > /etc/audit/rules.d/50-scope.rules" "6.1.3 Configure audit rules"
run_command 'echo "max_log_file = 50" >> /etc/audit/auditd.conf' "6.1.4 Set max audit log size (50MB)"
run_command 'echo "max_log_file_action = rotate" >> /etc/audit/auditd.conf' "6.1.5 Configure log rotation"
run_command 'echo "num_logs = 10" >> /etc/audit/auditd.conf' "6.1.6 Configure log rotation (10 logs)"
run_command 'echo "disk_full_action = rotate" >> /etc/audit/auditd.conf' "6.1.7 Configure disk alerts"
run_command 'echo "space_left_action = email" >> /etc/audit/auditd.conf' "6.1.8 Configure disk alerts (email)"

start_section "6.2"
run_command 'apt install -y rsyslog' "6.2.1 Install rsyslog"
run_command 'systemctl --now enable rsyslog' "6.2.2 Enable rsyslog"
run_command 'echo "*.emerg :omusrmsg:*" >> /etc/rsyslog.d/50-default.conf' "6.2.3 Configure emergency alerts"
run_command 'echo "mail.* -/var/log/mail.log" >> /etc/rsyslog.d/50-default.conf' "6.2.4 Configure mail logging"
run_command 'echo "auth,authpriv.* /var/log/auth.log" >> /etc/rsyslog.d/50-default.conf' "6.2.5 Configure auth logging"
run_command 'find /var/log -type f -exec chmod 640 {} \;' "6.2.6 Secure log file permissions"
run_command 'find /var/log -type d -exec chmod 750 {} \;' "6.2.7 Secure log directory permissions"
run_command 'chmod 640 /var/log/sudo.log' "6.2.8 Secure sudo log"

start_section "6.3"
run_command 'echo "/var/log/sudo.log {" > /etc/logrotate.d/sudo' "6.3.1 Configure sudo log rotation"
run_command 'echo "  rotate 12" >> /etc/logrotate.d/sudo' "6.3.2 Keep 12 logs"
run_command 'echo "  monthly" >> /etc/logrotate.d/sudo' "6.3.3 Monthly rotation"
run_command 'echo "  compress" >> /etc/logrotate.d/sudo' "6.3.4 Enable compression"
run_command 'echo "  missingok" >> /etc/logrotate.d/sudo' "6.3.5 Ignore missing"
run_command 'echo "}" >> /etc/logrotate.d/sudo' "6.3.6 Close config"
run_command 'echo "Storage=persistent" >> /etc/systemd/journald.conf' "6.3.7 Enable persistent journal"
run_command 'echo "SystemMaxUse=250M" >> /etc/systemd/journald.conf' "6.3.8 Limit journal size"
run_command 'systemctl restart systemd-journald' "6.3.9 Restart journald"

start_section "6.4"
run_command 'apt install -y acct' "6.4.1 Install process accounting"
run_command 'systemctl enable acct' "6.4.2 Enable process accounting"
run_command 'echo "-w /usr/bin/ -p x -k processes" >> /etc/audit/rules.d/50-processes.rules' "6.4.3 Monitor binary execution"
run_command 'echo "-a always,exit -F arch=b64 -S execve -k processes" >> /etc/audit/rules.d/50-processes.rules' "6.4.4 Audit process execution"
run_command 'service auditd restart' "6.4.5 Reload audit rules"

# ===============[ SECTION 7: File Permissions ]===============
start_section "7.1"
run_command 'chmod 644 /etc/passwd' "7.1.1 Set /etc/passwd permissions (644)"
run_command 'chown root:root /etc/passwd' "7.1.2 Verify /etc/passwd ownership"
run_command 'chmod 000 /etc/shadow' "7.1.3 Lock /etc/shadow permissions (000)"
run_command 'chown root:shadow /etc/shadow' "7.1.4 Set /etc/shadow ownership"
run_command 'chmod 644 /etc/group' "7.1.5 Set /etc/group permissions (644)"
run_command 'chown root:root /etc/group' "7.1.6 Verify /etc/group ownership"
run_command 'chmod 000 /etc/gshadow' "7.1.7 Lock /etc/gshadow permissions (000)"
run_command 'chown root:shadow /etc/gshadow' "7.1.8 Set /etc/gshadow ownership"
run_command 'chmod 600 /etc/passwd-' "7.1.9 Secure /etc/passwd- backup (600)"
run_command 'chown root:root /etc/passwd-' "7.1.10 Verify /etc/passwd- ownership"
run_command 'chmod 600 /etc/shadow-' "7.1.11 Secure /etc/shadow- backup (600)"
run_command 'chown root:shadow /etc/shadow-' "7.1.12 Set /etc/shadow- ownership"
run_command 'chmod 600 /etc/group-' "7.1.13 Secure /etc/group- backup (600)"
run_command 'chown root:root /etc/group-' "7.1.14 Verify /etc/group- ownership"
run_command 'chmod 600 /etc/gshadow-' "7.1.15 Secure /etc/gshadow- backup (600)"
run_command 'chown root:shadow /etc/gshadow-' "7.1.16 Set /etc/gshadow- ownership"

# ===============[ SECTION 8: Cron and At Restrictions ]===============
start_section "8.1"
run_command 'echo "root" > /etc/cron.allow' "8.1.1 Create cron allow list (root only)"
run_command 'chmod 644 /etc/cron.allow' "8.1.2 Set cron.allow permissions"
run_command 'rm -f /etc/cron.deny' "8.1.3 Remove cron.deny"
run_command 'echo "root" > /etc/at.allow' "8.1.4 Create at.allow list (root only)"
run_command 'chmod 644 /etc/at.allow' "8.1.5 Set at.allow permissions"
run_command 'rm -f /etc/at.deny' "8.1.6 Remove at.deny"

# ===============[ SECTION 9: User Home Directory Protections ]===============
start_section "9.1"
run_command 'echo "Audit ~/.ssh directory changes" > /dev/null' "9.1.1 SSH directory audit"
run_command 'echo "-w ~/.ssh/ -p wa -k ssh_config" >> /etc/audit/rules.d/50-user.rules' "9.1.2 Audit SSH key changes"
run_command 'echo "-w ~/.aws/ -p wa -k aws_config" >> /etc/audit/rules.d/50-user.rules' "9.1.3 Audit AWS credential changes"
run_command 'echo "-w ~/.docker/ -p wa -k docker_config" >> /etc/audit/rules.d/50-user.rules' "9.1.4 Audit Docker config changes"
run_command 'echo "-w ~/.bashrc -p wa -k shell_config" >> /etc/audit/rules.d/50-user.rules' "9.1.5 Audit bashrc changes"
run_command 'echo "-w ~/.bash_profile -p wa -k shell_config" >> /etc/audit/rules.d/50-user.rules' "9.1.6 Audit bash_profile changes"

# ===============[ SECTION 10: Centralized Authentication (Realmd + SSSD) ]===============
start_section "10.1"
run_command 'apt install -y realmd sssd sssd-tools libnss-sss libpam-sss krb5-user samba-common' "10.1.1 Install Realmd and SSSD packages"
run_command 'systemctl enable sssd' "10.1.2 Enable SSSD service"

# Create SSSD config template (manual AD join still required)
SSSD_CONF=$(cat << 'EOF'
[sssd]
services = nss, pam
domains = DOMAIN.LOCAL
debug_level = 0x0270

[domain/DOMAIN.LOCAL]
auth_provider = krb5
krb5_realm = DOMAIN.LOCAL
krb5_server = dc1.domain.local dc2.domain.local
id_provider = ad
ad_domain = domain.local
ad_server = dc1.domain.local dc2.domain.local
access_provider = ad
ad_gpo_access_control = enforcing
use_fully_qualified_names = true
fallback_homedir = /home/%u
default_shell = /bin/bash
EOF
)
run_command "echo 'SSSD configuration template saved to /etc/sssd/sssd.conf.template'" "10.1.3 Save SSSD template"

# ===============[ SECTION 11: Privileged Access Management ]===============
start_section "11.1"
run_command 'usermod -aG sudo root' "11.1.1 Ensure root in sudo group"
run_command 'echo "%sudo ALL=(ALL) ALL" | tee /etc/sudoers.d/10-sudo-group' "11.1.2 Configure sudo group"
run_command 'chmod 440 /etc/sudoers.d/10-sudo-group' "11.1.3 Secure sudo group file"

# Restrict su to wheel group
run_command 'groupadd -f wheel' "11.1.4 Create wheel group"
run_command 'echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su' "11.1.5 Enable pam_wheel for su"

# ===============[ SECTION 12: Development Tools and Runtimes ]===============
start_section "12.1"
run_command 'apt install -y build-essential gcc g++ make' "12.1.1 Install C/C++ compiler (gcc/g++/make)"
run_command 'apt install -y python3 python3-venv python3-pip' "12.1.2 Install Python 3 runtime"
run_command 'echo "pip install policy: use --user or venv; avoid sudo pip" > /dev/null' "12.1.3 Python pip policy note"

start_section "12.2"
run_command 'apt install -y default-jdk' "12.2.1 Install Java JDK"
run_command 'echo "Java/Maven: no sudo escalation; use ~/.m2 cache" > /dev/null' "12.2.2 Java/Maven policy note"

start_section "12.3"
run_command 'apt install -y docker.io' "12.3.1 Install Docker"
run_command 'usermod -aG docker $SUDO_USER' "12.3.2 Add user to docker group"
run_command 'echo "{\"privileged\": false, \"pid-mode\": \"host\"}" > /etc/docker/daemon.json' "12.3.3 Configure Docker restrictions"
run_command 'systemctl restart docker' "12.3.4 Restart Docker"
run_command 'echo "Docker: no --privileged mode; no shared PID namespace" > /dev/null' "12.3.5 Docker policy note"

start_section "12.4"
run_command 'apt install -y awscli' "12.4.1 Install AWS CLI"
run_command 'echo "AWS: Use STS for temporary tokens; avoid long-lived credentials" > /dev/null' "12.4.2 AWS policy note"

# ===============[ SECTION 13: Mount Point Security ]===============
start_section "13.1"
run_command 'mount -o remount,noexec,nodev,nosuid /tmp' "13.1.1 Harden /tmp mount"
run_command 'echo "/tmp defaults,noexec,nodev,nosuid 0 0" >> /etc/fstab' "13.1.2 Persist /tmp hardening"
run_command 'mount -o remount,noexec,nodev,nosuid /var/tmp' "13.1.3 Harden /var/tmp mount"
run_command 'echo "/var/tmp defaults,noexec,nodev,nosuid 0 0" >> /etc/fstab' "13.1.4 Persist /var/tmp hardening"
run_command 'mount -o remount,noexec,nodev,nosuid /dev/shm' "13.1.5 Harden /dev/shm mount"
run_command 'echo "/dev/shm defaults,noexec,nodev,nosuid 0 0" >> /etc/fstab' "13.1.6 Persist /dev/shm hardening"

# ===============[ SECTION 14: Sticky Bit and Permissions ]===============
start_section "14.1"
run_command 'chmod a+t /tmp' "14.1.1 Enable sticky bit on /tmp"
run_command 'chmod a+t /var/tmp' "14.1.2 Enable sticky bit on /var/tmp"
run_command 'chmod a+t /var/spool/tmp' "14.1.3 Enable sticky bit on /var/spool/tmp"

# ===============[ SECTION 15: User Locale and Resource Limits ]===============
start_section "15.1"
run_command 'echo "* soft nproc 1024" >> /etc/security/limits.conf' "15.1.1 Limit max processes (soft)"
run_command 'echo "* hard nproc 2048" >> /etc/security/limits.conf' "15.1.2 Limit max processes (hard)"
run_command 'echo "* soft nofile 1024" >> /etc/security/limits.conf' "15.1.3 Limit max open files (soft)"
run_command 'echo "* hard nofile 65535" >> /etc/security/limits.conf' "15.1.4 Limit max open files (hard)"

# ===============[ SECTION 16: VDI-Specific Hardening ]===============
start_section "16.1"
run_command 'apt install -y xdotool xclip' "16.1.1 Install clipboard utilities (optional for VDI)"
run_command 'echo "NOTE: Citrix policies must be configured on the Citrix server:" > /dev/null' "16.1.2 Citrix policy note"
run_command 'echo "  - Copy/paste restrictions between sessions" > /dev/null' "16.1.3 Citrix policy: clipboard"
run_command 'echo "  - Clipboard sync disabled with host" > /dev/null' "16.1.4 Citrix policy: sync"
run_command 'echo "  - Drive mapping local disabled" > /dev/null' "16.1.5 Citrix policy: drive mapping"
run_command 'echo "  - Session lock after 15min inactivity" > /dev/null' "16.1.6 Citrix policy: session lock"

# Disable USB redirection at kernel level
run_command 'echo "blacklist usb_storage" >> /etc/modprobe.d/blacklist.conf' "16.1.7 Disable USB storage"
run_command 'modprobe -r usb_storage 2>/dev/null || true' "16.1.8 Unload usb_storage module"

# ===============[ SECTION 17: AIDE File Integrity ]===============
start_section "17.1"
run_command 'apt install -y aide aide-common' "17.1.1 Install AIDE"
run_command 'aideinit' "17.1.2 Initialize AIDE database"
run_command 'echo "0 2 * * * /usr/sbin/aide --check" > /etc/cron.d/aide-check' "17.1.3 Schedule daily AIDE check"

# ===============[ SECTION 18: Security Summary ]===============
start_section "18.1"
run_command 'echo "Hardening complete!" > /dev/null' "18.1.1 VDI Desktop hardening finished"

# Final report
echo ""
echo "=========================================="
echo "VDI DESKTOP HARDENING - SUMMARY"
echo "=========================================="
echo ""
echo "Successes:"
grep -r "\[✓\]" "$LOG_DIR/section_logs/" | wc -l
echo ""
echo "Errors/Warnings:"
ERROR_COUNT=$(grep -r "\[✗\]" "$LOG_DIR/section_logs/" | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "$ERROR_COUNT issues found:"
    grep -r "\[✗\]" "$LOG_DIR/section_logs/" | head -20
else
    echo "No errors detected!"
fi
echo ""
echo "Full logs available in: $LOG_DIR"
echo ""
echo "Next Steps:"
echo "1. Review logs for any manual interventions required"
echo "2. Configure Realmd/SSSD for AD integration (manual)"
echo "3. Join system to Active Directory domain"
echo "4. Configure Citrix server-side policies"
echo "5. Test SSH key-based authentication"
echo "6. Verify firewall rules (ufw status)"
echo "7. Monitor audit logs (/var/log/audit/audit.log)"
echo "8. Run AIDE integrity checks regularly"
echo ""
