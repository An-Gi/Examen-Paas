---
title: "Examen en casa — PaaS"
subtitle: "Red de servicios segura virtualizada"
author:
  - "Estudiante A: Angie Esquivel (carné)"
  - "Estudiante B: Alejandro Quesada (carné)"
date: "II-2026"
lang: es
toc: true
numbersections: true
geometry: margin=2.5cm
---

<!--
  Plantilla con las 9 secciones exactas que pide el enunciado. NO cambiar el orden ni los títulos.
  PDF: `make pdf`  → docs/build/documentacion.pdf
  Responsables: §1, §7 y §8 A+B · §2, §3 A · §4 cada quien lo suyo · §5, §6 B · §9 A+B
-->

# Introducción

<!-- A+B · Redactada en el kick-off (Fase 0), con palabras propias. ¿Qué problema se resuelve y por qué? -->

Las organizaciones rara vez dependen de un solo servicio: necesitan resolver nombres, guardar datos, publicar un sitio web, compartir archivos, comunicarse por correo y dar acceso remoto seguro a sus usuarios. Cada uno de esos servicios habla un protocolo distinto de la capa de aplicación (DNS, HTTP/HTTPS, SMTP/IMAP, FTP, SMB, LDAP, MySQL, OpenVPN), y el trabajo de un administrador de redes consiste tanto en ponerlos a funcionar como en lograr que convivan en una misma red sin estorbarse y sin exponer más de lo necesario.

Este examen plantea montar esa infraestructura completa, una pequeña *plataforma como servicio* (PaaS), sobre **una sola máquina física**. Para lograrlo, la virtualización es la pieza central: una LAN virtual privada (`10.10.10.0/24`, dominio interno `paas.internal`) agrupa varias máquinas virtuales, y cada una cumple un papel concreto. La seguridad es un requisito explícito, no un agregado: el sitio web debe servirse también por HTTPS con un certificado emitido por **nuestra propia entidad certificadora** (creada con OpenSSL), el acceso remoto pasa por una VPN y los secretos nunca se guardan en el repositorio.

El enunciado lista muchos servicios posibles, pero la evaluación premia seis resultados concretos. Por eso decidimos implementar exactamente lo que se califica y hacerlo de forma demostrable:

- **WordPress sin contenedores**, con la base de datos MySQL en un servidor distinto del servidor web, servido por HTTP y por HTTPS.
- **Seis servicios con Docker Compose**: DNS (BIND9), directorio LDAP, correo electrónico, OwnCloud, FTP y SMB.
- **El mismo CMS desplegado en Kubernetes** (k3s), para comparar ambos modelos de publicación.
- **Una VPN OpenVPN (TCP, interfaz TAP) en Amazon Web Services**, creada y configurada como infraestructura como código con Terraform y Ansible.
- **Acceso público al CMS** con el dominio **`examenpaas.tech`**: el tráfico llega a la instancia en AWS y viaja por el túnel VPN hasta el servidor web de la LAN.

Más allá de la nota, el objetivo es entender cada protocolo lo suficiente para explicar qué ocurre en la red cuando algo funciona y, sobre todo, cuando falla. Como la calificación depende de una defensa en la que ambos integrantes deben poder responder sobre cualquier parte, repartimos el trabajo por peso en la rúbrica (Estudiante A: la cadena AWS → VPN → dominio público y los servicios ligados al DNS; Estudiante B: la cadena WordPress → CA → Kubernetes y los servicios de archivos), pero cada cambio pasa por la revisión del otro. Este documento recoge el diseño, la instalación de cada servicio, las decisiones tomadas y lo aprendido en el proceso.

# Ambiente de desarrollo

<!-- A · Herramientas con su versión exacta (`make verificar` ayuda a obtenerlas). -->

| Herramienta | Versión | Uso |
|---|---|---|
| VirtualBox | | Hipervisor de la LAN virtual |
| Ubuntu Server | 26.04 LTS (ARM64) | SO de las VMs de la LAN |
| Ubuntu Server | 24.04 LTS (amd64) | SO de la EC2 (AMI de Canonical) |
| Terraform | | Aprovisionamiento en AWS |
| Ansible | | Configuración de OpenVPN y Nginx |
| Docker / Compose | | 6 servicios en contenedores |
| k3s | | Kubernetes de un nodo |
| OpenSSL | 4.0.3 (Homebrew, en el Mac de B) | Entidad certificadora |
| MySQL Server | 8.4.13 (paquete de Ubuntu) | Base de datos en `db01` |
| Apache / PHP | 2.4.66 / 8.5.4 | Servidor web en `web01` |
| WordPress | 7.1.5 | CMS |
| Git / GitHub | | Control de versiones |
| pandoc | | Generación de este PDF |

Máquina anfitriona: _CPU, RAM, disco, SO._

# Diseño

<!-- A · Decisiones (resumen de docs/decisiones/), diagrama y justificación. -->

## Diagrama de red

![Diagrama de red](img/red.png)

## Decisiones principales

<!-- Una subsección por decisión: contexto → decisión → alternativas descartadas. -->

### Alcance según la rúbrica

### Plataforma de virtualización y direccionamiento

### VPN TCP/TAP en AWS y su uso como camino del acceso público

### Servicios elegidos para Docker Compose

### Kubernetes con k3s

# Instalación de servicios

<!-- Cada quien documenta lo suyo: comandos reales, archivos de configuración relevantes y la prueba que demuestra que funciona. -->

## Entidad certificadora (OpenSSL) — Estudiante B

La CA vive solo en el Mac de B, en `ca/`. Todo el procedimiento está en `ca/scripts/ca.sh`, y la configuración en `ca/openssl-ca.cnf` (CA) y `ca/web01.cnf` (petición de `web01`).

**Herramienta.** Se usa OpenSSL 4 de Homebrew. El `/usr/bin/openssl` de macOS es **LibreSSL 3.3.6**: no reconoce `x509 -ext` y cifra las llaves con PBKDF2 sobre SHA-1 y 2048 iteraciones. La primera CA se creó con él por accidente, se descartó y se regeneró. Desde entonces `ca.sh` rechaza LibreSSL y busca un OpenSSL real.

**1. Estructura** (`ca.sh init`). Crea `private/` con permisos `700`, la base de datos `index.txt` (un renglón por certificado emitido) y `serial`, que empieza en `1000`.

**2. Raíz** (`ca.sh ca`):

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc -out private/ca.key
openssl req -config openssl-ca.cnf -new -x509 -key private/ca.key -days 3650 -sha256 \
  -extensions ext_ca -out certs/ca.crt
```

- La llave es RSA de 4096 bits, cifrada con AES-256 y una *passphrase* guardada en el gestor de contraseñas. Se generó con `umask 077`.
- El certificado es autofirmado (emisor = sujeto = `CN=Examen PaaS Root CA`) y dura 10 años.
- `ext_ca` le pone `basicConstraints = critical, CA:TRUE` y `keyUsage = keyCertSign, cRLSign`: solo sirve para firmar otros certificados.

**3. Petición de `web01`** (`ca.sh csr web01`). La llave es RSA de 2048 bits **sin** passphrase: Apache tiene que poder leerla al arrancar sin que nadie la escriba. El CSR lleva el **SAN** `DNS:web01.paas.internal, DNS:www.paas.internal, IP:10.10.10.20`. Los navegadores ignoran el CN y validan solo contra el SAN (RFC 2818 y requisitos del CA/B Forum).

**4. Firma** (`ca.sh firmar web01`):

```bash
openssl ca -config openssl-ca.cnf -batch -extensions ext_servidor -in csr/web01.csr -out certs/web01.crt
openssl verify -CAfile certs/ca.crt certs/web01.crt        # certs/web01.crt: OK
```

- `ext_servidor` fija `CA:FALSE` y `extendedKeyUsage = serverAuth`: el certificado no puede firmar otros, aunque el CSR lo pidiera.
- `copy_extensions = copy` trae el SAN del CSR. Una extensión del CSR solo se copia si `ext_servidor` no la define, así que un CSR que pidiera `CA:TRUE` no lo conseguiría. El riesgo que queda es que acepte nombres arbitrarios en el SAN; por eso la CA solo firma CSRs que generamos nosotros.
- La vigencia es de 397 días, el máximo que aceptan los navegadores para un certificado de servidor.

**5. Distribución.**
- `nativo/desplegar.sh web01` copia a la VM `ca.crt`, `web01.crt` y `web01.key`. La llave de la CA nunca sale del Mac. El instalador deja el certificado en `/etc/ssl/paas/web01.crt` (644) y la llave en `/etc/ssl/private/web01.key` (640, `root:ssl-cert`).
- La raíz se agrega al almacén del sistema de `web01` (`update-ca-certificates`), al llavero del Mac (`security add-trusted-cert`) y a Firefox, que usa su propio almacén.
- En Git solo están `certs/*.crt`. `.gitignore` y el hook `detect-private-key` impiden subir llaves.

## Servidor de base de datos (MySQL en db01) — Estudiante B

`nativo/db01/instalar.sh` instala MySQL 8.4 desde los paquetes de Ubuntu y lo configura con `nativo/db01/mysqld.cnf`, que se instala como `/etc/mysql/mysql.conf.d/zz-paas.cnf`:

- `bind-address = 10.10.10.10`: escucha solo en la LAN, no en la NIC NAT ni en `0.0.0.0`.
  - **Problema encontrado:** el archivo se llamaba `99-paas.cnf` y MySQL seguía en `127.0.0.1`.
  - **Causa:** MySQL lee la carpeta en orden alfabético y el último valor gana. Los dígitos van antes que las letras, así que el `mysqld.cnf` de Ubuntu (`bind-address = 127.0.0.1`) se leía después.
  - **Arreglo:** el archivo pasó a `zz-paas.cnf`, y el instalador ahora comprueba el valor efectivo con `my_print_defaults mysqld`.
- `mysqlx = OFF`: el X Protocol (puerto 33060) no lo usa WordPress.
- **Memoria.** Con los valores por defecto MySQL ocupaba ~480 MB de los ~940 MB de la VM. Junto con un *upgrade* automático, el kernel lo mató 10 veces seguidas por falta de memoria (`Out of memory: Killed process … (mysqld)` en `journalctl -k`) y la VM dejó de responder. Se apagó `performance_schema` y se acotaron los buffers (`innodb_buffer_pool_size = 128M`, `max_connections = 40`): ahora ocupa ~225 MB. También se agregó swap (ver `scripts/vm/ajustes-demo.sh`).

Después el instalador:
- **Endurece** la instalación: borra usuarios anónimos, `root` remoto y la base `test`. `root` entra por `auth_socket`, o sea, solo el root del sistema y sin contraseña de red.
- **Crea** las bases y los usuarios:

| Base | Usuario | Puede conectarse desde | Privilegios |
|---|---|---|---|
| `wordpress` | `wp` | `10.10.10.20` (`web01`) | `SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, CREATE TEMPORARY TABLES, LOCK TABLES` sobre su base |
| `wordpress_k8s` | `wp_k8s` | `10.10.10.40` (`k8s01`, F4) | Los mismos, sobre su base |

Es privilegio mínimo: lo que WordPress necesita para su contenido y para crear o actualizar sus tablas. No incluye `GRANT OPTION`, `FILE`, `PROCESS` ni `SUPER`. Las contraseñas se piden por teclado y se insertan con `envsubst`, así que no quedan en el repositorio ni en el historial del shell.

- **Firewall.** Además de `bind-address`, `ufw` deja pasar SSH y el 3306 **solo** desde `10.10.10.20` y `10.10.10.40`. `bind-address` decide en qué interfaz escucha MySQL; `ufw` decide quién llega. Si una de las dos medidas falla, la otra sigue protegiendo la base.

**Pruebas (2026-11-27):**

```text
db01$ ss -tln | grep 3306
LISTEN 0  40  10.10.10.10:3306  0.0.0.0:*        # ni 127.0.0.1 ni 33060
web01$ mysql -h 10.10.10.10 -u wp -p wordpress -e 'SELECT CURRENT_USER();'
wp@10.10.10.20
mac$ nc -z -G 3 10.10.10.10 3306                 # anfitrión, no autorizado
(sin respuesta: lo descarta ufw)
```

## Servidor web y CMS (Apache + WordPress en web01) — Estudiante B

`nativo/web01/instalar.sh` instala Apache 2.4, PHP 8.5 con sus extensiones y el **cliente** de MySQL (no el servidor: la base de datos vive en `db01`, como exige el enunciado). Luego:

1. **Descarga WordPress** de `wordpress.org`, verifica su SHA-1 publicado y lo deja en `/var/www/wordpress` con dueño `www-data`.
2. **Genera `wp-config.php`:**
   - con `DB_HOST = 10.10.10.10`;
   - con *salts* de `openssl rand`;
   - dueño `root:www-data` y permisos `640`: el proceso web lo lee, pero no puede reescribirlo;
   - con `DISALLOW_FILE_EDIT`, para que no haya editor de PHP en el panel.
3. **Calcula la URL del sitio en cada petición.** El mismo WordPress se abre como `http://web01…`, `https://web01…` y, en la F5, como `https://cms.examenpaas.tech` a través de Nginx en la EC2. Dos protecciones:
   - solo se aceptan los `Host` conocidos, y cualquier otro se reemplaza por `web01.paas.internal`;
   - `X-Forwarded-Proto: https` solo se cree si la petición viene del proxy por el túnel (`10.8.0.1`).
4. **Instala el certificado** de la CA propia y habilita dos *virtual hosts* (`nativo/web01/apache/`):
   - `:80`, **sin redirección** a HTTPS, porque la rúbrica pide el servidor sin cifrado;
   - `:443`, con `SSLProtocol -all +TLSv1.2 +TLSv1.3` y sin HSTS, porque HSTS obligaría al navegador a usar HTTPS también en el `:80`.
   - Los dos niegan servir `wp-config.php`. Apache elige el vhost por el encabezado `Host` (en `:443`, por el SNI del saludo TLS) comparándolo con `ServerName` y `ServerAlias`.

La instalación de WordPress (título del sitio y administrador) se terminó en el navegador. La contraseña del administrador está en el gestor de contraseñas.

**Pruebas (2026-11-27):**

| Prueba | Resultado |
|---|---|
| `curl http://web01.paas.internal/` | `200`, sin redirección a HTTPS |
| `curl https://web01.paas.internal/` (Mac con la raíz en el llavero) | `200`, certificado válido (`ssl_verify_result = 0`) |
| Firefox en `https://web01.paas.internal` | Candado sin advertencias (raíz importada en Firefox) |
| `curl -H 'Host: evil.example' http://10.10.10.20/` | Enlaces siguen apuntando a `web01.paas.internal` |
| `curl -H 'X-Forwarded-Proto: https' http://web01…/` | Enlaces siguen en `http://`: el encabezado se ignora fuera del proxy |
| `curl http://web01.paas.internal/wp-config.php` | `403` |
| `openssl s_client -tls1_1` / `-tls1_2` / `-tls1_3` | Rechaza / acepta / acepta |
| `systemctl is-active mysql` en `web01` | `inactive`, el paquete no está instalado |

## VPN con IaC (Terraform + Ansible + OpenVPN) — Estudiante A

### Terraform

### Ansible

### Clientes (laptop, teléfono, web01)

## Servicios con Docker Compose

### DNS (BIND9) — Estudiante A

### LDAP (OpenLDAP) — Estudiante A

### Correo (docker-mailserver + Roundcube) — Estudiante A

### OwnCloud — Estudiante B

### FTP (pure-ftpd) — Estudiante B

### SMB (Samba) — Estudiante B

## CMS en Kubernetes (k3s) — Estudiante B

## Acceso público al CMS con dominio — Estudiante A

## Extras

### Prometheus + Grafana — Estudiante A

### Uptime Kuma — Estudiante B

# Actividades realizadas por estudiante

<!-- B · Generar con `make horas-md` y pegar aquí. Una línea por actividad. -->

## Estudiante A

| Fecha | Actividad | Horas |
|---|---|---:|
| | | |
| **Total** | | **0** |

## Estudiante B

| Fecha | Actividad | Horas |
|---|---|---:|
| | | |
| **Total** | | **0** |

# Autoevaluación

<!-- B · Con aporte de A. Honesta: el profesor compara contra lo demostrado. -->

## Estado final

## Problemas encontrados

## Limitaciones

## Reporte de commits

<!-- `make commits` → docs/build/commits.md -->

## Calificación según la rúbrica (0 a 10)

| Rubro | Peso | Nota (0–10) | Comentario |
|---|---:|---:|---|
| DataBase, WebServer y CMS sin contenedores | 20 % | | |
| VPN con IaC | 20 % | | |
| CMS con Kubernetes | 10 % | | |
| Acceso público al CMS con nombre de dominio (DNS) | 10 % | | |
| 6 servicios con Docker Compose | 30 % | | |
| Documentación | 10 % | | |
| Extra (máx. 2 servicios) | 10 % | | |

## Autoevaluación (1 a 5)

Escala: [1] Muy malo · [2] Malo · [3] Regular · [4] Bueno · [5] Muy bueno

| Rubro | Estudiante A | Estudiante B |
|---|:-:|:-:|
| Aprendizaje de servicios | | |
| Aprendizaje de IaC | | |
| Aprendizaje de PaaS | | |

# Lecciones aprendidas

<!-- A+B · Dirigidas a un estudiante que lleve el curso en el futuro. -->

# Bibliografía

<!-- A+B · Agregar fuentes conforme se usan (no al final). Formato APA o IEEE, consistente. -->

# Documentación del código fuente

<!-- A+B · Indicar dónde y cómo está documentado el código. -->

El código está comentado en su origen:

| Componente | Ubicación | Convención |
|---|---|---|
| Terraform | `terraform/*.tf` | Encabezado por archivo y comentario por recurso |
| Ansible | `ansible/roles/*/tasks/main.yml` | `name:` descriptivo en cada tarea y comentarios en las decisiones |
| Docker Compose | `docker/*/docker-compose.yml` | Encabezado con responsable y prueba de demo |
| Kubernetes | `k8s/manifests/*.yaml` | Encabezado por manifest |
| CA | `ca/scripts/ca.sh`, `ca/*.cnf` | Comentario por paso |
| Scripts | `scripts/**` | Uso y propósito en el encabezado |
