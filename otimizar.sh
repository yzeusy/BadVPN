#!/bin/bash

clear

if [[ $EUID -ne 0 ]]; then
  echo "❌ Execute como root"
  exit 1
fi

add_sysctl() {
  grep -qxF "$1" /etc/sysctl.conf || echo "$1" >> /etc/sysctl.conf
}

add_limit() {
  grep -qxF "$1" /etc/security/limits.conf || echo "$1" >> /etc/security/limits.conf
}

echo "Preparando o sistema..."
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt autoremove -y > /dev/null 2>&1
apt autoclean > /dev/null 2>&1
apt clean > /dev/null 2>&1

clear
echo "=========================================="
echo "         OTIMIZADOR DE VPS VPN            "
echo "=========================================="
echo "1) Otimizar Servidor"
echo "2) Remover Otimizações"
echo "======================================="
echo "0) Sair"
echo
read -p "Escolha uma opção [0/1/2]: " opcao
clear

[[ "$opcao" == "0" ]] && exit 0

if [[ "$opcao" == "1" ]]; then
  add_sysctl "net.core.default_qdisc=fq"
  add_sysctl "net.ipv4.tcp_congestion_control=bbr"
  add_sysctl "net.core.netdev_max_backlog=50000"
  add_sysctl "net.core.rmem_max=67108864"
  add_sysctl "net.core.wmem_max=67108864"
  add_sysctl "net.ipv4.tcp_rmem=4096 87380 67108864"
  add_sysctl "net.ipv4.tcp_wmem=4096 65536 67108864"
  add_sysctl "net.ipv4.tcp_fin_timeout=15"
  add_sysctl "net.ipv4.tcp_keepalive_time=600"
  add_sysctl "net.ipv4.tcp_window_scaling=1"
  add_sysctl "net.ipv4.tcp_low_latency=1"
  add_sysctl "net.ipv6.conf.all.disable_ipv6=1"
  add_sysctl "net.ipv6.conf.default.disable_ipv6=1"
  grep -q "1.1.1.1 8.8.8.8" /etc/systemd/resolved.conf || \
  sed -i 's/^#DNS=.*/DNS=1.1.1.1 8.8.8.8/' /etc/systemd/resolved.conf
  grep -q "9.9.9.9" /etc/systemd/resolved.conf || \
  sed -i 's/^#FallbackDNS=.*/FallbackDNS=9.9.9.9/' /etc/systemd/resolved.conf
  systemctl restart systemd-resolved > /dev/null 2>&1
  add_limit "* soft nofile 1048576"
  add_limit "* hard nofile 1048576"
  sysctl -p > /dev/null 2>&1
  clear
  echo "✅ Servidor otimizado automaticamente!"
  echo "🔁 Reiniciando a VPS.."
  exit 0
  reboot
fi

if [[ "$opcao" == "2" ]]; then
  sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
  sed -i '/net.core.netdev_max_backlog=50000/d' /etc/sysctl.conf
  sed -i '/net.core.rmem_max=67108864/d' /etc/sysctl.conf
  sed -i '/net.core.wmem_max=67108864/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_rmem=4096 87380 67108864/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_wmem=4096 65536 67108864/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fin_timeout=15/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_keepalive_time=600/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_window_scaling=1/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_low_latency=1/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.all.disable_ipv6=1/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6=1/d' /etc/sysctl.conf
  sed -i '/1.1.1.1 8.8.8.8/d' /etc/systemd/resolved.conf
  sed -i '/9.9.9.9/d' /etc/systemd/resolved.conf
  sed -i '/\* soft nofile 1048576/d' /etc/security/limits.conf
  sed -i '/\* hard nofile 1048576/d' /etc/security/limits.conf
  sysctl -p > /dev/null 2>&1
  systemctl restart systemd-resolved > /dev/null 2>&1
  clear
  echo "✅ Otimizações removidas com sucesso"
  echo "🔁 Reiniciando a VPS.."
  exit 0
  reboot
fi

echo
echo "=========================================="
echo " Processo finalizado"
echo "=========================================="
