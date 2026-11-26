#!/usr/bin/env bash
# Crea la red host-only 10.10.10.0/24 en VirtualBox. Ejecutar en la MÁQUINA ANFITRIONA.
# Responsable: Estudiante B (Fase 0, paso 0.4.1)
#
# Uso: bash scripts/vm/preparar-red-virtualbox.sh
#   macOS (anfitriona elegida, ADR-0002): crea la red "hostonlynet" NET_NAME=lan-paas
#   Linux:   IF_NAME=vboxnet0
#   Windows: IF_NAME="VirtualBox Host-Only Ethernet Adapter" (Git Bash)
set -euo pipefail

IF_NAME="${IF_NAME:-vboxnet0}"
NET_NAME="${NET_NAME:-lan-paas}"
HOST_IP="10.10.10.1"
MASK="255.255.255.0"

command -v VBoxManage >/dev/null || { echo "VBoxManage no está en el PATH"; exit 1; }

if [[ "$(uname -s)" == Darwin ]]; then
  # VirtualBox 7 en macOS no tiene interfaces host-only (vboxnet0): usa redes "hostonlynet"
  # sobre vmnet de Apple. vmnet le da al ANFITRIÓN la "lower-ip" (comprobado: con .100 el Mac
  # quedaba en 10.10.10.100) y sirve DHCP en lower+1..upper. Con .1-.9 el anfitrión queda en
  # 10.10.10.1 (convenciones.md), el DHCP de vmnet en .2-.9 (ninguna VM lo usa: IPs fijas) y
  # el rango .100-.150 queda libre para el DHCP de respaldo.
  if VBoxManage list hostonlynets | grep -Eq "^Name:[[:space:]]+${NET_NAME}$"; then
    echo "La red '${NET_NAME}' ya existe; se asegura el rango .1-.9 (aplica al reiniciar las VMs)."
    VBoxManage hostonlynet modify --name "$NET_NAME" --lower-ip 10.10.10.1 --upper-ip 10.10.10.9
  else
    echo "Creando la red hostonlynet '${NET_NAME}'..."
    VBoxManage hostonlynet add --name "$NET_NAME" --netmask "$MASK" \
      --lower-ip 10.10.10.1 --upper-ip 10.10.10.9 --enable
  fi
  VBoxManage list hostonlynets | grep -A6 -E "^Name:[[:space:]]+${NET_NAME}$"
  echo "En las VMs: --nic2 hostonlynet --host-only-net2 ${NET_NAME} (lo hace clonar-vms.sh)."
  echo "La interfaz del anfitrión (bridgeN con ${HOST_IP}) aparece al arrancar la primera VM."
  exit 0
fi

if [[ "$(uname -s)" == Linux ]]; then
  # VirtualBox >= 6.1.28 restringe las redes host-only a 192.168.56.0/21 salvo que se permita otro rango.
  if ! grep -qs "10.10.10.0/24" /etc/vbox/networks.conf; then
    echo "Falta permitir el rango en /etc/vbox/networks.conf. Ejecutar y volver a correr este script:"
    echo "  sudo mkdir -p /etc/vbox && echo '* 10.10.10.0/24' | sudo tee -a /etc/vbox/networks.conf"
    exit 1
  fi
fi

if ! VBoxManage list hostonlyifs | grep -Eq "^Name:[[:space:]]+${IF_NAME}$"; then
  echo "Creando interfaz host-only..."
  VBoxManage hostonlyif create
fi

VBoxManage hostonlyif ipconfig "$IF_NAME" --ip "$HOST_IP" --netmask "$MASK"

# IPs fijas en la LAN: el DHCP de VirtualBox se apaga para que no interfiera
# (y para poder probar el DHCP propio de respaldo si hiciera falta).
VBoxManage dhcpserver remove --interface="$IF_NAME" 2>/dev/null || true

echo "Red lista:"
VBoxManage list hostonlyifs | grep -A5 -E "^Name:[[:space:]]+${IF_NAME}$" | grep -E "Name|IPAddress|NetworkMask|DHCP"
