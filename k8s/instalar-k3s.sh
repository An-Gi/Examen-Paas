#!/usr/bin/env bash
# Instala k3s de un nodo en k8s01 — Estudiante B (Fase 4). Ejecutar DENTRO de k8s01.
#   --node-ip / --flannel-iface: que k3s use la NIC de la LAN (enp0s8) y no la NAT (enp0s3)
#   --write-kubeconfig-mode 644: kubectl sin sudo (aceptable en el examen; documentarlo)
set -euo pipefail

# TODO(B): fijar la versión para que la instalación sea reproducible, p. ej. INSTALL_K3S_VERSION=v1.xx.y+k3s1
export INSTALL_K3S_EXEC="--node-ip 10.10.10.40 --flannel-iface enp0s8 --write-kubeconfig-mode 644"

curl -sfL https://get.k3s.io | sh -

kubectl get nodes -o wide
kubectl get pods -A
