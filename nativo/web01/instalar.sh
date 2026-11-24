#!/usr/bin/env bash
# Instalación de Apache + PHP + WordPress en web01 — Estudiante B (Fase 1)
# Uso (en web01): sudo WP_DB_PASS='...' bash instalar.sh
# Prerrequisitos: db01 listo, y certs/web01.crt + private/web01.key generados en ca/.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
: "${WP_DB_PASS:?Definir WP_DB_PASS}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# TODO(B) 1: apt-get install -y apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring \
#                               php-xml php-zip php-intl mysql-client
#            (mysql-CLIENT para probar la conexión; NUNCA mysql-server aquí)
# TODO(B) 2: descargar WordPress (https://wordpress.org/latest.tar.gz), verificar su checksum y
#            extraerlo en /var/www/wordpress con dueño www-data
# TODO(B) 3: wp-config.php con DB_HOST=10.10.10.10, DB_USER=wp, salts de
#            https://api.wordpress.org/secret-key/1.1/salt/ y el bloque WP_HOME dinámico (nativo/README.md)
# TODO(B) 4: certificados: /etc/ssl/paas/web01.crt (644) y /etc/ssl/private/web01.key (640 root:ssl-cert)
# TODO(B) 5: a2enmod ssl rewrite headers; copiar apache/*.conf; a2ensite ambos; a2dissite 000-default
# TODO(B) 6: apache2ctl configtest && systemctl reload apache2
# TODO(B) 7: completar la instalación de WordPress (navegador o wp-cli) y tomar el snapshot fase1-ok

echo "TODO(B): implementar instalar.sh de web01 (dir: $DIR)"; exit 1
