#!/usr/bin/env bash
# Prueba de los protocolos del FileServer desde un cliente Linux — Estudiante B (Fase 3)
# El enunciado pide usarlos "a través de un punto de montaje en un cliente Linux en cualquiera de
# los otros servidores". Uso (en web01 o db01, NO en docker01):
#   sudo bash ~/paas/docker/probar-montajes.sh ftp|smb|todos
# Pide usuario y contraseña de cada servicio (los de docker/.env, guardados en el gestor).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
SERVIDOR="${SERVIDOR:-10.10.10.30}"
QUE="${1:-todos}"

pedir() { read -rp "$1 usuario: " u; read -rsp "$1 contraseña: " p; echo; }

probar() {   # probar <punto de montaje>
  local m=$1 f="prueba-$(hostname)-$(date +%H%M%S).txt"
  echo "hola desde $(hostname) por $(basename "$m")" > "$m/$f"
  ls -l "$m"
  grep -q "hola desde $(hostname)" "$m/$f" && echo "OK: escrito y leído $m/$f"
}

if [[ $QUE == ftp || $QUE == todos ]]; then
  echo "== FTP: rclone mount (FUSE) en /mnt/ftp"
  # curlftpfs (el cliente clásico) NO sirve en Ubuntu 26.04: con libcurl 8.18 falla con
  # "Error setting curl:" antes de conectarse. rclone hace lo mismo (FTP como sistema de archivos).
  command -v rclone >/dev/null || apt-get install -y -q rclone fuse3
  mkdir -p /mnt/ftp
  mountpoint -q /mnt/ftp && umount /mnt/ftp
  [[ -f /root/.netrc ]] && sed -i "/^machine $SERVIDOR /d" /root/.netrc   # resto del intento con curlftpfs
  pedir FTP
  # rclone vuelve a conectarse cuando lo necesita: la credencial queda en su configuración (600),
  # "ofuscada" con rclone obscure. Ojo: ofuscar NO es cifrar; lo que la protege son los permisos.
  # No se pasa en la línea de comandos porque se vería en "ps" mientras dure el montaje.
  install -d -m 700 /root/.config/rclone
  conf=/root/.config/rclone/rclone.conf
  touch "$conf" && chmod 600 "$conf"
  awk '/^\[/{skip=($0=="[paas-ftp]")} !skip' "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"
  printf '[paas-ftp]\ntype = ftp\nhost = %s\nuser = %s\npass = %s\n' \
    "$SERVIDOR" "$u" "$(printf '%s' "$p" | rclone obscure -)" >> "$conf"
  chmod 600 "$conf"
  # --vfs-cache-mode writes: FTP no permite escribir a mitad de un archivo; rclone arma el archivo
  # en un caché local y lo sube completo al cerrarlo.
  rclone mount paas-ftp: /mnt/ftp --daemon --allow-other --vfs-cache-mode writes --uid 1000 --gid 1000
  for _ in 1 2 3 4 5; do mountpoint -q /mnt/ftp && break; sleep 1; done
  mount | grep /mnt/ftp
  probar /mnt/ftp
fi

if [[ $QUE == smb || $QUE == todos ]]; then
  echo "== SMB: cifs (kernel) en /mnt/smb"
  command -v mount.cifs >/dev/null || apt-get install -y -q cifs-utils
  mkdir -p /mnt/smb
  mountpoint -q /mnt/smb && umount /mnt/smb
  pedir SMB
  cred=$(mktemp); chmod 600 "$cred"
  printf 'username=%s\npassword=%s\n' "$u" "$p" > "$cred"
  # vers=3.1.1: el dialecto más nuevo (cifrado y firma); uid/gid: los archivos aparecen del usuario
  mount -t cifs "//$SERVIDOR/compartido" /mnt/smb -o "credentials=$cred,vers=3.1.1,uid=1000,gid=1000"
  rm -f "$cred"
  mount | grep /mnt/smb
  probar /mnt/smb
fi
echo
echo "Montajes activos (desmontar con: sudo umount /mnt/ftp /mnt/smb):"
findmnt -t fuse.rclone,cifs || true
