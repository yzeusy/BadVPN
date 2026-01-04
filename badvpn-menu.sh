#!/bin/bash

BASE="/etc/badvpn"

pause() {
  echo ""
  read -p "Pressione ENTER para voltar ao menu..."
}

banner() {
  GREEN="\e[32m"
  RED="\e[31m"
  NC="\e[0m"

  PORT_LIST="7300 3478 10000"
  ACTIVE_PORTS=""

  for p in $PORT_LIST; do
    if ss -lun | awk '{print $5}' | grep -q ":$p$"; then
      ACTIVE_PORTS="$ACTIVE_PORTS $p"
    fi
  done
  clear
  echo "======================================="
  echo "            BadVPN Manager             "
  echo "======================================="
  if [ -n "$ACTIVE_PORTS" ]; then
    echo -e " Status: ${GREEN}ATIVO${NC} | Portas:${GREEN}$ACTIVE_PORTS${NC}"
  else
    echo -e " Status: ${RED}PARADO${NC}"
  fi
  echo "======================================="
  echo ""
}

install_badvpn() {
  banner
  sudo bash "$BASE/easyinstall" >/dev/null 2>&1
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

optimize_badvpn() {
  banner
  sudo bash "$BASE/badvpn-auto-optimize.sh" >/dev/null 2>&1
  echo "⚡ BadVPN otimizado com sucesso!"
  pause
}

remove_optimizations() {
  banner
  sudo rm -f /etc/sysctl.d/99-badvpn.conf
  sudo rm -rf /etc/systemd/system/badvpn.service.d
  sudo sed -i 's/--tun-mtu [0-9]\+//g' /etc/systemd/system/badvpn.service
  sudo sed -i 's/--buffer-size [0-9]\+//g' /etc/systemd/system/badvpn.service
  sudo systemctl daemon-reload
  sudo systemctl restart badvpn >/dev/null 2>&1
  echo "🧹 Otimizações removidas"
  pause
}

uninstall_badvpn() {
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
}

setup_multiport() {
  banner
  echo "Configurando BadVPN Multi-Porta..."
  sleep 1

  # Criar service template
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
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  # Criar service pai
  cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (All Ports)
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

  # Recarregar systemd
  systemctl daemon-reload

  # Ativar serviços
  systemctl enable badvpn@7300 badvpn@3478 badvpn@10000 >/dev/null 2>&1
  systemctl enable badvpn >/dev/null 2>&1

  # Reiniciar
  systemctl restart badvpn

  echo ""
  echo "✅ BadVPN configurado em MULTI-PORTA:"
  echo "   • UDP 7300"
  echo "   • UDP 3478"
  echo "   • UDP 10000"
  pause
}


while true; do
  banner
  echo " 1) Instalar BadVPN"
  echo " 2) Remover BadVPN"
  echo ""
  echo " 3) Iniciar [7300]"
  echo " 4) Parar"
  echo " 5) Reiniciar"
  echo ""
  echo " 6) Iniciar Multi-Porta [7300 / 3478 / 10000]"
  echo ""
  echo " 7) Otimizar sistema + BadVPN [BETA]"
  echo " 8) Remover otimizações"
  echo ""
  echo " 0) Sair"
  echo ""
  read -p "Escolha uma opção: " opt

  case "$opt" in
    1) install_badvpn ;;
    2) uninstall_badvpn ;;
    3) start_badvpn ;;
    4) stop_badvpn ;;
    5) restart_badvpn ;;
    6) setup_multiport ;;
    7) optimize_badvpn ;;
    8) remove_optimizations ;;
    0) clear; exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
