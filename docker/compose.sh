#!/usr/bin/env bash
# Atajo para operar cada servicio con el .env común de docker/.
# Uso:
#   ./compose.sh <carpeta> <comando de compose...>
#   ./compose.sh 01-dns-bind9 up -d
#   ./compose.sh 04-owncloud logs -f
#   ./compose.sh todos up -d          # los 6 servicios calificables
#   ./compose.sh todos ps
set -euo pipefail
cd "$(dirname "$0")"

[[ -f .env ]] || { echo "Falta docker/.env  ->  cp .env.example .env"; exit 1; }

SERVICIOS=(01-dns-bind9 02-ldap 03-email 04-owncloud 05-ftp 06-smb)
objetivo="${1:?Uso: ./compose.sh <carpeta|todos> <comando...>}"
shift

if [[ $objetivo == todos ]]; then
  lista=("${SERVICIOS[@]}")
else
  objetivo="${objetivo%/}"
  [[ -f "$objetivo/docker-compose.yml" ]] || { echo "No existe $objetivo/docker-compose.yml"; exit 1; }
  lista=("$objetivo")
fi

for s in "${lista[@]}"; do
  echo "==> $s: docker compose $*"
  docker compose --env-file .env --project-directory "$s" -f "$s/docker-compose.yml" "$@"
done
