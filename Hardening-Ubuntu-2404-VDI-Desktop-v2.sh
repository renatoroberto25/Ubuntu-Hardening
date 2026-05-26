#!/usr/bin/env bash
# Ubuntu 24.04 VDI Desktop hardening - proposta realista para devs sem root.
# Foco: proteger o SO e deixar o dev trabalhar em Python, Java, C/C++, Docker rootless, AWS e Azure.

set -u

VERSION="2026-05-25-V1.0.0"

# ===== Ajustes do ambiente =====
DEV_GROUP="${DEV_GROUP:-vdi-devs}"
ADMIN_GROUP="${ADMIN_GROUP:-vdi-admins}"
LOG_BASE="${LOG_BASE:-/var/log/ubuntu-vdi-hardening}"

# Controles opcionais. Mantidos conservadores por padrao.
DRY_RUN="${DRY_RUN:-false}"
ENABLE_SSH="${ENABLE_SSH:-false}"
INSTALL_DEV_TOOLS="${INSTALL_DEV_TOOLS:-true}"
INSTALL_DOCKER_ROOTLESS="${INSTALL_DOCKER_ROOTLESS:-true}"
DISABLE_ROOTFUL_DOCKER="${DISABLE_ROOTFUL_DOCKER:-true}"
PURGE_LEGACY_SERVICES="${PURGE_LEGACY_SERVICES:-true}"
HARDEN_TMP_NOEXEC="${HARDEN_TMP_NOEXEC:-false}"
DISABLE_IPV6="${DISABLE_IPV6:-false}"
ENFORCE_DEV_NO_SUDO="${ENFORCE_DEV_NO_SUDO:-false}"

CURRENT_SECTION="init"
ERRORS=0

log_dir() {
    printf '%s/%s\n' "$LOG_BASE" "$(date +%Y%m%d_%H%M%S)"
}

LOG_DIR="$(log_dir)"

start_section() {
    CURRENT_SECTION="$1"
    mkdir -p "$LOG_DIR/sections/$CURRENT_SECTION"
    printf '\n[%s] SECTION %s\n' "$(date '+%H:%M:%S')" "$CURRENT_SECTION" | tee -a "$LOG_DIR/main.log"
}

log_info() {
    printf '  [INFO] %s\n' "$1" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/info.log"
}

log_ok() {
    printf '  [OK] %s\n' "$1" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/success.log"
}

log_warn() {
    printf '  [WARN] %s\n' "$1" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/warn.log"
}

log_fail() {
    ERRORS=$((ERRORS + 1))
    printf '  [FAIL] %s\n' "$1" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/error.log"
}

run() {
    local desc="$1"
    shift

    log_info "$desc"
    if [ "$DRY_RUN" = "true" ]; then
        printf '  [DRY-RUN] %s\n' "$*" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/commands.log"
        return 0
    fi

    if "$@" >>"$LOG_DIR/sections/$CURRENT_SECTION/output.log" 2>&1; then
        log_ok "$desc"
        return 0
    fi

    log_fail "$desc"
    return 1
}

run_shell() {
    local desc="$1"
    local cmd="$2"

    log_info "$desc"
    if [ "$DRY_RUN" = "true" ]; then
        printf '  [DRY-RUN] %s\n' "$cmd" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/commands.log"
        return 0
    fi

    if bash -c "$cmd" >>"$LOG_DIR/sections/$CURRENT_SECTION/output.log" 2>&1; then
        log_ok "$desc"
        return 0
    fi

    log_fail "$desc"
    return 1
}

backup_file() {
    local file="$1"
    if [ -e "$file" ] && [ "$DRY_RUN" != "true" ]; then
        cp -a "$file" "$file.vdi-hardening.$(date +%Y%m%d%H%M%S).bak"
    fi
}

write_file() {
    local path="$1"
    local mode="$2"
    local owner="$3"
    local content="$4"

    log_info "Write $path"
    if [ "$DRY_RUN" = "true" ]; then
        printf '  [DRY-RUN] write %s mode %s owner %s\n' "$path" "$mode" "$owner" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/commands.log"
        return 0
    fi

    backup_file "$path"
    install -d -m 0755 "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    chown "$owner" "$path"
    chmod "$mode" "$path"
    log_ok "Wrote $path"
}

append_unique_line() {
    local path="$1"
    local line="$2"

    log_info "Ensure line in $path: $line"
    if [ "$DRY_RUN" = "true" ]; then
        printf '  [DRY-RUN] ensure line in %s\n' "$path" | tee -a "$LOG_DIR/sections/$CURRENT_SECTION/commands.log"
        return 0
    fi

    touch "$path"
    if ! grep -Fqx "$line" "$path"; then
        printf '%s\n' "$line" >> "$path"
    fi
    log_ok "Line present in $path"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Run as root: sudo %s\n' "$0" >&2
        exit 1
    fi
}

init_logging() {
    mkdir -p "$LOG_DIR/sections"
    printf 'Ubuntu VDI hardening %s\nStarted: %s\n' "$VERSION" "$(date -Is)" | tee "$LOG_DIR/main.log" >/dev/null
}

check_platform() {
    start_section "00-platform"
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        log_info "Detected ${PRETTY_NAME:-unknown}"
        if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
            log_warn "Script desenhado para Ubuntu 24.04; continuar somente em staging/snapshot"
        fi
    else
        log_warn "/etc/os-release ausente"
    fi
}

configure_identity_placeholders() {
    start_section "10-identidade"
    run "Install SSSD/realmd packages" apt-get install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli krb5-user samba-common-bin

    run "Enable SSSD if configured" systemctl enable sssd

    local sssd_template
    sssd_template='[sssd]
services = nss, pam
domains = EXAMPLE.LOCAL

[domain/EXAMPLE.LOCAL]
id_provider = ad
auth_provider = ad
access_provider = ad
ad_domain = example.local
krb5_realm = EXAMPLE.LOCAL
ad_gpo_access_control = enforcing
use_fully_qualified_names = false
fallback_homedir = /home/%u
default_shell = /bin/bash

# Ajustar dominio, DCs e grupos antes de ativar:
# realm join -U admin@example.local example.local
# realm permit -g vdi-devs@example.local
'
    write_file "/etc/sssd/sssd.conf.template" "0600" "root:root" "$sssd_template"

    run "Create local admin group placeholder" groupadd -f "$ADMIN_GROUP"
    log_warn "Join de AD e realm permit devem ser feitos conforme dominio real da companhia"
}

configure_privilege_model() {
    start_section "20-privilegios"
    run "Lock root password" passwd -l root
    run "Create admin group" groupadd -f "$ADMIN_GROUP"
    run "Create dev group placeholder" groupadd -f "$DEV_GROUP"

    local sudoers
    sudoers="Defaults use_pty
Defaults logfile=/var/log/sudo.log
Defaults log_input,log_output
Defaults env_reset,timestamp_timeout=15
%$ADMIN_GROUP ALL=(ALL:ALL) ALL
"
    write_file "/etc/sudoers.d/20-vdi-admins" "0440" "root:root" "$sudoers"
    run "Validate vdi sudoers" visudo -cf /etc/sudoers.d/20-vdi-admins

    if [ "$ENFORCE_DEV_NO_SUDO" = "true" ]; then
        run_shell "Remove members of $DEV_GROUP from sudo group" \
            "getent group '$DEV_GROUP' | awk -F: '{print \$4}' | tr ',' '\n' | sed '/^$/d' | while read -r u; do gpasswd -d \"\$u\" sudo || true; done"
    else
        log_warn "ENFORCE_DEV_NO_SUDO=false; nao removi usuarios de sudo automaticamente"
    fi

    if ! grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_wheel\.so' /etc/pam.d/su 2>/dev/null; then
        append_unique_line "/etc/pam.d/su" "auth required pam_wheel.so use_uid group=$ADMIN_GROUP"
    else
        log_info "pam_wheel already configured in /etc/pam.d/su"
    fi

    write_file "/etc/polkit-1/rules.d/49-vdi-admins.rules" "0644" "root:root" "polkit.addAdminRule(function(action, subject) {
    return [\"unix-group:$ADMIN_GROUP\"];
});"
}

configure_ssh() {
    start_section "30-ssh"
    run "Install OpenSSH server package" apt-get install -y openssh-server

    local sshd_dropin
    sshd_dropin='PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitUserEnvironment no
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
LogLevel VERBOSE
'
    write_file "/etc/ssh/sshd_config.d/90-vdi-hardening.conf" "0644" "root:root" "$sshd_dropin"
    run "Validate sshd config" sshd -t

    if [ "$ENABLE_SSH" = "true" ]; then
        run "Enable SSH service" systemctl enable --now ssh
    else
        run "Disable SSH service by default" systemctl disable --now ssh
        log_warn "SSH ficou desabilitado. Use ENABLE_SSH=true se suporte operacional exigir."
    fi
}

install_dev_tools() {
    start_section "40-dev-tools"
    if [ "$INSTALL_DEV_TOOLS" != "true" ]; then
        log_warn "INSTALL_DEV_TOOLS=false; pulando toolchain dev"
        return
    fi

    run "Install Python/Java/C/C++/AWS/Azure user tooling" apt-get install -y \
        python3 python3-venv python3-pip pipx \
        build-essential gcc g++ make gdb \
        default-jdk maven gradle \
        git git-lfs curl ca-certificates unzip jq \
        awscli

    # Azure CLI via repositorio oficial Microsoft
    run_shell "Add Microsoft signing key for Azure CLI" \
        "curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && chmod 0644 /etc/apt/keyrings/microsoft.gpg"
    run_shell "Add Azure CLI apt repository" \
        "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ noble main' > /etc/apt/sources.list.d/azure-cli.list"
    run "Update apt after adding Azure CLI repo" apt-get update
    run "Install Azure CLI" apt-get install -y azure-cli

    run_shell "Ensure pipx binary path profile hint" \
        "printf '%s\n' 'export PATH=\"\$HOME/.local/bin:\$PATH\"' > /etc/profile.d/10-user-local-bin.sh && chmod 0644 /etc/profile.d/10-user-local-bin.sh"

    write_file "/etc/pip.conf" "0644" "root:root" "[global]
require-virtualenv = true

[install]
user = false
"
    log_warn "pip global fica bloqueado por padrao; dev deve usar python3 -m venv ou pipx"
    log_warn "AWS: usar aws sso login ou credenciais STS temporarias; evitar long-lived keys em ~/.aws/credentials"
    log_warn "Azure: usar az login com device flow ou Managed Identity; sem service principal em arquivo local"
}

configure_docker_rootless() {
    start_section "50-docker-rootless"
    if [ "$INSTALL_DOCKER_ROOTLESS" != "true" ]; then
        log_warn "INSTALL_DOCKER_ROOTLESS=false; pulando Docker rootless"
        return
    fi

    run "Install Docker/rootless dependencies" apt-get install -y \
        docker.io docker-buildx uidmap slirp4netns fuse-overlayfs dbus-user-session rootlesskit

    if [ "$DISABLE_ROOTFUL_DOCKER" = "true" ]; then
        run "Disable rootful Docker service and socket" systemctl disable --now docker.service docker.socket
        run "Remove world/group access from rootful Docker socket if present" \
            bash -c 'if [ -S /var/run/docker.sock ]; then chown root:root /var/run/docker.sock && chmod 0600 /var/run/docker.sock; fi'
    else
        log_warn "DISABLE_ROOTFUL_DOCKER=false; garanta que dev nao esteja no grupo docker"
    fi

    run_shell "Ensure docker group exists but dev is not a member" \
        "getent group docker >/dev/null || groupadd docker"

    write_file "/etc/profile.d/20-docker-rootless.sh" "0644" "root:root" 'if [ -n "$UID" ] && [ -S "/run/user/$UID/docker.sock" ]; then
    export DOCKER_HOST="unix:///run/user/$UID/docker.sock"
fi'

    write_file "/usr/local/sbin/setup-rootless-docker-user" "0750" "root:root" '#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: setup-rootless-docker-user <username>" >&2
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: setup-rootless-docker-user <username>" >&2
    exit 1
fi

user="$1"
home_dir="$(getent passwd "$user" | cut -d: -f6)"
uid="$(id -u "$user")"

if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
    echo "User home not found for $user" >&2
    exit 1
fi

loginctl enable-linger "$user"

if command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    runuser -l "$user" -c "dockerd-rootless-setuptool.sh install"
else
    echo "dockerd-rootless-setuptool.sh not found. Install Docker rootless package/tooling first." >&2
    exit 1
fi

runuser -l "$user" -c "systemctl --user enable --now docker"
echo "Rootless Docker configured for $user at unix:///run/user/$uid/docker.sock"
'

    log_warn "Execute setup-rootless-docker-user <usuario> para cada dev local/AD apos primeiro login"
}

configure_filesystem_and_home() {
    start_section "60-filesystem-home"

    # --- umask ---
    run "Set conservative login.defs umask" sed -i 's/^UMASK.*/UMASK 077/' /etc/login.defs
    write_file "/etc/profile.d/30-vdi-umask.sh" "0644" "root:root" 'umask 027'

    # --- resource limits ---
    write_file "/etc/security/limits.d/90-vdi-dev.conf" "0644" "root:root" "# VDI dev resource limits
*    hard core     0
*    soft nproc    4096
*    hard nproc    8192
*    soft nofile   4096
*    hard nofile   65535
*    soft fsize    4194304
*    hard fsize    8388608
"

    # --- /tmp /var/tmp sticky ---
    run "Set sticky bit on /tmp" chmod 1777 /tmp
    run "Set sticky bit on /var/tmp" chmod 1777 /var/tmp

    if [ "$HARDEN_TMP_NOEXEC" = "true" ]; then
        run_shell "Mask default tmp.mount before fstab override" \
            "systemctl mask tmp.mount >/dev/null 2>&1 || true"
        log_warn "HARDEN_TMP_NOEXEC=true: ajuste /etc/fstab manualmente conforme particionamento real"
        log_warn "Testar compatibilidade com Java, IDEs, builds e Docker rootless ANTES de ativar em producao"
    else
        log_warn "Nao apliquei noexec em /tmp por compatibilidade com Java, IDEs, builds e Citrix (HARDEN_TMP_NOEXEC=false)"
    fi

    # --- helper: fix home permissions (inclui .azure) ---
    write_file "/usr/local/sbin/vdi-fix-user-home-perms" "0750" "root:root" '#!/usr/bin/env bash
# Corrige permissoes de home e diretorios sensiveis de cada usuario em /home.
# Inclui: .ssh, .aws, .azure, .docker, .cache, .local, .m2, .gradle, .npm, .config
set -euo pipefail

for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user="$(basename "$home_dir")"
    id "$user" >/dev/null 2>&1 || continue

    chown "$user:$user" "$home_dir"
    chmod 0750 "$home_dir"

    for dir in .ssh .aws .azure .docker .cache .local .m2 .gradle .npm .config; do
        target="$home_dir/$dir"
        if [ -d "$target" ]; then
            chown -R "$user:$user" "$target"
            chmod 0700 "$target"
        fi
    done

    # Chaves SSH: arquivos 600
    if [ -d "$home_dir/.ssh" ]; then
        find "$home_dir/.ssh" -type f -exec chmod 0600 {} +
    fi

    # Credenciais AWS: arquivos 600
    if [ -d "$home_dir/.aws" ]; then
        find "$home_dir/.aws" -type f -exec chmod 0600 {} +
    fi

    # Credenciais Azure: arquivos 600
    if [ -d "$home_dir/.azure" ]; then
        find "$home_dir/.azure" -type f -exec chmod 0600 {} +
    fi

    # .netrc: se existir deve ser 600
    if [ -f "$home_dir/.netrc" ]; then
        chown "$user:$user" "$home_dir/.netrc"
        chmod 0600 "$home_dir/.netrc"
    fi
done

echo "Home permissions fixed."
'
}

configure_audit_shell_inits() {
    start_section "65-audit-shell-inits"
    # auditd nao expande ~ em paths; precisamos de regras por home existente.
    # O bloco abaixo emite regras para homes presentes no momento do hardening.
    # Para novos usuarios AD, re-executar este bloco ou rodar vdi-fix-user-home-perms + augenrules.

    log_info "Gerando regras auditd para shell inits de usuarios em /home"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Pulando geracao de regras de shell init"
        return 0
    fi

    local rules_file="/etc/audit/rules.d/51-vdi-user-shell-inits.rules"
    : > "$rules_file"

    for home_dir in /home/*; do
        [ -d "$home_dir" ] || continue
        user="$(basename "$home_dir")"
        id "$user" >/dev/null 2>&1 || continue

        for f in .bashrc .bash_profile .profile .zshrc .bash_logout; do
            printf -- '-w %s/%s -p wa -k shell_init\n' "$home_dir" "$f" >> "$rules_file"
        done
        printf -- '-w %s/.ssh -p wa -k ssh_keys\n' "$home_dir" >> "$rules_file"
        printf -- '-w %s/.aws -p wa -k aws_creds\n' "$home_dir" >> "$rules_file"
        printf -- '-w %s/.azure -p wa -k azure_creds\n' "$home_dir" >> "$rules_file"
    done

    chmod 0640 "$rules_file"
    chown root:root "$rules_file"
    log_ok "Wrote $rules_file"

    run "Reload audit rules after shell init additions" augenrules --load
}

configure_kernel_network() {
    start_section "70-kernel-network"
    write_file "/etc/sysctl.d/60-vdi-hardening.conf" "0644" "root:root" "# VDI Hardening - kernel e rede
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.unprivileged_bpf_disabled = 1
kernel.perf_event_paranoid = 3
fs.suid_dumpable = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
"

    if [ "$DISABLE_IPV6" = "true" ]; then
        append_unique_line "/etc/sysctl.d/60-vdi-hardening.conf" "net.ipv6.conf.all.disable_ipv6 = 1"
        append_unique_line "/etc/sysctl.d/60-vdi-hardening.conf" "net.ipv6.conf.default.disable_ipv6 = 1"
        log_warn "IPv6 desabilitado via sysctl; validar com equipe de rede/Citrix antes de aplicar em producao"
    else
        log_warn "IPv6 preservado (DISABLE_IPV6=false); deve seguir arquitetura de rede corporativa/Citrix"
    fi

    write_file "/etc/modprobe.d/vdi-disable-protocols.conf" "0644" "root:root" "# Protocolos de rede nao usados
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false

# Filesystems nao usados
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
"
    run "Apply sysctl settings" sysctl --system
    log_warn "Sem UFW egress: controle principal assumido no firewall/proxy corporativo"
}

configure_services() {
    start_section "80-services"
    if [ "$PURGE_LEGACY_SERVICES" = "true" ]; then
        run "Purge legacy network services" apt-get purge -y \
            telnetd inetutils-telnet rsh-client rsh-server rlogin talk talkd tftpd-hpa vsftpd \
            nfs-kernel-server rpcbind samba slapd postfix || true
    fi

    run "Disable Bluetooth if present" systemctl disable --now bluetooth || true
    run "Disable Avahi if present" systemctl disable --now avahi-daemon || true
    run "Disable CUPS if present" systemctl disable --now cups || true
    run "Mask autofs if present" systemctl mask autofs || true

    write_file "/etc/modprobe.d/vdi-usb-storage.conf" "0644" "root:root" "install usb_storage /bin/false
blacklist usb_storage
"
    log_warn "USB redirection principal deve ser controlado por policy Citrix"
    log_warn "Citrix VDA services (ctxvda, ctxhdx, ctxgfx, ctxlogd) nao foram tocados; nao mascarar"
}

configure_logging_audit() {
    start_section "90-logs-audit"
    run "Install auditd and rsyslog" apt-get install -y auditd audispd-plugins rsyslog
    run "Enable auditd" systemctl enable auditd
    run "Enable rsyslog" systemctl enable --now rsyslog

    write_file "/etc/systemd/journald.conf.d/90-vdi.conf" "0644" "root:root" "[Journal]
Storage=persistent
SystemMaxUse=250M
SystemKeepFree=100M
Compress=yes
"
    run "Restart journald" systemctl restart systemd-journald

    write_file "/etc/audit/rules.d/50-vdi-realista.rules" "0640" "root:root" "-D
-b 8192
-f 1
# Identidade
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
# Privilegios
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-w /etc/pam.d/ -p wa -k pam
# SSH
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd
# SSSD/AD
-w /etc/sssd/ -p wa -k sssd
# APT sources
-w /etc/apt/sources.list -p wa -k apt_sources
-w /etc/apt/sources.list.d/ -p wa -k apt_sources
-w /etc/apt/keyrings/ -p wa -k apt_sources
# Boot
-w /boot/ -p wa -k boot
# Comandos privilegiados
-w /usr/bin/sudo -p x -k sudo_exec
-w /bin/su -p x -k su_exec
# Modulos de kernel
-w /usr/sbin/modprobe -p x -k kernel_module
-w /usr/sbin/insmod -p x -k kernel_module
-w /usr/sbin/rmmod -p x -k kernel_module
-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -k kernel_module
-a always,exit -F arch=b32 -S init_module,delete_module,finit_module -k kernel_module
# Comandos executados como root
-a always,exit -F arch=b64 -S execve -F euid=0 -k rootcmd
-a always,exit -F arch=b32 -S execve -F euid=0 -k rootcmd
"
    run "Load audit rules" augenrules --load
}

write_postcheck() {
    start_section "99-postcheck"
    write_file "/usr/local/sbin/vdi-hardening-postcheck" "0750" "root:root" '#!/usr/bin/env bash
# Postcheck: valida controles criticos apos hardening e reboot.
set -u

PASS=0
FAIL=0

ok()   { printf "  [OK]   %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  [FAIL] %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { printf "  [INFO] %s\n" "$1"; }

echo
echo "=== 1. Identidade e grupos ==="
getent group vdi-devs  >/dev/null 2>&1  && ok  "grupo vdi-devs existe"   || fail "grupo vdi-devs ausente"
getent group vdi-admins >/dev/null 2>&1 && ok  "grupo vdi-admins existe" || fail "grupo vdi-admins ausente"

echo
echo "=== 2. Root e sudo ==="
passwd -S root 2>/dev/null | grep -q " L " && ok "root bloqueado" || fail "root NAO bloqueado"
test -f /etc/sudoers.d/20-vdi-admins && visudo -cf /etc/sudoers.d/20-vdi-admins >/dev/null 2>&1 \
    && ok "sudoers vdi-admins valido" || fail "sudoers vdi-admins invalido ou ausente"
getent group sudo | grep -qE ":(.*,)?$SUDO_USER(,|$)" 2>/dev/null \
    && fail "usuario atual ainda no grupo sudo" || ok "usuario atual fora do grupo sudo"

echo
echo "=== 3. SSH ==="
sshd -t >/dev/null 2>&1 && ok "sshd config valida" || fail "sshd config invalida"
systemctl is-enabled ssh >/dev/null 2>&1 && info "SSH habilitado (esperado se ENABLE_SSH=true)" \
    || ok "SSH desabilitado (padrao)"

echo
echo "=== 4. Kernel ==="
check_sysctl() {
    local key="$1" expected="$2"
    local val
    val=$(sysctl -n "$key" 2>/dev/null)
    if [ "$val" = "$expected" ]; then
        ok "$key = $val"
    else
        fail "$key = $val (esperado $expected)"
    fi
}
check_sysctl kernel.randomize_va_space 2
check_sysctl kernel.yama.ptrace_scope 1
check_sysctl kernel.dmesg_restrict 1
check_sysctl kernel.kptr_restrict 2
check_sysctl fs.suid_dumpable 0
check_sysctl net.ipv4.ip_forward 0

echo
echo "=== 5. Logs e auditoria ==="
systemctl is-active auditd >/dev/null 2>&1  && ok "auditd ativo"    || fail "auditd inativo"
systemctl is-enabled auditd >/dev/null 2>&1 && ok "auditd enabled"  || fail "auditd nao habilitado no boot"
systemctl is-active rsyslog >/dev/null 2>&1 && ok "rsyslog ativo"   || fail "rsyslog inativo"
journalctl --disk-usage >/dev/null 2>&1     && ok "journald persistente" || fail "journald nao persistente"

echo
echo "=== 6. Docker ==="
systemctl is-enabled docker.socket >/dev/null 2>&1 \
    && fail "docker.socket rootful ainda habilitado" || ok "docker.socket rootful desabilitado"
systemctl is-enabled docker.service >/dev/null 2>&1 \
    && fail "docker.service rootful ainda habilitado" || ok "docker.service rootful desabilitado"
getent group docker | grep -q ':.*[^:]' \
    && fail "grupo docker tem membros — verificar se sao devs" || ok "grupo docker vazio"

echo
echo "=== 7. Permissoes de home ==="
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user="$(basename "$home_dir")"
    id "$user" >/dev/null 2>&1 || continue
    perm=$(stat -c "%a" "$home_dir")
    case "$perm" in
        700|750) ok "home $user perm $perm" ;;
        *)       fail "home $user perm $perm (esperado 700 ou 750)" ;;
    esac
    for cred_dir in .ssh .aws .azure; do
        if [ -d "$home_dir/$cred_dir" ]; then
            dp=$(stat -c "%a" "$home_dir/$cred_dir")
            [ "$dp" = "700" ] && ok "$user/$cred_dir = 700" || fail "$user/$cred_dir = $dp (esperado 700)"
        fi
    done
done

echo
echo "=== 8. umask e limites ==="
grep -q "umask 027" /etc/profile.d/30-vdi-umask.sh 2>/dev/null \
    && ok "umask 027 configurado" || fail "umask 027 ausente em /etc/profile.d/"
grep -q "hard core" /etc/security/limits.d/90-vdi-dev.conf 2>/dev/null \
    && ok "core dump desabilitado via limits.d" || fail "limite core ausente"
grep -q "hard nproc" /etc/security/limits.d/90-vdi-dev.conf 2>/dev/null \
    && ok "nproc limit configurado" || fail "nproc limit ausente"

echo
echo "=== 9. Azure e AWS CLI ==="
command -v az      >/dev/null 2>&1 && ok "azure-cli instalado" || info "azure-cli nao encontrado (INSTALL_DEV_TOOLS?)"
command -v aws     >/dev/null 2>&1 && ok "aws-cli instalado"   || info "aws-cli nao encontrado (INSTALL_DEV_TOOLS?)"

echo
echo "=== 10. Portas em escuta ==="
info "Portas TCP em escuta (verificar se sao esperadas):"
ss -lntp 2>/dev/null | tail -n +2 | while read -r line; do info "  $line"; done

echo
echo "============================================"
printf "Postcheck concluido: %s OK, %s FAIL\n" "$PASS" "$FAIL"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then
    echo "Acoes manuais necessarias: revisar os itens [FAIL] acima."
    exit 1
fi
'
    run "Run postcheck" /usr/local/sbin/vdi-hardening-postcheck
}

main() {
    require_root
    init_logging
    check_platform

    start_section "01-apt"
    run "Update apt metadata" apt-get update

    configure_identity_placeholders
    configure_privilege_model
    configure_ssh
    install_dev_tools
    configure_docker_rootless
    configure_filesystem_and_home
    configure_kernel_network
    configure_services
    configure_logging_audit
    configure_audit_shell_inits      # auditoria de shell inits com paths absolutos
    write_postcheck

    printf '\n============================================\n'
    printf 'Ubuntu VDI hardening\n'
    printf 'Version: %s\n' "$VERSION"
    printf 'Errors:  %d\n' "$ERRORS"
    printf 'Logs:    %s\n' "$LOG_DIR"
    printf '\nNext steps:\n'
    printf '1. Ajustar dominio AD e executar realm join / realm permit.\n'
    printf '2. Confirmar que devs nao pertencem a sudo/admin/docker rootful.\n'
    printf '3. Executar setup-rootless-docker-user <usuario> apos primeiro login de cada dev.\n'
    printf '4. Executar vdi-fix-user-home-perms apos criacao de cada home AD.\n'
    printf '5. Para novos usuarios AD: re-executar configure_audit_shell_inits ou rodar augenrules --load.\n'
    printf '6. Validar Python, Java, C/C++, AWS CLI, Azure CLI, IDE, Citrix e Docker rootless.\n'
    printf '7. Rodar /usr/local/sbin/vdi-hardening-postcheck apos reboot.\n'
    printf '============================================\n'

    if [ "$ERRORS" -gt 0 ]; then
        exit 1
    fi
}

main "$@"
