# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Lab VDI Ubuntu 24.04 - ambiente pre-hardening realista.
# Uso:
#   vagrant up                        # defaults
#   VDI_VM_USER=joao VDI_VM_PASS=s3cr3t vagrant up
#   VDI_VM_MEMORY=8192 VDI_VM_CPUS=4 vagrant up
#
# Depois de up: aplicar hardening COMO ROOT:
#   vagrant ssh              # entra como vagrant (tem sudo)
#   sudo -i
#   bash /tmp/hardening/Hardening-Ubuntu-2404-VDI-Desktop-v2.sh
#
# Para testar como dev apos hardening:
#   ssh <VDI_VM_USER>@<VDI_VM_IP>   ou   su - <VDI_VM_USER> dentro da VM

Vagrant.configure("2") do |config|

  date    = Time.now.strftime("%Y%m%d")
  vm_name = "ubuntu-desktop-2404-vdi-#{date}"
  vm_ip   = ENV.fetch("VDI_VM_IP",     "192.168.56.44")
  vm_user = ENV.fetch("VDI_VM_USER",   "renato")
  vm_pass = ENV.fetch("VDI_VM_PASS",   "C9p5au8naa@")
  vm_sudo = ENV.fetch("VDI_VM_SUDO",   "false")

  config.vm.box      = "caspermeijn/ubuntu-desktop-24.04"
  config.vm.hostname = vm_name

  config.vm.network "private_network", ip: vm_ip

  config.ssh.forward_agent = false

  config.vm.provider "virtualbox" do |vb|
    vb.name   = vm_name
    vb.memory = ENV.fetch("VDI_VM_MEMORY", "4096").to_i
    vb.cpus   = ENV.fetch("VDI_VM_CPUS",   "2").to_i
    vb.customize ["modifyvm", :id, "--vram",              "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller","vmsvga"]
    vb.customize ["modifyvm", :id, "--clipboard-mode",   "disabled"]
    vb.customize ["modifyvm", :id, "--draganddrop",      "disabled"]
  end

  # ── Provisionamento: ambiente dev pre-hardening ──────────────────────────
  # Variaveis passadas como env para evitar interpolacao Ruby dentro do shell
  # (senhas com $, ! ou # quebrariam o heredoc).
  config.vm.provision "shell",
    privileged: true,
    env: {
      "LAB_USER" => vm_user,
      "LAB_PASS" => vm_pass,
      "LAB_SUDO" => vm_sudo,
    },
    inline: <<~'SHELL'
      set -eu
      echo "== Ubuntu 24.04 VDI lab bootstrap: $(date) =="

      timedatectl set-timezone America/Sao_Paulo || true

      apt-get update -qq

      # ── Grupos esperados pelo hardening ──────────────────────────────────
      groupadd -f vdi-devs
      groupadd -f vdi-admins

      # ── Usuario dev de lab ───────────────────────────────────────────────
      if ! id -u "$LAB_USER" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$LAB_USER"
        echo "[OK] Usuario $LAB_USER criado."
      else
        echo "[OK] Usuario $LAB_USER ja existe."
      fi

      echo "${LAB_USER}:${LAB_PASS}" | chpasswd

      # Dev entra em vdi-devs; sudo somente se explicitamente pedido
      usermod -aG vdi-devs "$LAB_USER"

      if [ "$LAB_SUDO" = "true" ]; then
        usermod -aG sudo "$LAB_USER"
        echo "[OK] $LAB_USER adicionado ao sudo (LAB_SUDO=true)."
      else
        gpasswd -d "$LAB_USER" sudo >/dev/null 2>&1 || true
        echo "[OK] $LAB_USER mantido sem sudo — simula dev VDI real."
      fi

      # ── Toolchain dev (o hardening vai encontrar isso instalado) ─────────
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-venv python3-pip pipx \
        build-essential gcc g++ make gdb \
        default-jdk maven \
        git git-lfs curl ca-certificates unzip jq \
        vim tree btop \
        docker.io docker-buildx uidmap slirp4netns fuse-overlayfs \
        dbus-user-session rootlesskit

      # AWS CLI v2 via instalador oficial. Em algumas imagens Ubuntu 24.04
      # o pacote apt "awscli" nao esta habilitado/disponivel.
      if ! command -v aws >/dev/null 2>&1; then
        arch="$(uname -m)"
        case "$arch" in
          x86_64|amd64) aws_arch="x86_64" ;;
          aarch64|arm64) aws_arch="aarch64" ;;
          *) echo "[ERRO] Arquitetura nao suportada para AWS CLI: $arch" >&2; exit 1 ;;
        esac

        tmpdir="$(mktemp -d)"
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o "${tmpdir}/awscliv2.zip"
        unzip -q "${tmpdir}/awscliv2.zip" -d "$tmpdir"
        "${tmpdir}/aws/install" --update
        rm -rf "$tmpdir"
        echo "[OK] AWS CLI v2 instalado."
      else
        echo "[OK] AWS CLI ja presente."
      fi

      # Azure CLI via repo oficial Microsoft
      if ! command -v az >/dev/null 2>&1; then
        install -d -m 0755 /etc/apt/keyrings
        curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
        chmod 0644 /etc/apt/keyrings/microsoft.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/azure-cli/ noble main" \
          > /etc/apt/sources.list.d/azure-cli.list
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y azure-cli
        echo "[OK] Azure CLI instalado."
      else
        echo "[OK] Azure CLI ja presente."
      fi

      # Docker rootful ativo antes do hardening (o hardening vai desabilitar)
      systemctl enable --now docker || true

      # Dev NAO entra no grupo docker rootful — hardening vai validar isso
      gpasswd -d "$LAB_USER" docker >/dev/null 2>&1 || true

      # ── Alguns arquivos sensiveis no home para testar permissoes ─────────
      DEV_HOME="/home/${LAB_USER}"
      install -d -m 0700 -o "$LAB_USER" -g "$LAB_USER" "${DEV_HOME}/.ssh"
      install -d -m 0777 -o "$LAB_USER" -g "$LAB_USER" "${DEV_HOME}/.aws"   # intencional: perms erradas para o hardening corrigir
      install -d -m 0777 -o "$LAB_USER" -g "$LAB_USER" "${DEV_HOME}/.azure" # idem
      touch "${DEV_HOME}/.aws/credentials"
      chmod 0644 "${DEV_HOME}/.aws/credentials"   # intencional: arquivo exposto
      chown "$LAB_USER:$LAB_USER" "${DEV_HOME}/.aws/credentials"

      # ── Banner ───────────────────────────────────────────────────────────
      cat > /etc/issue.net << 'BANNER'
************************************************************
* ACESSO RESTRITO - UBUNTU VDI LAB (PRE-HARDENING)        *
************************************************************
Ambiente de testes. Aplique o hardening como root antes de usar.
BANNER
      chmod 644 /etc/issue.net

      echo ""
      echo "============================================"
      echo "Bootstrap concluido."
      echo "  Dev user : $LAB_USER (sem sudo, grupo vdi-devs)"
      echo "  Docker   : rootful ativo — hardening vai desabilitar"
      echo "  ~/.aws   : permissoes intencionalmente abertas (0777/0644)"
      echo "  ~/.azure : permissoes intencionalmente abertas (0777)"
      echo ""
      echo "Proximos passos:"
      echo "  1. vagrant ssh"
      echo "  2. sudo -i"
      echo "  3. bash /caminho/Hardening-Ubuntu-2404-VDI-Desktop-v2.sh"
      echo "  4. Logar como $LAB_USER e testar ferramentas dev"
      echo "============================================"
    SHELL

end
