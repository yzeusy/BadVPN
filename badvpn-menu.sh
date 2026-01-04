#!/bin/bash

BASE="/etc/badvpn"

pause() {
  echo ""
  read -p "Pressione ENTER para voltar ao menu..."
}

banner() {
  clear
  echo "======================================="
  echo "        BadVPN Manager - yzeusy         "
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

status_badvpn() {
  banner
  systemctl status badvpn --no-pager
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
  echo " 2) Iniciar BadVPN"
  echo " 3) Parar BadVPN"
  echo " 4) Reiniciar BadVPN"
  echo " 5) Status BadVPN"
  echo ""
  echo " 6) Otimizar sistema + BadVPN"
  echo " 7) Remover otimizações"
  echo ""
  echo " 8) Remover BadVPN"
  echo ""
  echo " 00) Sair"
  echo ""
  read -p "Escolha uma opção: " opt

  case "$opt" in
    1) install_badvpn ;;
    2) start_badvpn ;;
    3) stop_badvpn ;;
    4) restart_badvpn ;;
    5) status_badvpn ;;
    6) optimize_badvpn ;;
    7) remove_optimizations ;;
    8) uninstall_badvpn ;;
    00) clear; exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
