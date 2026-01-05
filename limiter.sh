#!/usr/bin/env bash

# ================== CONFIG ==================
BASE_DIR="/etc/limiter"
CORE="$BASE_DIR/limiter_core.sh"
DATABASE="/root/usuarios.db"
LOGFILE="$BASE_DIR/banido.log"
SERVICE="/etc/systemd/system/limiter.service"
# ============================================

create_core() {
mkdir -p "$BASE_DIR"

cat > "$CORE" << 'EOF'
#!/usr/bin/env bash

BASE_DIR="/etc/limiter"
DATABASE="/root/usuarios.db"
LOGFILE="$BASE_DIR/banido.log"
OVPN_STATUS="/etc/openvpn/openvpn-status.log"
INTERVAL=15

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

count_badvpn() {
  ps aux | grep "[b]advpn-udpgw" | grep "$1" | wc -l
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

  local ssh ovpn badvpn
  ssh=$(count_ssh "$user")
  ovpn=$(count_openvpn "$user")
  badvpn=$(count_badvpn "$user")

  # 🚨 TOLERÂNCIA ZERO
  # Se QUALQUER serviço ultrapassar o limite → derruba NA HORA

  if (( ssh > limit )); then
    pkill -u "$user"
    log "$user SSH TOLERANCIA ZERO ($ssh/$limit)"
    return
  fi

  if (( ovpn > limit )); then
    kill_openvpn "$user" $((ovpn - limit))
    log "$user OPENVPN TOLERANCIA ZERO ($ovpn/$limit)"
    return
  fi

  if (( badvpn > limit )); then
    pkill -f "badvpn-udpgw.*$user"
    log "$user BADVPN TOLERANCIA ZERO ($badvpn/$limit)"
    return
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
Description=Limiter SSH OpenVPN BadVPN
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
  create_core
  create_service

  [[ ! -f "$DATABASE" ]] && echo "usuario 1" > "$DATABASE"
  touch "$LOGFILE"

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable limiter.service
  systemctl start limiter.service

  echo "✅ Limiter ATIVADO"
  sleep 2
}

disable_limiter() {
  systemctl stop limiter.service 2>/dev/null
  systemctl disable limiter.service 2>/dev/null

  rm -f "$SERVICE"
  rm -rf "$BASE_DIR"

  systemctl daemon-reload

  echo "❌ Limiter DESATIVADO (usuarios.db preservado)"
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
    echo "Status: [ $STATUS ]"
    echo "============================"
    echo "01) Ativar Limiter"
    echo "02) Desativar Limiter"
    echo "============================"
    echo "00) Voltar"
    echo "============================"
    read -rp "Escolha: " opt

    case $opt in
    01 | 1) [[ "$STATUS" == "ATIVO" ]] || enable_limiter ;;
    02 | 2) [[ "$STATUS" == "DESATIVADO" ]] || disable_limiter ;;
    00 | 0) clear
         bash <(curl -sL https://raw.githubusercontent.com/DTunnel0/CheckUser-Go/master/ottmenu)
         exit ;;
      *) echo "Opção inválida" ;;
    esac
    sleep 1
  done
}

menu
