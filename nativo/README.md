# DB + WebServer + CMS sin contenedores

**Responsable:** Estudiante B · **Fase:** 1 · **Rubro:** 20 %

| Nodo | IP | Qué corre | Qué NO debe tener |
|---|---|---|---|
| `db01` | 10.10.10.10 | MySQL 8 nativo (`apt`) | Apache, PHP, Docker |
| `web01` | 10.10.10.20 | Apache 2 + PHP + WordPress, HTTP `:80` y HTTPS `:443` | MySQL server, Docker |

## Archivos

| Archivo | Destino en la VM |
|---|---|
| `db01/mysqld.cnf` | `/etc/mysql/mysql.conf.d/99-paas.cnf` |
| `db01/init-wordpress.sql` | Plantilla que procesa `envsubst` (ver `db01/instalar.sh`) |
| `db01/instalar.sh` | Esqueleto de instalación de db01 |
| `web01/apache/wordpress-http.conf` | `/etc/apache2/sites-available/` |
| `web01/apache/wordpress-https.conf` | `/etc/apache2/sites-available/` |
| `web01/instalar.sh` | Esqueleto de instalación de web01 |

## Decisiones pendientes (registrarlas como ADR)

1. **HTTP y HTTPS conviven, sin redirección.** La rúbrica pide "web server sin cifrado" y "con cifrado", así que **no** se redirige `:80` a `:443`.
2. **`WP_HOME` dinámico.** WordPress guarda su URL (`siteurl`) y redirige a ella. Como el mismo sitio se abre por `http://web01…`, `https://web01…` y `https://cms.examenpaas.tech` (a través de Nginx en EC2), conviene calcular la URL en `wp-config.php`:

   ```php
   // TODO(B): validar en la Fase 1; respetar X-Forwarded-Proto cuando venga del proxy de EC2 (10.8.0.1)
   $proto = (!empty($_SERVER['HTTPS']) || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') ? 'https' : 'http';
   define('WP_HOME',    $proto . '://' . $_SERVER['HTTP_HOST']);
   define('WP_SITEURL', $proto . '://' . $_SERVER['HTTP_HOST']);
   if ($proto === 'https') { $_SERVER['HTTPS'] = 'on'; }
   ```

3. **El usuario de MySQL** `'wp'@'10.10.10.20'` solo puede conectarse desde `web01`.

## Terminado cuando

- [ ] `http://web01.paas.internal` y `https://web01.paas.internal` muestran WordPress, este último con candado válido
- [ ] En web01: `mysql -h 10.10.10.10 -u wp -p -e 'SHOW DATABASES;'` funciona
- [ ] En db01, la misma conexión desde otra IP es **rechazada** (probar desde docker01)
- [ ] En web01: `systemctl status mysql` → *Unit not found* (no hay base de datos local)
- [ ] `ss -tlnp` en db01 muestra 3306 solo en `10.10.10.10`
- [ ] Snapshot `fase1-ok`

## Preguntas probables en la defensa

- ¿Por qué `bind-address` y no un firewall? (respuesta ideal: ambos, ¿se configuró `ufw`?)
- ¿Qué pasa si `web01` cambia de IP?
- ¿Cómo sabe Apache qué vhost usar? (`ServerName`, SNI)
- ¿Dónde están las credenciales de la base de datos y quién puede leerlas?
