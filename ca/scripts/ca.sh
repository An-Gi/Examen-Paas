#!/usr/bin/env bash
# Entidad certificadora propia con OpenSSL — Estudiante B (Fase 1)
# Uso (desde cualquier lugar):
#   bash ca/scripts/ca.sh init               estructura de la base de datos de la CA
#   bash ca/scripts/ca.sh ca                 llave y certificado raíz
#   bash ca/scripts/ca.sh csr <nombre>       llave + CSR usando ca/<nombre>.cnf
#   bash ca/scripts/ca.sh firmar <nombre>    firma el CSR y verifica
# Cada paso debe quedar documentado en docs/documentacion.md §4 (comando + explicación + salida).
set -euo pipefail
cd "$(dirname "$0")/.."    # carpeta ca/

inicializar() {
  mkdir -p private certs newcerts csr
  chmod 700 private
  touch index.txt
  [[ -f serial ]] || echo 1000 > serial
  echo "Estructura de la CA lista en $(pwd)"
}

crear_ca() {
  # TODO(B) 1: llave privada de la CA, protegida con passphrase -> private/ca.key
  #            pista: openssl genpkey -algorithm RSA ... -aes256
  # TODO(B) 2: certificado raíz autofirmado (10 años) con [req] y [ext_ca] de openssl-ca.cnf -> certs/ca.crt
  #            pista: openssl req -config openssl-ca.cnf -x509 -new ...
  # TODO(B) 3: mostrarlo: openssl x509 -in certs/ca.crt -noout -text
  echo "TODO(B): implementar crear_ca"; return 1
}

csr_servidor() {
  local nombre=$1
  [[ -f "$nombre.cnf" ]] || { echo "Falta ca/$nombre.cnf"; return 1; }
  # TODO(B) 1: llave privada del servidor SIN passphrase (Apache arranca sin intervención) -> private/$nombre.key
  # TODO(B) 2: CSR con el SAN de $nombre.cnf -> csr/$nombre.csr
  # TODO(B) 3: revisar el CSR: openssl req -in csr/$nombre.csr -noout -text
  echo "TODO(B): implementar csr_servidor $nombre"; return 1
}

firmar() {
  local nombre=$1
  # TODO(B) 1: firmar con la CA usando -extensions ext_servidor -> certs/$nombre.crt
  #            pista: openssl ca -config openssl-ca.cnf -in csr/$nombre.csr -out certs/$nombre.crt ...
  # TODO(B) 2: openssl verify -CAfile certs/ca.crt certs/$nombre.crt
  # TODO(B) 3: openssl x509 -in certs/$nombre.crt -noout -ext subjectAltName
  echo "TODO(B): implementar firmar $nombre"; return 1
}

case "${1:-}" in
  init)   inicializar ;;
  ca)     crear_ca ;;
  csr)    csr_servidor "${2:?Uso: ca.sh csr <nombre>}" ;;
  firmar) firmar "${2:?Uso: ca.sh firmar <nombre>}" ;;
  *)      sed -n '2,8p' "$0"; exit 1 ;;
esac
