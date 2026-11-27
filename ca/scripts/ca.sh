#!/usr/bin/env bash
# Entidad certificadora propia con OpenSSL — Estudiante B (Fase 1)
# Uso (desde cualquier lugar):
#   bash ca/scripts/ca.sh init               estructura de la base de datos de la CA
#   bash ca/scripts/ca.sh ca                 llave y certificado raíz
#   bash ca/scripts/ca.sh csr <nombre>       llave + CSR usando ca/<nombre>.cnf
#   bash ca/scripts/ca.sh firmar <nombre>    firma el CSR y verifica
# Cada paso debe quedar documentado en docs/documentacion.md §4 (comando + explicación + salida).
#
# La passphrase de la CA se pide por teclado (openssl la lee del terminal). Solo para pruebas
# automáticas se puede pasar en la variable CA_PASS; nunca usarla con la CA real.
set -euo pipefail
cd "$(dirname "$0")/.."    # carpeta ca/

CNF=openssl-ca.cnf
# El enunciado pide OpenSSL. /usr/bin/openssl de macOS es LibreSSL: no entiende varias opciones
# (x509 -ext) y cifra la llave con valores viejos (PBKDF2 con SHA-1). Se usa el de Homebrew.
OPENSSL="${OPENSSL:-openssl}"
if "$OPENSSL" version | grep -q LibreSSL; then
  for alt in /opt/homebrew/bin/openssl /usr/local/bin/openssl; do
    [[ -x $alt ]] && ! "$alt" version | grep -q LibreSSL && { OPENSSL=$alt; break; }
  done
  "$OPENSSL" version | grep -q LibreSSL && { echo "Se necesita OpenSSL 3 o más reciente: brew install openssl"; exit 1; }
fi
openssl() { command "$OPENSSL" "$@"; }
DIAS_CA=3650               # raíz: 10 años, vive en un solo lugar y se reemplaza con poca frecuencia
# Si CA_PASS existe, openssl la toma del entorno; si no, la pregunta.
# genpkey usa -pass para la llave que escribe; req y ca usan -passin para la que leen.
pass_out() { [[ -n ${CA_PASS:-} ]] && echo "-pass env:CA_PASS" || true; }
pass_in()  { [[ -n ${CA_PASS:-} ]] && echo "-passin env:CA_PASS"  || true; }

inicializar() {
  mkdir -p private certs newcerts csr
  chmod 700 private
  touch index.txt
  [[ -f serial ]] || echo 1000 > serial
  echo "Estructura de la CA lista en $(pwd)"
}

crear_ca() {
  [[ -f index.txt ]] || inicializar
  if [[ -f private/ca.key ]]; then
    echo "private/ca.key ya existe: no se sobrescribe la CA (borrarla a mano si de verdad se quiere otra)"
    return 1
  fi
  echo "== 1. Llave privada de la CA: RSA 4096 cifrada con AES-256 (se pedirá la passphrase)"
  # umask 077: la llave nace legible solo por el dueño, sin ventana de tiempo con otros permisos
  # shellcheck disable=SC2046
  ( umask 077; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc \
      $(pass_out) -out private/ca.key )

  echo "== 2. Certificado raíz autofirmado ($DIAS_CA días) con [req]/[dn_ca]/[ext_ca]"
  # -x509 hace que req emita un certificado en vez de un CSR; se firma con su propia llave.
  # shellcheck disable=SC2046
  openssl req -config "$CNF" -new -x509 -key private/ca.key $(pass_in) \
    -days "$DIAS_CA" -sha256 -extensions ext_ca -out certs/ca.crt

  echo "== 3. Resultado"
  openssl x509 -in certs/ca.crt -noout -subject -issuer -dates -ext basicConstraints,keyUsage
  openssl x509 -in certs/ca.crt -noout -fingerprint -sha256
}

csr_servidor() {
  local nombre=$1
  [[ -f "$nombre.cnf" ]] || { echo "Falta ca/$nombre.cnf"; return 1; }
  mkdir -p csr
  echo "== 1. Llave del servidor $nombre: RSA 2048 SIN passphrase (Apache arranca sin intervención)"
  if [[ -f private/$nombre.key ]]; then
    echo "   private/$nombre.key ya existe: se reutiliza (renovar el certificado no obliga a cambiar la llave)"
  else
    ( umask 077; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "private/$nombre.key" )
  fi

  echo "== 2. CSR con el SAN de $nombre.cnf"
  openssl req -config "$nombre.cnf" -new -key "private/$nombre.key" -out "csr/$nombre.csr"

  echo "== 3. Revisión del CSR (la firma prueba que quien lo pide tiene la llave privada)"
  openssl req -in "csr/$nombre.csr" -noout -verify -subject
  openssl req -in "csr/$nombre.csr" -noout -text | grep -A1 'Subject Alternative Name'
}

firmar() {
  local nombre=$1
  [[ -f "csr/$nombre.csr" ]] || { echo "Falta csr/$nombre.csr: correr antes 'ca.sh csr $nombre'"; return 1; }
  [[ -f certs/ca.crt ]] || { echo "Falta la CA: correr antes 'ca.sh ca'"; return 1; }
  echo "== 1. Firma con la CA (se pedirá la passphrase de la CA)"
  # -extensions ext_servidor: CA:false + serverAuth, aunque el CSR pidiera otra cosa.
  # copy_extensions = copy (openssl-ca.cnf) trae el SAN del CSR; -batch evita las preguntas y/n.
  # shellcheck disable=SC2046
  openssl ca -config "$CNF" -batch -extensions ext_servidor $(pass_in) \
    -in "csr/$nombre.csr" -out "certs/$nombre.crt" -notext

  echo "== 2. Verificación de la cadena"
  openssl verify -CAfile certs/ca.crt "certs/$nombre.crt"

  echo "== 3. Nombres y uso del certificado"
  openssl x509 -in "certs/$nombre.crt" -noout -subject -issuer -dates -serial
  openssl x509 -in "certs/$nombre.crt" -noout -ext subjectAltName,extendedKeyUsage,basicConstraints
}

case "${1:-}" in
  init)   inicializar ;;
  ca)     crear_ca ;;
  csr)    csr_servidor "${2:?Uso: ca.sh csr <nombre>}" ;;
  firmar) firmar "${2:?Uso: ca.sh firmar <nombre>}" ;;
  *)      sed -n '2,8p' "$0"; exit 1 ;;
esac
