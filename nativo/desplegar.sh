#!/usr/bin/env bash
# Copia a una VM solo lo que su instalador necesita — Estudiante B (Fase 1)
# Uso (en el Mac, desde la raíz del repo):  bash nativo/desplegar.sh db01|web01
# Destino: ~/paas/ en la VM (usuario zekken). Después, en la VM: sudo bash ~/paas/nativo/<vm>/instalar.sh
# La llave privada de la CA (ca/private/ca.key) NUNCA sale del Mac: a web01 solo va la llave de web01.
set -euo pipefail
cd "$(dirname "$0")/.."
VM="${1:?Uso: bash nativo/desplegar.sh db01|web01}"
USUARIO="${USUARIO:-zekken}"
case "$VM" in
  db01)  IP=10.10.10.10; ARCHIVOS=(nativo/db01 scripts/vm/ajustes-demo.sh) ;;
  web01) IP=10.10.10.20; ARCHIVOS=(nativo/web01 scripts/vm/ajustes-demo.sh ca/certs/ca.crt ca/certs/web01.crt ca/private/web01.key)
         for f in "${ARCHIVOS[@]:2}"; do
           [[ -f $f ]] || { echo "Falta $f: correr antes ca/scripts/ca.sh (ca, csr web01, firmar web01)"; exit 1; }
         done ;;
  *) echo "VM desconocida: $VM"; exit 1 ;;
esac
# -R conserva la ruta relativa (nativo/web01, ca/certs/...) bajo ~/paas/
rsync -aR --exclude '.DS_Store' "${ARCHIVOS[@]}" "$USUARIO@$IP:paas/"
# El rsync de macOS (openrsync) ignora --chmod: los permisos se cierran después, en la VM.
ssh "$USUARIO@$IP" 'chmod -R go-rwx ~/paas'
echo "Copiado a $USUARIO@$IP:~/paas/. Siguiente paso (pide sudo):"
echo "  ssh -t $USUARIO@$IP 'sudo bash ~/paas/nativo/$VM/instalar.sh'"
