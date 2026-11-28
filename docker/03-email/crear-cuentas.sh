#!/usr/bin/env bash
# Crea las cuentas de correo de la demo — Estudiante A (Fase 3)
# Uso (en docker01, ANTES del primer up):  bash ~/paas/docker/03-email/crear-cuentas.sh
#                                          ./compose.sh 03-email up -d
# docker-mailserver no arranca Dovecot sin al menos una cuenta: por eso se crean antes, con un
# contenedor temporal (compose run) que solo escribe en 03-email/dms/config/ (hashes, ignorado por Git).
# Las contraseñas salen de docker/.env (MAIL_USUARIO1_PASSWORD, MAIL_USUARIO2_PASSWORD); no se imprimen.
# Idempotente: una cuenta que ya existe no se toca. Con el servicio ya arriba, los cambios se aplican solos.
set -euo pipefail
cd "$(dirname "$0")/.."    # carpeta docker/
set -a; source .env; set +a
DOMINIO=${DOMINIO_LAN:-paas.internal}
CUENTAS=03-email/dms/config/postfix-accounts.cf
ALIAS=03-email/dms/config/postfix-virtual.cf

setup() { docker compose --env-file .env -f 03-email/docker-compose.yml run --rm --no-deps -T mailserver setup "$@"; }

for n in 1 2; do
  cuenta="usuario$n@$DOMINIO"
  var="MAIL_USUARIO${n}_PASSWORD"
  if grep -qs "^$cuenta|" "$CUENTAS"; then
    echo "ya existe: $cuenta"
  else
    setup email add "$cuenta" "${!var:?definir $var en docker/.env}" >/dev/null
    echo "creada:    $cuenta"
  fi
done

# postmaster@ es obligatorio por RFC 5321: alias hacia usuario1
if ! grep -qs "^postmaster@$DOMINIO " "$ALIAS"; then
  setup alias add "postmaster@$DOMINIO" "usuario1@$DOMINIO" >/dev/null
  echo "creado:    alias postmaster@$DOMINIO -> usuario1@$DOMINIO"
fi
echo "Cuentas en $CUENTAS: $(cut -d'|' -f1 "$CUENTAS" | tr '\n' ' ')"
