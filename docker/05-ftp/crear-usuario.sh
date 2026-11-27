#!/usr/bin/env bash
# Crea (o actualiza la contraseña de) el usuario virtual FTP — Estudiante B (Fase 3)
# Uso (en docker01, con el servicio arriba):  bash ~/paas/docker/05-ftp/crear-usuario.sh
# Toma FTP_USER y FTP_PASSWORD de docker/.env: la contraseña no se escribe ni se muestra.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
: "${FTP_USER:?falta en .env}" "${FTP_PASSWORD:?falta en .env}"

# UID/GID 1000: dueño de los archivos dentro del volumen. -d encierra al usuario en su carpeta
# (chroot); --createhomedir (bandera de la imagen) la crea en el primer login.
if docker exec ftp pure-pw show "$FTP_USER" >/dev/null 2>&1; then
  printf '%s\n%s\n' "$FTP_PASSWORD" "$FTP_PASSWORD" | docker exec -i ftp pure-pw passwd "$FTP_USER" -m >/dev/null
  echo "Contraseña de $FTP_USER actualizada"
else
  printf '%s\n%s\n' "$FTP_PASSWORD" "$FTP_PASSWORD" \
    | docker exec -i ftp pure-pw useradd "$FTP_USER" -u 1000 -g 1000 -d "/home/ftpusers/$FTP_USER" -m >/dev/null
  echo "Usuario $FTP_USER creado"
fi
docker exec ftp pure-pw list
