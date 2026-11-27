#!/usr/bin/env bash
# Instala k3s de un nodo en k8s01 — Estudiante B (Fase 4). Ejecutar DENTRO de k8s01:
#   sudo bash ~/paas/k8s/instalar-k3s.sh
#   --node-ip / --flannel-iface: que k3s use la NIC de la LAN (la que tiene 10.10.10.40) y no la NAT.
#   El nombre se detecta por la IP: en ARM (ADR-0002) la NAT es enp0s8, al revés que en x86.
#   El kubeconfig queda 600 (solo root) y se copia a ~/.kube/config del usuario: kubectl sin sudo
#   sin que cualquier usuario de la VM pueda administrar el clúster.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
USUARIO="${SUDO_USER:-zekken}"
# Versión fija: la instalación es reproducible y no cambia entre el ensayo y la defensa
export INSTALL_K3S_VERSION="${INSTALL_K3S_VERSION:-v1.37.2+k3s1}"

LAN_IFACE=$(ip -o -4 addr show | awk '$4 ~ /^10\.10\.10\.40\// {print $2; exit}')
[[ -n $LAN_IFACE ]] || { echo "k8s01 no tiene 10.10.10.40: correr antes configurar-vm"; exit 1; }
export INSTALL_K3S_EXEC="--node-ip 10.10.10.40 --flannel-iface $LAN_IFACE --write-kubeconfig-mode 600"

# Instalador oficial de k3s (descarga el binario de esa versión y verifica su sha256)
curl -sfL https://get.k3s.io | sh -

echo "== kubeconfig para $USUARIO"
install -d -m 700 -o "$USUARIO" -g "$USUARIO" "/home/$USUARIO/.kube"
install -m 600 -o "$USUARIO" -g "$USUARIO" /etc/rancher/k3s/k3s.yaml "/home/$USUARIO/.kube/config"
grep -q 'KUBECONFIG' "/home/$USUARIO/.bashrc" || echo 'export KUBECONFIG=$HOME/.kube/config' >> "/home/$USUARIO/.bashrc"

echo "== Esperando al nodo"
until kubectl get nodes 2>/dev/null | grep -q ' Ready'; do sleep 3; done
kubectl get nodes -o wide
kubectl -n kube-system rollout status deploy/coredns --timeout=180s
kubectl get pods -A
