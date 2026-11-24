#!/usr/bin/env bash
# Crea la red host-only 10.10.10.0/24 en VirtualBox. Ejecutar en la MÁQUINA ANFITRIONA.
# Responsable: Estudiante B (Fase 0, paso 0.4.1)
#
# Uso: bash scripts/vm/preparar-red-virtualbox.sh
#   IF_NAME=vboxnet0 (Linux) | IF_NAME="VirtualBox Host-Only Ethernet Adapter" (Windows/Git Bash)
set -euo pipefail

IF_NAME="${IF_NAME:-vboxnet0}"
HOST_IP="10.10.10.1"
MASK="255.255.255.0"

command -v VBoxManage >/dev/null || { echo "VBoxManage no está en el PATH"; exit 1; }

case "$(uname -s)" in
  Darwin)
    # VirtualBox 7 en macOS usa "hostonlynet" en vez de "hostonlyif".
    echo "macOS detectado. Crear la red manualmente:"
    echo "  VBoxManage hostonlynet add --name lan-paas --netmask $MASK --lower-ip 10.10.10.100 --upper-ip 10.10.10.150"
    echo "y en las VMs usar '--nic2 hostonlynet --host-only-net2 lan-paas' (ajustar clonar-vms.sh)."
    exit 0
    ;;
  Linux)
    # VirtualBox >= 6.1.28 restringe las redes host-only a 192.168.56.0/21 salvo que se permita otro rango.
    if ! grep -qs "10.10.10.0/24" /etc/vbox/networks.conf; then
      echo "Falta permitir el rango en /etc/vbox/networks.conf. Ejecutar y volver a correr este script:"
      echo "  sudo mkdir -p /etc/vbox && echo '* 10.10.10.0/24' | sudo tee -a /etc/vbox/networks.conf"
      exit 1
    fi
    ;;
esac

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
