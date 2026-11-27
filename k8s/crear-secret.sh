#!/usr/bin/env bash
# Crea (o reemplaza) el Secret wordpress-db del namespace cms — Estudiante B (Fase 4)
# Uso (en k8s01):  bash ~/paas/k8s/crear-secret.sh
# Pide la contraseña de wp_k8s (la que se dio a nativo/db01/instalar.sh) y genera las salts de
# WordPress. Nada se escribe en Git ni queda en la línea de comandos (se vería en "ps").
# Recordar: un Secret NO está cifrado; en etcd/SQLite de k3s es base64. Lo protege el acceso a la API.
set -euo pipefail
# Por "ssh k8s01 'comando'" no se lee ~/.bashrc, y sin KUBECONFIG kubectl (el de k3s) intenta
# /etc/rancher/k3s/k3s.yaml, que es solo de root (600, instalar-k3s.sh).
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
# El namespace se crea con el mismo manifiesto que usa "kubectl apply -k" (si se creara con
# "kubectl create ns", el apply posterior avisa que le falta la anotación last-applied-configuration).
kubectl apply -f "$(dirname "$0")/manifests/00-namespace.yaml" >/dev/null
read -rsp "Contraseña de MySQL para 'wp_k8s'@'10.10.10.40': " p; echo
[[ -n $p ]] || { echo "No puede quedar vacía"; exit 1; }
umask 077
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
{
  printf 'WORDPRESS_DB_PASSWORD=%s\n' "$p"
  # Salts compartidas por todas las réplicas (sin esto cada pod generaría las suyas)
  for k in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    printf 'WORDPRESS_%s=%s\n' "$k" "$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-48)"
  done
} > "$tmp"
kubectl -n cms create secret generic wordpress-db --from-env-file="$tmp" --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl -n cms get secret wordpress-db -o jsonpath='{.data}' | tr ',' '\n' | cut -d: -f1 | tr -d '{"'
echo
echo "Si el Deployment ya existía: kubectl -n cms rollout restart deploy/wordpress"
