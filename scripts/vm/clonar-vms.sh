#!/usr/bin/env bash
# Clona la plantilla en las 4 VMs del examen (clones enlazados: ahorran disco).
# Ejecutar en la MÁQUINA ANFITRIONA. Responsable: Estudiante B (Fase 0, paso 0.4.6)
#
# Uso: bash scripts/vm/clonar-vms.sh
#   PLANTILLA=ubuntu2404-plantilla SNAPSHOT=base IF_NAME=vboxnet0
set -euo pipefail

PLANTILLA="${PLANTILLA:-ubuntu2404-plantilla}"
SNAPSHOT="${SNAPSHOT:-base}"
IF_NAME="${IF_NAME:-vboxnet0}"

# nombre:RAM_MB:CPUs  (fuente: docs/convenciones.md)
VMS=(
  "db01:1024:1"
  "web01:2048:1"
  "docker01:4096:2"
  "k8s01:4096:2"
)

VBoxManage snapshot "$PLANTILLA" list >/dev/null 2>&1 \
  || { echo "La plantilla '$PLANTILLA' no tiene snapshots; tomar '$SNAPSHOT' primero."; exit 1; }

for entrada in "${VMS[@]}"; do
  IFS=: read -r nombre ram cpus <<<"$entrada"

  if VBoxManage showvminfo "$nombre" >/dev/null 2>&1; then
    echo "· $nombre ya existe, se omite"
    continue
  fi

  echo "· Clonando $nombre (${ram} MB, ${cpus} CPU)"
  # VirtualBox regenera las MAC por defecto; machine-id y llaves SSH los regenera configurar-vm.
  VBoxManage clonevm "$PLANTILLA" --name "$nombre" --snapshot "$SNAPSHOT" \
    --options=Link --mode=machine --register

  VBoxManage modifyvm "$nombre" --memory "$ram" --cpus "$cpus" \
    --nic1 nat --nic2 hostonly --hostonlyadapter2 "$IF_NAME"
done

cat <<EOF

Clones listos. En la consola de cada VM ejecutar:
  sudo configurar-vm db01     10.10.10.10
  sudo configurar-vm web01    10.10.10.20
  sudo configurar-vm docker01 10.10.10.30
  sudo configurar-vm k8s01    10.10.10.40
EOF
