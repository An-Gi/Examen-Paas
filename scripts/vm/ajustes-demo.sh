#!/usr/bin/env bash
# Estabilidad de las VMs para la demo — Estudiante B (Fase 1)
# Uso (en cada VM): sudo bash ajustes-demo.sh      Es idempotente.
#
# 1. Swap de 1 GB: con 1-1,5 GB de RAM, un pico de memoria hace que el kernel mate procesos
#    (pasó con MySQL en db01). Con swap el sistema se pone lento, pero no pierde servicios.
# 2. Sin actualizaciones automáticas: unattended-upgrades corre una vez al día por su cuenta.
#    Durante la defensa eso significa CPU, RAM y el lock de apt ocupados en el peor momento.
#    Se actualiza a mano (apt update && apt upgrade) antes de cada snapshot.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

echo "== 1. Swap"
if swapon --show --noheadings | grep -q .; then
  swapon --show
else
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Usar la swap solo cuando de verdad falte RAM (el valor por defecto, 60, la usa antes)
  echo 'vm.swappiness = 10' > /etc/sysctl.d/90-paas-swap.conf
  sysctl -q -p /etc/sysctl.d/90-paas-swap.conf
  swapon --show
fi

echo "== 2. Actualizaciones automáticas"
# Si una está corriendo, se espera a que termine: cortarla a mitad de dpkg deja paquetes rotos.
while pgrep -f 'apt.systemd.daily|unattended-upgrade$' >/dev/null; do
  echo "   Hay una actualización automática en curso; esperando 15 s..."; sleep 15
done
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl disable --now unattended-upgrades.service 2>/dev/null || true
# update-notifier (apt-check) calcula actualizaciones en CADA login por SSH (mensaje del día) y usa
# ~100 MB: en db01 se juntó con MySQL y el upgrade automático. Se apagan esos scripts del motd.
for f in /etc/update-motd.d/90-updates-available /etc/update-motd.d/91-release-upgrade; do
  [[ -e $f ]] && chmod -x "$f"
done
cat > /etc/apt/apt.conf.d/99-paas-sin-automaticas <<'CONF'
// Generado por ajustes-demo.sh: nada de apt en segundo plano durante la demo
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
CONF
systemctl list-timers 'apt-*' --all --no-pager | head -4
dpkg --audit && echo "dpkg consistente"
free -m
