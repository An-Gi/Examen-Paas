#!/usr/bin/env bash
# Instalación de MySQL en db01 — Estudiante B (Fase 1)
# Uso (en db01, desde la carpeta copiada con nativo/desplegar.sh):
#   sudo bash ~/paas/nativo/db01/instalar.sh
# Pide las contraseñas por teclado (no quedan en el historial). Tomarlas del gestor de contraseñas.
# También se pueden pasar como variables: sudo WP_DB_PASS=... WP_K8S_DB_PASS=... bash instalar.sh
# Es idempotente: volver a correrlo no rompe nada.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"

pedir() {   # pedir VARIABLE "descripción": la lee sin eco si no viene en el entorno
  local var=$1 desc=$2 v
  if [[ -z ${!var:-} ]]; then
    read -rsp "$desc: " v; echo
    printf -v "$var" '%s' "$v"
  fi
  [[ -n ${!var} ]] || { echo "$var no puede quedar vacía"; exit 1; }
  # Va dentro de un literal SQL '...': comilla simple o barra invertida lo romperían.
  [[ ${!var} != *[\'\\]* ]] || { echo "$var: sin comillas simples ni barras invertidas"; exit 1; }
  export "${var?}"
}
pedir WP_DB_PASS     "Contraseña de MySQL para 'wp'@'10.10.10.20' (CMS nativo)"
pedir WP_K8S_DB_PASS "Contraseña de MySQL para 'wp_k8s'@'10.10.10.40' (CMS en k3s)"

echo "== 1. Paquetes (MySQL server + envsubst + ufw)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q mysql-server gettext-base ufw

echo "== 2. Configuración: solo en 10.10.10.10, sin X Protocol"
rm -f /etc/mysql/mysql.conf.d/99-paas.cnf   # nombre anterior: se leía antes que mysqld.cnf y perdía
install -m 644 "$DIR/mysqld.cnf" /etc/mysql/mysql.conf.d/zz-paas.cnf
# El último bind-address es el que vale: debe ser el de la LAN
my_print_defaults mysqld | grep -E 'bind-address|mysqlx'
[[ $(my_print_defaults mysqld | grep -- '--bind-address=' | tail -n1) == --bind-address=10.10.10.10 ]] \
  || { echo "ERROR: otro archivo pisa bind-address"; exit 1; }
systemctl restart mysql
systemctl is-active --quiet mysql

echo "== 3. Endurecimiento (equivalente a mysql_secure_installation)"
# En Ubuntu root entra por auth_socket: solo el root del sistema operativo, sin contraseña de red.
mysql <<'SQL'
DELETE FROM mysql.user WHERE User = '';
DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';
FLUSH PRIVILEGES;
SQL

echo "== 4. Bases y usuarios de WordPress (nativo y k3s)"
# Solo se sustituyen estas variables: el resto del SQL no se toca.
envsubst '${WP_DB_PASS}'     < "$DIR/init-wordpress.sql"     | mysql
envsubst '${WP_K8S_DB_PASS}' < "$DIR/init-wordpress-k8s.sql" | mysql

echo "== 5. Firewall: SSH abierto, 3306 solo desde web01 y k8s01"
# Defensa en profundidad: bind-address limita la interfaz; ufw, quién puede llegar.
ufw allow OpenSSH >/dev/null
ufw allow from 10.10.10.20 to any port 3306 proto tcp comment 'web01 WordPress' >/dev/null
ufw allow from 10.10.10.40 to any port 3306 proto tcp comment 'k8s01 WordPress' >/dev/null
ufw --force enable >/dev/null

echo "== 6. Verificación"
ss -tlnp | grep -E ':(3306|33060)\b' || true
ss -tln | grep -q '10.10.10.10:3306' || { echo "ERROR: MySQL no escucha en 10.10.10.10:3306"; exit 1; }
mysql -e "SELECT user, host, plugin FROM mysql.user ORDER BY user;"
mysql -e "SHOW GRANTS FOR 'wp'@'10.10.10.20'; SHOW GRANTS FOR 'wp_k8s'@'10.10.10.40';"
ufw status numbered
echo
echo "Listo. Probar desde web01:  mysql -h 10.10.10.10 -u wp -p -e 'SHOW DATABASES;'"
