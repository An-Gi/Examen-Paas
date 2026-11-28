#!/usr/bin/env bash
# Copia el certificado de mail.paas.internal a docker/03-email/tls/ — Estudiante A (Fase 3)
# Se corre en el Mac donde vive la CA (el de B), después de:
#   bash ca/scripts/ca.sh csr mail && bash ca/scripts/ca.sh firmar mail
# Luego: bash docker/desplegar.sh   (copia tls/ a docker01; mail.key nunca va a Git: *.key en .gitignore)
set -euo pipefail
cd "$(dirname "$0")/../.."    # raíz del repo
DEST=docker/03-email/tls
for f in ca/certs/ca.crt ca/certs/mail.crt ca/private/mail.key; do
  [[ -f $f ]] || { echo "Falta $f: firmar antes el certificado (ca.sh csr mail + ca.sh firmar mail)"; exit 1; }
done
# El certificado tiene que ser de esta CA y corresponder a esta llave
openssl verify -CAfile ca/certs/ca.crt ca/certs/mail.crt
[[ $(openssl x509 -in ca/certs/mail.crt -noout -pubkey) == $(openssl pkey -in ca/private/mail.key -pubout) ]] \
  || { echo "mail.crt no corresponde a mail.key"; exit 1; }
install -m 644 ca/certs/ca.crt ca/certs/mail.crt "$DEST/"
install -m 600 ca/private/mail.key "$DEST/"
openssl x509 -in "$DEST/mail.crt" -noout -subject -enddate -ext subjectAltName
echo "Listo en $DEST/. Siguiente: bash docker/desplegar.sh"
