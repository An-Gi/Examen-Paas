#!/usr/bin/env bash
# Docker Engine + Compose en docker01 — Estudiantes A y B (Fase 3, una sola vez)
# Uso (en docker01):  sudo bash ~/paas/docker/instalar-docker.sh
# Repositorio oficial de Docker (https://docs.docker.com/engine/install/ubuntu/): ya publica
# paquetes para Ubuntu 26.04 "resolute" en arm64. Es idempotente.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
USUARIO="${SUDO_USER:-zekken}"
. /etc/os-release

echo "== 1. Repositorio oficial de Docker (firmado con su llave GPG)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<SRC
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
SRC

echo "== 2. Paquetes"
apt-get update -q
apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "== 3. Rotación de logs de los contenedores (si no, crecen sin límite en el disco de 24 GB)"
install -d /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
systemctl enable --now docker
systemctl restart docker

echo "== 4. $USUARIO en el grupo docker (equivale a root en esta VM: solo para quien administra)"
usermod -aG docker "$USUARIO"

docker version --format 'Docker {{.Server.Version}} ({{.Server.Arch}})'
docker compose version
echo "Listo. Cerrar la sesión SSH y volver a entrar para que el grupo docker se aplique."
