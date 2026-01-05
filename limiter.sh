#!/usr/bin/env bash

# ================== CONFIG ==================
CORE="/etc/limiter_core.sh"
DATABASE="/root/usuarios.db"
LOGFILE="/etc/banido.log"
SERVICE="/etc/systemd/system/limiter.service"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.limiter.bak"

OVPN_CONFIG=""
OVPN_BACKUP=""
# ============================================

detect_openvpn_conf() {
  for f in /etc/openvpn/server.conf /etc/openvpn/openvpn.conf /etc/openvpn/*.conf; do
    [[ -f "$f" ]] && OVPN_CONFIG="$f" && break
  done
  [[ -n "$OVPN_CONFIG" ]] && OVPN_BACKUP="${OVPN_CONFIG}.limiter.bak"
}

apply_ssh_lock() {
  [[ -f "$SSHD_BACKUP" ]] || cp "$SSHD_CONFIG" "$SSHD_BACKUP"
  sed -i '/^MaxSessions/d' "$SSHD_CONFIG"
  cat >> "$SSHD_CONFIG" <<EOF

# === LIMITER LOCK ===
MaxSessions 1
EOF
  systemctl restart ssh
}

apply_openvpn_lock() {
  detect_openvpn_conf
  [[ -z "$OVPN_CONFIG" ]] && return
  [[ -f "$OVPN_BACKUP" ]] || cp "$OVPN_CONFIG" "$OVPN_BACKUP"
  sed -i '/^duplicate-cn/d' "$OVPN_CONFIG"
  echo "duplicate-cn 0" >> "$OVPN_CONFIG"
  systemctl restart openvpn 2>/dev/null || systemctl restart openvpn-server@server 2>/dev/null
}

restore_ssh_lock() {
  [[ -f "$SSHD_BACKUP" ]] && {
    cp "$SSHD_BACKUP" "$SSHD_CONFIG"
    rm -f "$SSHD_BACKUP"
    systemctl restart ssh
  }
}

restore_openvpn_lock() {
  detect_openvpn_conf
  [[ -f "$OVPN_BACKUP" ]] && {
    cp "$OVPN_BACKUP" "$OVPN_CONFIG"
    rm -f "$OVPN_BACKUP"
    systemctl restart openvpn 2>/dev/null || systemctl restart openvpn-server@server 2>/dev/null
  }
}

create_core() {
cat > "$CORE" << 'EOF'
#!/usr/bin/env bash

DATABASE="/root/usuarios.db"
LOGFILE="/etc/banido.log"
OVPN_STATUS="/etc/openvpn/openvpn-status.log"
INTERVAL=1

log() {
  echo "[$(date '+%F %T')] $1" >> "$LOGFILE"
}

count_ssh() {
  ps -u "$1" --no-headers | grep -c "[s]shd"
}

count_openvpn() {
  [[ -f "$OVPN_STATUS" ]] || echo 0
  grep -c ",$1," "$OVPN_STATUS" 2>/dev/null
}

kill_openvpn() {
  local user=$1
  local excess=$2
  grep ",$user," "$OVPN_STATUS" | cut -d',' -f3 | head -n "$excess" | while read -r pid; do
    kill "$pid" 2>/dev/null
    log "$user OPENVPN PID $pid FINALIZADO"
  done
}

check_user() {
  local user=$1
  local limit=$2

  local ssh ovpn
  ssh=$(count_ssh "$user")
  ovpn=$(count_openvpn "$user")

  if (( ssh > limit )); then
    pkill -u "$user"
    log "$user SSH EXCEDEU ($ssh/$limit)"
  fi

  if (( ovpn > limit )); then
    kill_openvpn "$user" $((ovpn - limit))
    log "$user OPENVPN EXCEDEU ($ovpn/$limit)"
  fi
}

while true; do
  while read -r user limit; do
    id "$user" &>/dev/null || continue
    check_user "$user" "$limit"
  done < "$DATABASE"
  sleep "$INTERVAL"
done
EOF

chmod +x "$CORE"
}

create_service() {
cat > "$SERVICE" << EOF
[Unit]
Description=Limiter SSH + OpenVPN Service
After=network.target openvpn.service
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/bash $CORE
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
}

enable_limiter() {
  echo "Ativando limiter..."
  apply_ssh_lock
  apply_openvpn_lock
  create_core
  create_service

  [[ ! -f "$DATABASE" ]] && echo "usuario 1" > "$DATABASE"
  touch "$LOGFILE"

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable limiter.service
  systemctl start limiter.service

  echo "Limiter ATIVADO"
  sleep 2
}

disable_limiter() {
  echo "Desativando limiter..."
  systemctl stop limiter.service 2>/dev/null
  systemctl disable limiter.service 2>/dev/null

  restore_ssh_lock
  restore_openvpn_lock

  rm -f "$SERVICE"
  rm -f "$CORE"
  rm -f "$LOGFILE"

  systemctl daemon-reload

  echo "Limiter DESATIVADO"
  sleep 2
}

get_status() {
  systemctl is-active --quiet limiter.service && echo "ATIVO" || echo "DESATIVADO"
}

menu() {
  while true; do
    clear
    STATUS=$(get_status)

    echo "====== LIMITER MANAGER ======"
    echo "============================="
    echo "Status: [ $STATUS ]"
    echo "============================="
    echo "01) Ativar Limiter"
    echo "02) Desativar Limiter"
    echo "00) Volar"
    echo "============================="
    read -rp "Escolha: " opt

    case $opt in
    01 | 1)
        [[ "$STATUS" == "ATIVO" ]] && echo "Já está ativo" || enable_limiter
        sleep 1
        ;;
    02 | 2)
        [[ "$STATUS" == "DESATIVADO" ]] && echo "Já está desativado" || disable_limiter
        sleep 1
        ;;
    00 | 0)
        clear
        bash <(curl -sL https://raw.githubusercontent.com/DTunnel0/CheckUser-Go/master/ottmenu)
        exit
        ;;
      *)
        echo "Opção inválida"
        sleep 1
        ;;
    esac
  done
}

menu
