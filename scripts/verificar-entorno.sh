#!/usr/bin/env bash
# Verifica que el equipo de cada estudiante tenga las herramientas necesarias.
# Uso: bash scripts/verificar-entorno.sh [a|b|todos]     (o: make verificar ROL=a)
# Sale con código 1 si falta alguna herramienta obligatoria para el rol indicado.
set -uo pipefail

ROL="${1:-todos}"
faltan=0

# chequear <comando> <cómo obtener la versión> <obligatorio|opcional>
chequear() {
  local cmd=$1 version_cmd=$2 nivel=$3
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✅ %-16s %s\n" "$cmd" "$(eval "$version_cmd" 2>/dev/null | head -n1)"
  elif [[ $nivel == obligatorio ]]; then
    printf "  ❌ %-16s FALTA (obligatorio)\n" "$cmd"
    faltan=$((faltan + 1))
  else
    printf "  ⚠️  %-16s no instalado (opcional)\n" "$cmd"
  fi
}

# nivel <rol que lo necesita: a|b|ambos>  -> obligatorio u opcional según $ROL
nivel() {
  [[ $1 == ambos || $ROL == todos || $1 == "$ROL" ]] && echo obligatorio || echo opcional
}

echo "== Comunes"
chequear git        "git --version"                obligatorio
chequear make       "make --version"               obligatorio
chequear python3    "python3 --version"            obligatorio
chequear ssh        "ssh -V 2>&1"                  obligatorio
chequear pre-commit "pre-commit --version"         obligatorio

echo "== Virtualización"
chequear VBoxManage "VBoxManage --version"         "$(nivel ambos)"
if [[ -r /proc/cpuinfo ]]; then
  if grep -Eqc '(vmx|svm)' /proc/cpuinfo; then
    echo "  ✅ VT-x/AMD-V      disponible"
  else
    echo "  ⚠️  VT-x/AMD-V      no detectado (revisar BIOS/UEFI; en WSL2 esto es normal)"
  fi
fi

echo "== Contenedores"
chequear docker     "docker --version"             "$(nivel ambos)"
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    printf "  ✅ %-16s %s\n" "docker compose" "$(docker compose version --short)"
  else
    echo "  ❌ docker compose   FALTA el plugin Compose v2"; faltan=$((faltan + 1))
  fi
fi

echo "== IaC (Estudiante A)"
chequear terraform        "terraform version"            "$(nivel a)"
chequear aws              "aws --version"                "$(nivel a)"
chequear ansible-playbook "ansible-playbook --version"   "$(nivel a)"

echo "== Documentación (Estudiante B)"
chequear pandoc     "pandoc --version"             "$(nivel b)"
chequear xelatex    "xelatex --version"            "$(nivel b)"
chequear npx        "npx --version"                opcional

echo "== Calidad (opcionales)"
chequear yamllint     "yamllint --version"         opcional
chequear ansible-lint "ansible-lint --version"     opcional
chequear gitleaks     "gitleaks version"           opcional

if [[ -r /proc/meminfo ]]; then
  ram_gb=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
  echo "== RAM total: ${ram_gb} GB (la anfitriona necesita >= 16 GB)"
fi

echo
if (( faltan > 0 )); then
  echo "Faltan $faltan herramienta(s) obligatoria(s) para el rol '$ROL'."
  exit 1
fi
echo "Entorno listo para el rol '$ROL'."
