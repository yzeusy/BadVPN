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
  local ports services status color

  # Coletar services badvpn ativos
  services=$(systemctl list-units --type=service --all | awk '/badvpn/ && /running/ {print $1}')

  [[ -z "$services" ]] && {
    echo -e " Status: ${RED}PARADO${NC}"
    return
  }

  ports=""

  for svc in $services; do
    # Extrair listen-addr do ExecStart
    port=$(systemctl cat "$svc" 2>/dev/null \
      | grep -- '--listen-addr' \
      | sed -n 's/.*--listen-addr [^:]*:\([0-9]\+\).*/\1/p')

    [[ -n "$port" ]] && ports+="$port "
  done
  ports=$(echo "$ports" | tr ' ' '\n' | sort -n | uniq | tr '\n' ' ')

  if [[ -n "$ports" ]]; then
    echo -e " Status: ${GREEN}ATIVO | Portas: $ports ${NC}"
  else
    echo -e " Status: ${RED}PARADO${NC}"
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

while true; do
  banner
  echo " 1) Instalar BadVPN"
  echo ""
  echo " 2) Iniciar [7300]"
  echo " 3) Parar"
  echo " 4) Reiniciar"
  echo " 5) Remover"
  echo ""
  echo " 6) Otimizar sistema + BadVPN [BETA]"
  echo " 7) Remover otimizações"
  echo ""
  echo " 0) Sair"
  echo ""
  read -p "Escolha uma opção: " opt

  case "$opt" in
    1) install_badvpn ;;
    2) start_badvpn ;;
    3) stop_badvpn ;;
    4) restart_badvpn ;;
    5) uninstall_badvpn ;;
    6) optimize_badvpn ;;
    7) remove_optimizations ;;
    0) clear; exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
