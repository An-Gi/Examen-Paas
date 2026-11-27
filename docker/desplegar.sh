#!/usr/bin/env bash
# Copia docker/ a docker01 (o el script de prueba a un cliente) — Estudiantes A y B (Fase 3)
# Uso (en el Mac, desde la raíz del repo):
#   bash docker/desplegar.sh            -> docker01:~/paas/docker  (sin .env: ese vive solo en la VM)
#   bash docker/desplegar.sh web01      -> web01:~/paas/docker/probar-montajes.sh
set -euo pipefail
cd "$(dirname "$0")/.."
USUARIO="${USUARIO:-zekken}"
case "${1:-docker01}" in
  docker01) IP=10.10.10.30; ARCHIVOS=(docker) ;;
  web01)    IP=10.10.10.20; ARCHIVOS=(docker/probar-montajes.sh) ;;
  db01)     IP=10.10.10.10; ARCHIVOS=(docker/probar-montajes.sh) ;;
  *) echo "VM desconocida: $1"; exit 1 ;;
esac
# --exclude .env: nunca se sobrescribe el .env real de la VM con nada del Mac
rsync -aR --exclude '.env' --exclude '.DS_Store' "${ARCHIVOS[@]}" "$USUARIO@$IP:paas/"
ssh "$USUARIO@$IP" 'chmod -R go-rwx ~/paas'
echo "Copiado a $USUARIO@$IP:~/paas/"
