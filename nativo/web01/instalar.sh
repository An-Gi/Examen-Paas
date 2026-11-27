#!/usr/bin/env bash
# Instalación de Apache + PHP + WordPress en web01 — Estudiante B (Fase 1)
# Uso (en web01, desde la carpeta copiada con nativo/desplegar.sh):
#   sudo bash ~/paas/nativo/web01/instalar.sh
# Pide la contraseña de 'wp'@'10.10.10.20' por teclado (o WP_DB_PASS=... en el entorno).
# Prerrequisitos: db01 instalado, y ca/certs/{ca,web01}.crt + ca/private/web01.key copiados
# junto a este script por desplegar.sh. Es idempotente: no reinstala WordPress si ya existe.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
CA_DIR="$(cd "$DIR/../../ca" && pwd)"
DB_HOST=10.10.10.10
WP_DIR=/var/www/wordpress

if [[ -z ${WP_DB_PASS:-} ]]; then
  read -rsp "Contraseña de MySQL para 'wp'@'10.10.10.20' (la misma que en db01): " WP_DB_PASS; echo
fi
[[ -n $WP_DB_PASS ]] || { echo "WP_DB_PASS no puede quedar vacía"; exit 1; }
# Va dentro de un literal PHP '...': comilla simple o barra invertida lo romperían.
[[ $WP_DB_PASS != *[\'\\]* ]] || { echo "Sin comillas simples ni barras invertidas"; exit 1; }
for f in certs/ca.crt certs/web01.crt private/web01.key; do
  [[ -f $CA_DIR/$f ]] || { echo "Falta $CA_DIR/$f: generar la CA en el Mac y correr nativo/desplegar.sh"; exit 1; }
done

echo "== 1. Paquetes: Apache, PHP y el CLIENTE de MySQL (nunca mysql-server aquí)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring \
  php-xml php-zip php-intl mysql-client curl ca-certificates

echo "== 2. La CA propia en el almacén del sistema (curl y PHP confían en ella)"
install -m 644 "$CA_DIR/certs/ca.crt" /usr/local/share/ca-certificates/paas-ca.crt
update-ca-certificates >/dev/null

echo "== 3. Conexión a la base remota en $DB_HOST"
MYSQL_PWD="$WP_DB_PASS" mysql -h "$DB_HOST" -u wp -e 'SELECT CURRENT_USER() AS conectado_como, DATABASE();' wordpress

echo "== 4. WordPress en $WP_DIR"
if [[ -f $WP_DIR/wp-includes/version.php ]]; then
  echo "   Ya instalado: $(grep -oP "wp_version = '\K[^']+" "$WP_DIR/wp-includes/version.php"); no se toca"
else
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/wp.tar.gz" https://wordpress.org/latest.tar.gz
  # wordpress.org publica el SHA-1 de cada paquete: detecta descargas corruptas o alteradas.
  echo "$(curl -fsSL https://wordpress.org/latest.tar.gz.sha1)  $tmp/wp.tar.gz" | sha1sum -c -
  tar -xzf "$tmp/wp.tar.gz" -C "$tmp"
  mkdir -p "$WP_DIR"
  cp -a "$tmp/wordpress/." "$WP_DIR/"
  chown -R www-data:www-data "$WP_DIR"
fi

echo "== 5. wp-config.php (credenciales, salts y URL dinámica)"
if [[ -f $WP_DIR/wp-config.php ]] && [[ -z ${REGENERAR_CONFIG:-} ]]; then
  echo "   Ya existe; no se regenera (REGENERAR_CONFIG=1 para forzarlo: cierra todas las sesiones)"
else
  # Salts locales con el CSPRNG de OpenSSL: no depende de api.wordpress.org. base64 no trae comillas.
  salt() { openssl rand -base64 48 | tr -d '\n'; }
  umask 027
  cat > "$WP_DIR/wp-config.php" <<PHP
<?php
// Generado por nativo/web01/instalar.sh — NO versionar (tiene credenciales).
define('DB_NAME',     'wordpress');
define('DB_USER',     'wp');
define('DB_PASSWORD', '${WP_DB_PASS}');
define('DB_HOST',     '${DB_HOST}');   // la base vive en db01, nunca en este servidor
define('DB_CHARSET',  'utf8mb4');
define('DB_COLLATE',  '');

define('AUTH_KEY',         '$(salt)');
define('SECURE_AUTH_KEY',  '$(salt)');
define('LOGGED_IN_KEY',    '$(salt)');
define('NONCE_KEY',        '$(salt)');
define('AUTH_SALT',        '$(salt)');
define('SECURE_AUTH_SALT', '$(salt)');
define('LOGGED_IN_SALT',   '$(salt)');
define('NONCE_SALT',       '$(salt)');
\$table_prefix = 'wp_';

// --- URL dinámica -------------------------------------------------------------------------
// El mismo sitio se abre como http/https://web01.paas.internal y como https://cms.examenpaas.tech
// (Nginx en la EC2 -> VPN -> aquí por HTTP). Sin esto WordPress redirige siempre a su siteurl.
// Solo se aceptan nombres conocidos: un Host arbitrario no puede cambiar los enlaces del sitio.
\$paas_hosts = ['web01.paas.internal', 'www.paas.internal', '10.10.10.20', 'cms.examenpaas.tech'];
\$paas_host  = strtolower(\$_SERVER['HTTP_HOST'] ?? '');
if (!in_array(\$paas_host, \$paas_hosts, true)) { \$paas_host = 'web01.paas.internal'; }
// X-Forwarded-Proto solo se cree si viene del proxy de la EC2 por el túnel (10.8.0.1).
\$paas_proxy = (\$_SERVER['REMOTE_ADDR'] ?? '') === '10.8.0.1'
               && (\$_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
\$paas_proto = ((!empty(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] !== 'off') || \$paas_proxy) ? 'https' : 'http';
if (\$paas_proto === 'https') { \$_SERVER['HTTPS'] = 'on'; }
define('WP_HOME',    \$paas_proto . '://' . \$paas_host);
define('WP_SITEURL', \$paas_proto . '://' . \$paas_host);

define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);   // sin editor de PHP en el panel: menos daño si roban una sesión
define('FS_METHOD', 'direct');

if (!defined('ABSPATH')) { define('ABSPATH', __DIR__ . '/'); }
require_once ABSPATH . 'wp-settings.php';
PHP
  umask 022
  # root es dueño (el proceso web no puede reescribirlo); www-data solo lo lee.
  chown root:www-data "$WP_DIR/wp-config.php"
  chmod 640 "$WP_DIR/wp-config.php"
fi
php -l "$WP_DIR/wp-config.php"

echo "== 6. Certificado del servidor firmado por la CA propia"
install -d -m 755 /etc/ssl/paas
install -m 644 "$CA_DIR/certs/web01.crt" /etc/ssl/paas/web01.crt
install -m 640 -o root -g ssl-cert "$CA_DIR/private/web01.key" /etc/ssl/private/web01.key

echo "== 7. Apache: módulos y vhosts :80 y :443 (sin redirección entre ellos)"
a2enmod -q ssl rewrite headers
install -m 644 "$DIR/apache/wordpress-http.conf"  /etc/apache2/sites-available/
install -m 644 "$DIR/apache/wordpress-https.conf" /etc/apache2/sites-available/
a2ensite -q wordpress-http wordpress-https
a2dissite -q 000-default 2>/dev/null || true
apache2ctl configtest
systemctl reload-or-restart apache2

echo "== 8. Verificación"
ss -tlnp | grep -E ':(80|443)\b' || true
systemctl is-active mysql 2>/dev/null && echo "ERROR: hay un MySQL local" || echo "OK: sin MySQL local"
for url in http://web01.paas.internal https://web01.paas.internal; do
  printf '%-32s ' "$url"; curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' "$url"
done
echo | openssl s_client -connect web01.paas.internal:443 -servername web01.paas.internal 2>/dev/null \
  | grep -E 'Verify return code|Protocol *:' || true
echo
echo "Listo. Terminar la instalación de WordPress en el navegador: https://web01.paas.internal"
