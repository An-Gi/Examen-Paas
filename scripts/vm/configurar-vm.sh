#!/usr/bin/env bash
# Da identidad propia a un clon: hostname, IP fija en la LAN, machine-id y llaves SSH únicas.
# Se instala en la plantilla como /usr/local/sbin/configurar-vm (ver preparar-plantilla.sh).
# Responsable: Estudiante B (Fase 0, paso 0.4.7)
#
# Uso (en la consola del clon): sudo configurar-vm <hostname> <ip>
#   Ejemplo: sudo configurar-vm web01 10.10.10.20
#   IFACE=<nic de la LAN> DOMINIO=paas.internal
#   Sin IFACE, la NIC de la LAN se detecta: es la que NO lleva la ruta por defecto (esa es la NAT).
#   Así sirve igual en x86 (NAT=enp0s3, LAN=enp0s8) y en ARM (NAT=enp0s8, LAN=la 2.ª NIC), ADR-0002.
#
# ¿Por qué regenerar machine-id y llaves SSH? Los clones heredan los de la plantilla:
#  - machine-id repetido: systemd-networkd usa ese valor para el DUID/IAID de DHCP, así que
#    los clones pueden pedir la misma IP, y journald/otros servicios confunden los nodos.
#  - llaves de host SSH repetidas: todas las VMs se "hacen pasar" por la misma máquina.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
NOMBRE="${1:?Uso: sudo configurar-vm <hostname> <ip>}"
IP="${2:?Uso: sudo configurar-vm <hostname> <ip>}"
# NIC de la LAN = la única interfaz física que no es "lo" ni la de la ruta por defecto (NAT).
detectar_lan() {
  local nat
  nat=$(ip -o route show default | awk '{print $5; exit}')
  ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' \
    | grep -Ev "^(lo|docker|br-|veth|cni|flannel|tap|tun)" | grep -vx "${nat:-ninguna}" | head -n1 || true   # sin || true, set -e cortaría antes del mensaje de error
}
IFACE="${IFACE:-$(detectar_lan)}"
[[ -n $IFACE ]] || { echo "No se encontró la NIC de la LAN: ¿falta el adaptador 2 (lan-paas)? Usar IFACE=..."; exit 1; }
DOMINIO="${DOMINIO:-paas.internal}"

[[ $IP =~ ^10\.10\.10\.[0-9]{1,3}$ ]] || { echo "La IP debe estar en 10.10.10.0/24"; exit 1; }

echo "== Hostname: $NOMBRE"
hostnamectl set-hostname "$NOMBRE"

echo "== machine-id nuevo"
rm -f /etc/machine-id
systemd-machine-id-setup
[[ -d /var/lib/dbus ]] && ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "== Llaves de host SSH nuevas"
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
systemctl restart ssh

echo "== NIC NAT por nombre (el instalador la ató a la MAC de la plantilla)"
# 00-installer-config.yaml usa "match: macaddress" + "set-name" con la MAC de la PLANTILLA. Los
# clones tienen otra MAC, así que esa regla no aplica ("Cannot find unique matching interface") y
# la NAT solo funcionaba por la regla genérica de dracut. Se reemplaza por una que use el nombre.
NAT_IFACE=$(ip -o route show default | awk '{print $5; exit}')
NAT_IFACE="${NAT_IFACE:-enp0s8}"
cat > /etc/netplan/00-installer-config.yaml <<EOF
# Generado por configurar-vm — adaptador NAT (salida a Internet), por nombre y no por MAC
network:
  version: 2
  ethernets:
    ${NAT_IFACE}:
      dhcp4: true
EOF
chmod 600 /etc/netplan/00-installer-config.yaml

echo "== IP fija $IP/24 en $IFACE (sin gateway: Internet sale por el adaptador NAT)"
cat > /etc/netplan/60-lan-paas.yaml <<EOF
# Generado por configurar-vm — LAN host-only del examen
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: false
      addresses: [${IP}/24]
      # Sin esto, netplan hace que systemd-networkd-wait-online espere DNS en esta NIC
      # (que no tiene: IP fija sin nameservers) y cada arranque se traba 2 min antes del login.
      optional: true
EOF
chmod 600 /etc/netplan/60-lan-paas.yaml
netplan apply

echo "== /etc/hosts (hasta que el DNS BIND9 de docker01 esté listo)"
sed -i "s/^127\.0\.1\.1.*/127.0.1.1 ${NOMBRE}.${DOMINIO} ${NOMBRE}/" /etc/hosts
sed -i '/# lan-paas$/d' /etc/hosts
cat >> /etc/hosts <<EOF
10.10.10.1  anfitrion.${DOMINIO} anfitrion # lan-paas
10.10.10.10 db01.${DOMINIO} db01 # lan-paas
10.10.10.20 web01.${DOMINIO} web01 www.${DOMINIO} # lan-paas
10.10.10.30 docker01.${DOMINIO} docker01 # lan-paas
10.10.10.40 k8s01.${DOMINIO} k8s01 # lan-paas
EOF

echo
echo "Listo:"
echo "  hostname   : $(hostname)"
echo "  machine-id : $(cat /etc/machine-id)"
ip -brief addr show "$IFACE"
