# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  DATA     = Time.now.strftime("%Y%m%d")
  VM_NAME  = "dubuntu-desktop-2404-lts-#{DATA}"
  VM_IP    = "192.168.56.44"
  VM_USER  = "renato"
  VM_PASS  = "C9p5au8naa@2025"

  config.vm.box      = "gusztavvargadr/ubuntu-desktop-2404-lts"
  config.vm.hostname = VM_NAME

  config.vm.network "private_network", ip: VM_IP

  config.vm.provider "virtualbox" do |vb|
    vb.name   = VM_NAME
    vb.memory = "4096"
    vb.cpus   = 1
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end

  config.ssh.insert_key     = false
  config.ssh.forward_agent  = false

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    set -e

    echo "=============================================================="
    echo "Configurando User, SSH, Timezone e Desktop - $(date)"
    echo "=============================================================="

    # Timezone
    timedatectl set-timezone America/Sao_Paulo || true

    # Atualiza repos
    apt-get update

    # Usuário + sudo (Debian usa sudo, não wheel)
    if ! id -u "#{VM_USER}" >/dev/null 2>&1; then
      useradd -m -s /bin/bash "#{VM_USER}"
      echo "#{VM_USER}:#{VM_PASS}" | chpasswd
      usermod -aG sudo "#{VM_USER}"
      echo "[OK] Usuário #{VM_USER} criado e adicionado ao sudo."
    fi

    # DESKTOP (Debian 12 GNOME)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      tree \
      ansible \
      btop \
      duf

    systemctl enable gdm3
    systemctl set-default graphical.target

    # SSH keys
    configure_ssh() {
      local USER_HOME=$1
      local USER_NAME=$2
      local SSH_DIR="$USER_HOME/.ssh"
      local AUTH_KEYS="$SSH_DIR/authorized_keys"

      mkdir -p "$SSH_DIR"

      cat << 'EOF' > "$AUTH_KEYS"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPAlHi1VtrLbSHgrCimWs1/fPAyw2r163EhAHOuM3k8N99n+7nqiZzALcEqwVB6GzKksMJxVoEe1erjq/XmKb0vd1CHKgqZ+Qm38fA/3D8gK8eVO71j+3ArbdxBPwYbGZ8yulpsDPCSAosJ0n9vnB0a4X1FORKGxJWm4/U/og9uXOq0x17JXMSRPOZT3g2U/JDms183Tump5St3rY2Kxddz4K5u0Xv4j1j9CuDKIeYBHZyT5JpHRSHu+VD7iOUF0XgbduqYXhmjFj0JGgb/00bs1Tn3E3x4lsToLN5/M+xj1KiKtnKm7OOcg7Vtq5dJZuReuiB0accpkZlUx5HHxPL grupo easy@easynb1422
ssh-ed25519 TESTE
EOF

      sed -i '/^$/d' "$AUTH_KEYS"
      chown -R "$USER_NAME":"$USER_NAME" "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      chmod 600 "$AUTH_KEYS"
    }

    configure_ssh "/home/vagrant" "vagrant"
    configure_ssh "/home/#{VM_USER}" "#{VM_USER}"

    # Banner
    cat > /etc/issue.net << 'BANNER'
************************************************************
* ACESSO RESTRITO — SISTEMA MONITORADO HITSS              *
************************************************************
Uso exclusivo de pessoal autorizado.
BANNER

    chmod 644 /etc/issue.net

    echo "[OK] Provisionamento finalizado."
  SHELL
end