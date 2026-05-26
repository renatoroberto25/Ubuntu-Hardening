#!/bin/bash
set -euo pipefail

FLAG_FILE="/var/lib/tenable/nessusagent/.first-boot-done"
NESSUSCLI="/opt/nessus_agent/sbin/nessuscli"
TENABLE_KEY="45b85b603d4f4ed07d445151eacc6db46715a19318c42da539327de707dedbac"
TENABLE_HOST="sensor.cloud.tenable.com"
TENABLE_PORT="443"
TENABLE_GROUPS="LINUX_DEFAULT"
HOSTNAME_VAR="$(hostname -s 2>/dev/null || hostname)"

# Lista de proxies para tentar — vazio = sem proxy (sempre tenta primeiro)
PROXY_LIST=(
  ""
  "http://10.54.24.184:3128"
  "http://10.29.177.37:8080"
  "http://10.243.179.233:3128"
)

STATUS_OUT=""
STATUS_RC=0

log() {
  printf '[%s] %s\n' "$1" "$2"
}

agent_installed() {
  [ -x "$NESSUSCLI" ]
}

read_status() {
  if agent_installed; then
    STATUS_OUT="$("$NESSUSCLI" agent status 2>&1)" && STATUS_RC=0 || STATUS_RC=$?
  else
    STATUS_OUT="nessuscli nao encontrado em $NESSUSCLI"
    STATUS_RC=127
  fi
  return 0
}

status_has() {
  printf '%s\n' "$STATUS_OUT" | grep -Fq "$1"
}

agent_running() {
  read_status
  status_has "Running: Yes"
}

agent_linked_to_expected() {
  read_status
  status_has "Linked to: ${TENABLE_HOST}:${TENABLE_PORT}"
}

agent_connected() {
  read_status
  status_has "Running: Yes" &&
    status_has "Linked to: ${TENABLE_HOST}:${TENABLE_PORT}" &&
    status_has "Link status: Connected to ${TENABLE_HOST}:${TENABLE_PORT}"
}

start_agent() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now nessusagent >/dev/null 2>&1 ||
      systemctl restart nessusagent >/dev/null 2>&1 ||
      true
  fi
  if command -v service >/dev/null 2>&1; then
    service nessusagent start >/dev/null 2>&1 || true
  fi
}

try_install() {
  local proxy="$1"
  if [ -z "$proxy" ]; then
    log "INFO" "Tentando instalar sem proxy..."
  else
    log "INFO" "Tentando instalar via proxy: $proxy"
  fi

  curl -fsSL -G \
    ${proxy:+--proxy "$proxy"} \
    --connect-timeout 15 \
    --max-time 120 \
    -H "X-Key: $TENABLE_KEY" \
    --data-urlencode "name=$HOSTNAME_VAR" \
    --data-urlencode "groups=$TENABLE_GROUPS" \
    "https://${TENABLE_HOST}/install/agent" | bash
}

install_agent() {
  for proxy in "${PROXY_LIST[@]}"; do
    if try_install "$proxy"; then
      log "INFO" "Instalacao concluida${proxy:+ via proxy $proxy}"
      return 0
    fi
    if [ -z "$proxy" ]; then
      log "WARN" "Falha sem proxy. Tentando proxies conhecidos..."
    else
      log "WARN" "Falha via $proxy. Tentando proximo..."
    fi
  done

  log "ERRO" "Nenhuma rota funcionou (sem proxy e todos os proxies conhecidos falharam)."
  log "ERRO" "Verifique conectividade com $TENABLE_HOST:$TENABLE_PORT ou informe o proxy correto para este ambiente."
  exit 1
}

unlink_if_wrong_manager() {
  read_status
  if status_has "Linked to: None"; then
    return 0
  fi
  if status_has "Linked to:" && ! status_has "Linked to: ${TENABLE_HOST}:${TENABLE_PORT}"; then
    log "WARN" "Agent linkado em outro manager. Executando unlink antes do relink."
    "$NESSUSCLI" agent unlink --force >/dev/null 2>&1 || true
  fi
}

link_agent() {
  log "INFO" "Vinculando Tenable Agent em ${TENABLE_HOST}:${TENABLE_PORT}"
  "$NESSUSCLI" agent link \
    --key="$TENABLE_KEY" \
    --host="$TENABLE_HOST" \
    --port="$TENABLE_PORT" \
    --groups="$TENABLE_GROUPS" \
    --name="$HOSTNAME_VAR"
}

wait_connected() {
  local attempt
  for attempt in $(seq 1 12); do
    if agent_connected; then
      return 0
    fi
    log "INFO" "Aguardando conexao com Tenable (${attempt}/12)"
    sleep 10
  done
  return 1
}

finish_ok() {
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
  log "OK" "Agent instalado, rodando e conectado em ${TENABLE_HOST}:${TENABLE_PORT}"
  printf '%s\n' "$STATUS_OUT"
}

# --- Main ---

if ! agent_installed; then
  install_agent
  sleep 5
fi

if ! agent_installed; then
  log "ERRO" "Instalacao finalizou, mas $NESSUSCLI nao existe ou nao e executavel"
  exit 1
fi

start_agent

if agent_connected; then
  finish_ok
  exit 0
fi

read_status

if ! agent_running; then
  log "WARN" "Agent instalado, mas nao parece estar rodando. Tentando iniciar."
  start_agent
fi

if ! agent_linked_to_expected; then
  unlink_if_wrong_manager
  link_agent
  sleep 5
fi

start_agent

if wait_connected; then
  finish_ok
  exit 0
fi

read_status
log "ERRO" "Agent nao chegou ao estado conectado esperado"
printf '%s\n' "$STATUS_OUT"
exit 1