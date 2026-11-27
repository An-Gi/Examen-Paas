#!/usr/bin/env bash
# Crea o completa docker/.env con contraseñas aleatorias — Estudiantes A y B (Fase 3)
# Uso (en docker01):  bash ~/paas/docker/generar-env.sh
# - Si .env no existe, lo crea desde .env.example.
# - Cada valor "cambiar" se reemplaza por una contraseña aleatoria de 24 caracteres.
# - Las variables nuevas de .env.example se agregan; las existentes NO se tocan.
# No imprime ninguna contraseña. Para pasarlas al gestor: ver .env en la VM (cat ~/paas/docker/.env).
set -euo pipefail
cd "$(dirname "$0")"
umask 077
[[ -f .env ]] || : > .env
chmod 600 .env
nuevas=0
while IFS= read -r linea; do
  [[ $linea =~ ^([A-Z0-9_]+)=([^[:space:]#]*) ]] || continue
  var=${BASH_REMATCH[1]} valor=${BASH_REMATCH[2]}
  grep -q "^${var}=" .env && continue
  # Alfanumérica: evita comillas y símbolos que romperían YAML, SQL o la línea de comandos.
  # (No usar "tr </dev/urandom | head": con pipefail, el SIGPIPE de tr corta el script en silencio.)
  if [[ $valor == cambiar ]]; then
    valor=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-24)
    [[ ${#valor} -eq 24 ]] || { echo "No se pudo generar la contraseña de $var"; exit 1; }
  fi
  printf '%s=%s\n' "$var" "$valor" >> .env
  nuevas=$((nuevas + 1))
done < .env.example
echo "docker/.env: $nuevas variable(s) nueva(s); $(grep -c '=' .env) en total. Permisos: $(stat -c %a .env)"
grep -q '=cambiar$' .env && echo "AVISO: quedan valores 'cambiar' en .env" || true
