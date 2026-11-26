#!/usr/bin/env bash
# Instala k3s de un nodo en k8s01 — Estudiante B (Fase 4). Ejecutar DENTRO de k8s01.
#   --node-ip / --flannel-iface: que k3s use la NIC de la LAN (la que tiene 10.10.10.40) y no la NAT.
#   El nombre se detecta por la IP: en ARM (ADR-0002) la NAT es enp0s8, al revés que en x86.
#   --write-kubeconfig-mode 644: kubectl sin sudo (aceptable en el examen; documentarlo)
set -euo pipefail

# TODO(B): fijar la versión para que la instalación sea reproducible, p. ej. INSTALL_K3S_VERSION=v1.xx.y+k3s1
LAN_IFACE=$(ip -o -4 addr show | awk '$4 ~ /^10\.10\.10\.40\// {print $2; exit}')
[[ -n $LAN_IFACE ]] || { echo "k8s01 no tiene 10.10.10.40: correr antes configurar-vm"; exit 1; }
export INSTALL_K3S_EXEC="--node-ip 10.10.10.40 --flannel-iface $LAN_IFACE --write-kubeconfig-mode 644"

curl -sfL https://get.k3s.io | sh -

kubectl get nodes -o wide
kubectl get pods -A
