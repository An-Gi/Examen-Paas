#!/usr/bin/env bash
# Prepara la VM plantilla (Ubuntu Server 24.04) antes de tomar el snapshot "base".
# Ejecutar DENTRO de la plantilla: sudo bash preparar-plantilla.sh llaves.pub
# Responsable: Estudiante B (Fase 0, paso 0.4.5)
#
# llaves.pub = llaves públicas SSH de A y B, una por línea.
# Requiere configurar-vm.sh en el mismo directorio (se instala como /usr/local/sbin/configurar-vm).
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
LLAVES="${1:?Uso: sudo bash preparar-plantilla.sh llaves.pub}"
USUARIO="${SUDO_USER:-paas}"
DIR_SCRIPT="$(cd "$(dirname "$0")" && pwd)"

echo "== Paquetes base"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y full-upgrade
apt-get install -y openssh-server curl wget ca-certificates gnupg vim git jq htop \
  net-tools dnsutils iputils-ping traceroute tcpdump nmap bash-completion

echo "== Zona horaria"
timedatectl set-timezone America/Costa_Rica

echo "== Disco: extender el LV raíz si el instalador dejó espacio libre"
if command -v vgs >/dev/null && [[ "$(vgs --noheadings -o vg_free --units g ubuntu-vg 2>/dev/null | tr -dc '0-9.')" != "0" ]]; then
  lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv || true
fi
df -h /

echo "== Llaves SSH de A y B para '$USUARIO'"
install -d -m 700 -o "$USUARIO" -g "$USUARIO" "/home/$USUARIO/.ssh"
cat "$LLAVES" >> "/home/$USUARIO/.ssh/authorized_keys"
sort -u -o "/home/$USUARIO/.ssh/authorized_keys" "/home/$USUARIO/.ssh/authorized_keys"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.ssh/authorized_keys"
chmod 600 "/home/$USUARIO/.ssh/authorized_keys"

echo "== SSH solo con llave (las llaves ya están instaladas)"
cat > /etc/ssh/sshd_config.d/10-paas.conf <<'EOF'
# Examen PaaS: acceso solo por llave pública
PasswordAuthentication no
PermitRootLogin no
EOF
sshd -t && systemctl restart ssh

echo "== Script de configuración para los clones"
install -m 755 "$DIR_SCRIPT/configurar-vm.sh" /usr/local/sbin/configurar-vm

echo "== cloud-init desactivado (evita que reescriba hostname o red en los clones)"
touch /etc/cloud/cloud-init.disabled

echo "== Limpieza para clonar"
apt-get -y autoremove && apt-get clean
truncate -s 0 /etc/machine-id          # cada clon genera el suyo (configurar-vm lo fuerza)
rm -f /var/lib/dbus/machine-id
# La IP temporal 10.10.10.5 (puesta con `ip addr add`) no es persistente: desaparece al apagar.

echo
echo "Plantilla lista. Siguiente: 'sudo poweroff' y en la anfitriona:"
echo "  VBoxManage snapshot ubuntu2404-plantilla take base"
