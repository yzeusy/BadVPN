#!/bin/bash

BASE="/etc/badvpn"

pause() {
  echo ""
  read -p "Pressione ENTER para voltar ao menu..."
}

banner() {
  clear
  GREEN="\e[32m"
  RED="\e[31m"
  NC="\e[0m"

  get_active_ports() {
  local ports=""

  # MULTI-PORTAS EXISTE
  if [[ -f /etc/systemd/system/badvpn@.service ]]; then

    # 1️⃣ Tentar pegar portas ATIVAS
    ports=$(systemctl list-units --type=service --state=running \
      | awk '/badvpn@[0-9]+\.service/ {
          gsub(/.*@|\.service/, "", $1); print $1
        }' | sort -n | tr '\n' ' ')

    # 2️⃣ Se não houver portas ativas, pegar portas CONFIGURADAS
    if [[ -z "$ports" ]]; then
      ports=$(systemctl cat badvpn 2>/dev/null \
        | awk '/Requires=badvpn@[0-9]+\.service/ {
            gsub(/.*@|\.service/, "", $0); print $0
          }' | sort -n | tr '\n' ' ')
    fi

  else
    # PORTA ÚNICA (ativa ou parada)
    ports=$(systemctl cat badvpn 2>/dev/null \
      | grep -- '--listen-addr' \
      | sed -n 's/.*:\([0-9]\+\).*/\1/p')
  fi

  if [[ -n "$ports" ]]; then
    echo -e "Status: ${GREEN}ATIVO | Portas: $ports ${NC}"
  else
    echo -e "Status: ${RED}PARADO${NC}"
  fi
}
  echo "======================================="
  echo "            BadVPN Manager             "
  echo "======================================="
  get_active_ports
  echo "======================================="
}

install_badvpn() {
  banner
  bash <(curl -sL https://raw.githubusercontent.com/yzeusy/BadVPN/refs/heads/main/easyinstall) >/dev/null 2>&1
  echo "✅ BadVPN instalado com sucesso!"
  pause
}

start_badvpn() {
  banner
  sudo systemctl start badvpn >/dev/null 2>&1
  echo "🚀 BadVPN iniciado"
  pause
}

stop_badvpn() {
  banner
  sudo systemctl stop badvpn >/dev/null 2>&1
  echo "🛑 BadVPN parado"
  pause
}

restart_badvpn() {
  banner
  sudo systemctl restart badvpn >/dev/null 2>&1
  echo "🔄 BadVPN reiniciado"
  pause
}

is_multiport() {
  [[ -f /etc/systemd/system/badvpn@.service ]]
}

optimize_badvpn() {
  banner
  echo "⚡ Aplicando otimizações no BadVPN..."
  sleep 1

  echo "📦 Ajustando sysctl..."
  cat > /etc/sysctl.d/99-badvpn.conf <<'EOF'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 50000
net.ipv4.udp_mem = 65536 131072 262144
EOF

  sysctl --system >/dev/null 2>&1

  if is_multiport; then
    echo "🔀 Modo MULTI-PORTAS detectado"

    cat > /etc/systemd/system/badvpn@.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (%i)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:%i \
--max-clients 1000 \
--buffer-size 32768

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart badvpn

  else
    echo "🔹 Modo PORTA ÚNICA detectado"

    cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7300 \
--max-clients 1000 \
--buffer-size 32768

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart badvpn
  fi

  echo "✅ Otimização aplicada com sucesso"
  pause
}


remove_optimizations() {
  banner
  echo "🧹 Removendo otimizações do BadVPN..."
  sleep 1

  rm -f /etc/sysctl.d/99-badvpn.conf
  sysctl --system >/dev/null 2>&1

  if is_multiport; then
    echo "🔀 Multi-portas detectado — limpando template"

    cat > /etc/systemd/system/badvpn@.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (%i)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:%i \
--max-clients 1000

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart badvpn

  else
    echo "🔹 Porta única detectada — limpando service"

    cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7300 \
--max-clients 1000

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart badvpn
  fi

  echo "✅ Otimizações removidas com sucesso"
  pause
}

uninstall_badvpn() {
  banner
  read -p "Tem certeza que deseja REMOVER COMPLETAMENTE o BadVPN? (s/n): " yn

  if [[ ! "$yn" =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    pause
    return
  fi

  echo "🛑 Parando serviços BadVPN..."
  systemctl stop badvpn >/dev/null 2>&1 || true
  systemctl stop badvpn@* >/dev/null 2>&1 || true

  echo "🚫 Desabilitando serviços..."
  systemctl disable badvpn >/dev/null 2>&1 || true
  systemctl disable badvpn@* >/dev/null 2>&1 || true

  echo "🔄 Recarregando systemd..."
  systemctl daemon-reload

  echo "🧹 Removendo arquivos..."

  # Remover services
  rm -f /etc/systemd/system/badvpn.service
  rm -f /etc/systemd/system/badvpn@.service

  # Remover diretório do repo
  rm -rf /etc/badvpn

  # Remover binários
  rm -f /usr/local/bin/badvpn
  rm -f /usr/local/bin/badvpn-udpgw
  rm -f /usr/local/bin/badvpn-server
  rm -f /usr/local/bin/badvpn-tun2socks

  # Remover otimizações (se existirem)
  rm -f /etc/sysctl.d/99-badvpn.conf
  rm -rf /etc/systemd/system/badvpn.service.d

  systemctl daemon-reexec >/dev/null 2>&1

  echo ""
  echo "✅ BadVPN REMOVIDO COMPLETAMENTE do sistema"
  pause
}

setup_multiport() {
  banner
  echo "🔧 Configurando BadVPN em modo MULTI-PORTA..."
  sleep 1

  echo "🔍 Verificando se porta 7300 está ativa..."
  if ss -lun | grep -q ':7300'; then
    echo "⚠️ Porta 7300 em uso — limpando modo simples..."

    systemctl stop badvpn >/dev/null 2>&1 || true
    systemctl disable badvpn >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/badvpn.service

    pkill -9 badvpn-udpgw >/dev/null 2>&1 || true
  fi

  echo "🧹 Limpando serviços antigos..."
  systemctl stop badvpn@* >/dev/null 2>&1 || true
  systemctl disable badvpn@* >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/badvpn@.service

  systemctl daemon-reload
  systemctl daemon-reexec

  echo "🧱 Criando service template..."

  cat > /etc/systemd/system/badvpn@.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (%i)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:%i \
--max-clients 1000

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  echo "🧱 Criando service pai..."

  cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (Multi-Port)
After=network.target
Requires=badvpn@7300.service badvpn@3478.service badvpn@10000.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload

  echo "🚀 Ativando portas 7300 / 3478 / 10000..."
  systemctl enable badvpn@7300 badvpn@3478 badvpn@10000 >/dev/null 2>&1
  systemctl enable badvpn >/dev/null 2>&1

  systemctl start badvpn

  echo ""
  echo "✅ BadVPN MULTI-PORTA ativo com sucesso!"
  echo "➡️ Portas: 7300 3478 10000"
  pause
}

remove_multiport() {
  banner
  read -p "Remover MULTI-PORTAS e voltar para porta única (7300)? (s/n): " yn

  if [[ ! "$yn" =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    pause
    return
  fi

  echo "🛑 Parando serviços multi-porta..."
  systemctl stop badvpn >/dev/null 2>&1 || true
  systemctl stop badvpn@* >/dev/null 2>&1 || true

  echo "🚫 Desabilitando instâncias..."
  systemctl disable badvpn@* >/dev/null 2>&1 || true
  systemctl disable badvpn >/dev/null 2>&1 || true

  echo "🧹 Limpando services antigos..."
  rm -f /etc/systemd/system/badvpn@.service
  rm -f /etc/systemd/system/badvpn.service

  echo "🧨 Matando processos órfãos..."
  pkill -9 badvpn-udpgw >/dev/null 2>&1 || true

  systemctl daemon-reload
  systemctl daemon-reexec

  echo "🧱 Restaurando service simples (7300)..."

  cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7300 \
--max-clients 1000

Restart=always
RestartSec=3
KillMode=process
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable badvpn >/dev/null 2>&1
  systemctl start badvpn

  echo ""
  echo "✅ Multi-portas REMOVIDO com sucesso"
  echo "➡️ BadVPN ativo apenas na porta 7300"
  pause
}

restart_multiport() {
  banner

  # Verificar se multi-porta existe
  if [[ ! -f /etc/systemd/system/badvpn@.service ]]; then
    echo "❌ Multi-portas não está configurado"
    pause
    return
  fi

  echo "🔄 Reiniciando BadVPN MULTI-PORTA..."
  sleep 1

  echo "🛑 Parando instâncias..."
  systemctl stop badvpn >/dev/null 2>&1 || true
  systemctl stop badvpn@* >/dev/null 2>&1 || true

  echo "🧨 Limpando processos órfãos..."
  pkill -9 badvpn-udpgw >/dev/null 2>&1 || true

  echo "🚀 Iniciando novamente..."
  systemctl start badvpn

  sleep 1

  # Verificação final
  if ss -lun | grep -Eq ':(7300|3478|10000)'; then
    echo "✅ Multi-portas reiniciado com sucesso"
  else
    echo "⚠️ Atenção: nenhuma porta ativa após reinício"
  fi

  pause
}

while true; do
  banner
  echo " 01) Instalar BadVPN"
  echo " 02) Remover BadVPN"
  echo "======================================="
  echo " 03) Abrir Porta: 7300"
  echo " 04) Reiniciar"
  echo "======================================="
  echo " 05) Abrir Multi Portas"
  echo " 06) Reiniciar"
  echo " 07) Remover"
  echo "======================================="
  echo " 08) Otimizar BadVPN [BETA]"
  echo " 09) Remover otimizações"
  echo "======================================="
  echo " 00) Sair"
  echo ""
  read -p "Escolha uma opção: " opt

  case "$opt" in
    01 | 1) install_badvpn ;;
    02 | 2) uninstall_badvpn ;;
    03 | 3) start_badvpn ;;
    04 | 4) restart_badvpn ;;
    05 | 5) setup_multiport ;;
    06 | 6) restart_multiport ;;
    07 | 7) remove_multiport ;;
    08 | 8) optimize_badvpn ;;
    09 | 9) remove_optimizations ;;
    00 | 0) clear; exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
