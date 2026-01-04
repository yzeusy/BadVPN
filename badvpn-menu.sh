#!/bin/bash

BASE="/etc/badvpn"

pause() {
  echo ""
  read -p "Pressione ENTER para voltar ao menu..."
}

banner() {
  clear
  echo "======================================="
  echo "            BadVPN Manager             "
  echo "======================================="
  PORTS=$(ss -lunp 2>/dev/null | grep badvpn-udpgw | awk '{print $5}' | awk -F: '{print $NF}' | sort -n | tr '\n' ' ')
  if [ -n "$PORTS" ]; then
    echo " Status:${GREEN} ATIVO | Portas: $PORTS${NC}"
  else
    echo " ${RED}Status: PARADO${NC}"
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
  banner
  read -p "Tem certeza que deseja REMOVER o BadVPN? (s/n): " yn
  if [[ "$yn" =~ ^[Ss]$ ]]; then
    sudo bash "$BASE/uninstall" >/dev/null 2>&1
    echo "🗑️ BadVPN removido completamente"
  else
    echo "❌ Operação cancelada"
  fi
  pause
}

while true; do
  banner
  echo " 1) Instalar BadVPN"
  echo " 2) Remover BadVPN"
  echo ""
  echo " 3) Iniciar"
  echo " 4) Parar"
  echo " 5) Reiniciar"
  echo ""
  echo " 6) Otimizar sistema + BadVPN [BETA]"
  echo " 7) Remover otimizações"
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
    6) optimize_badvpn ;;
    7) remove_optimizations ;;
    0) clear; exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
