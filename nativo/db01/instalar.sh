#!/usr/bin/env bash
# Instalación de MySQL en db01 — Estudiante B (Fase 1)
# Uso (en db01): sudo WP_DB_PASS='...' bash instalar.sh
# Documentar cada paso real en docs/documentacion.md §4.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
: "${WP_DB_PASS:?Definir WP_DB_PASS (tomarla del gestor de contraseñas)}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# TODO(B) 1: apt-get install -y mysql-server gettext-base   (gettext-base trae envsubst)
# TODO(B) 2: install -m 644 "$DIR/mysqld.cnf" /etc/mysql/mysql.conf.d/99-paas.cnf && systemctl restart mysql
# TODO(B) 3: endurecer (equivalente a mysql_secure_installation: quitar usuarios anónimos y la base test)
# TODO(B) 4: envsubst '${WP_DB_PASS}' < "$DIR/init-wordpress.sql" | mysql
# TODO(B) 5: verificar: ss -tlnp | grep 3306   y   mysql -e "SELECT user,host FROM mysql.user;"
# TODO(B) 6 (opcional): ufw allow from 10.10.10.20 to any port 3306 proto tcp

echo "TODO(B): implementar instalar.sh de db01 (dir: $DIR)"; exit 1
