# DB + WebServer + CMS sin contenedores

**Responsable:** Estudiante B · **Fase:** 1 · **Rubro:** 20 %

| Nodo | IP | Qué corre | Qué NO debe tener |
|---|---|---|---|
| `db01` | 10.10.10.10 | MySQL 8 nativo (`apt`) | Apache, PHP, Docker |
| `web01` | 10.10.10.20 | Apache 2 + PHP + WordPress, HTTP `:80` y HTTPS `:443` | MySQL server, Docker |

## Archivos

| Archivo | Destino en la VM |
|---|---|
| `db01/mysqld.cnf` | `/etc/mysql/mysql.conf.d/zz-paas.cnf` |
| `db01/init-wordpress.sql` | Base `wordpress` y usuario `wp@10.10.10.20` (plantilla de `envsubst`) |
| `db01/init-wordpress-k8s.sql` | Base `wordpress_k8s` y usuario `wp_k8s@10.10.10.40` para la F4 ([ADR-0003](../docs/decisiones/0003-alcance-servicios-respuestas-profesor.md) §4) |
| `db01/instalar.sh` | MySQL, configuración, endurecimiento, bases, `ufw` y verificación |
| `web01/apache/wordpress-http.conf` | `/etc/apache2/sites-available/` |
| `web01/apache/wordpress-https.conf` | `/etc/apache2/sites-available/` |
| `web01/instalar.sh` | Apache, PHP, WordPress (con SHA-1 verificado), `wp-config.php`, certificados y vhosts |
| `desplegar.sh` | Se corre en el Mac: copia a `~/paas/` de la VM solo lo que necesita su instalador |

## Pasos

```bash
# En el Mac (raíz del repo). La CA se crea una sola vez (ver ca/README.md).
bash ca/scripts/ca.sh init && bash ca/scripts/ca.sh ca
bash ca/scripts/ca.sh csr web01 && bash ca/scripts/ca.sh firmar web01

bash nativo/desplegar.sh db01
ssh -t zekken@10.10.10.10 'sudo bash ~/paas/nativo/db01/instalar.sh'    # pide 2 contraseñas de MySQL

bash nativo/desplegar.sh web01
ssh -t zekken@10.10.10.20 'sudo bash ~/paas/nativo/web01/instalar.sh'   # pide la de wp
```

Luego se termina la instalación de WordPress en `https://web01.paas.internal`. El Mac necesita los nombres de la LAN en `/etc/hosts` y la raíz de la CA en su llavero (ver `ca/README.md`).

Las contraseñas se piden por teclado y no pueden llevar `'` ni `\`, porque van dentro de literales de SQL y de PHP.

## Decisiones

1. **HTTP y HTTPS conviven, sin redirección.** La rúbrica pide "web server sin cifrado" y "con cifrado", así que **no** se redirige `:80` a `:443`.
2. **`WP_HOME` dinámico.** WordPress guarda su URL (`siteurl`) y redirige a ella. Como el mismo sitio se abre por `http://web01…`, `https://web01…` y `https://cms.examenpaas.tech` (a través de Nginx en EC2), conviene calcular la URL en `wp-config.php`:

   `web01/instalar.sh` genera esa lógica con dos protecciones:
   - Solo acepta los `Host` conocidos (`web01`, `www`, `10.10.10.20`, `cms.examenpaas.tech`). Otro `Host` no puede reescribir los enlaces del sitio.
   - Solo cree `X-Forwarded-Proto: https` si la petición viene del proxy de la EC2 por el túnel (`10.8.0.1`). Cualquier otro cliente podría falsificar ese encabezado.

3. **El usuario de MySQL** `'wp'@'10.10.10.20'` solo puede conectarse desde `web01`, y solo a la base `wordpress`. Tiene privilegio mínimo: datos más `CREATE/ALTER/INDEX/DROP` para que WordPress instale y actualice sus tablas. No tiene `GRANT OPTION`, `FILE`, `PROCESS` ni `SUPER`.
4. **`bind-address` y `ufw`, los dos.** MySQL escucha solo en `10.10.10.10`, y `ufw` deja entrar al 3306 solo a `web01` y `k8s01`. El X Protocol (33060) se apaga.
5. **TLS:** Apache acepta solo TLS 1.2 y 1.3. No hay HSTS, porque rompería la demo del `:80`.
6. **`wp-config.php`:** dueño `root`, grupo `www-data`, permisos 640, y Apache niega servirlo. Las salts se generan con `openssl rand` y el editor de PHP del panel está apagado (`DISALLOW_FILE_EDIT`).

## Terminado cuando

- [x] `http://web01.paas.internal` y `https://web01.paas.internal` muestran WordPress, este último con candado válido
- [x] En web01: `mysql -h 10.10.10.10 -u wp -p -e 'SHOW DATABASES;'` funciona
- [x] En db01, la misma conexión desde otra IP es **rechazada** (probado desde el anfitrión `10.10.10.1`; repetir desde docker01 en la F3)
- [x] En web01: `systemctl status mysql` → *Unit not found* (no hay base de datos local)
- [x] `ss -tlnp` en db01 muestra 3306 solo en `10.10.10.10`
- [ ] Snapshot `fase1-ok`

## Preguntas probables en la defensa

- ¿Por qué `bind-address` y no un firewall? (respuesta ideal: ambos, ¿se configuró `ufw`?)
- ¿Qué pasa si `web01` cambia de IP?
- ¿Cómo sabe Apache qué vhost usar? (`ServerName`, SNI)
- ¿Dónde están las credenciales de la base de datos y quién puede leerlas?
