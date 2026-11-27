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
| OpenSSL | | Entidad certificadora |
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

## Servidor de base de datos (MySQL en db01) — Estudiante B

## Servidor web y CMS (Apache + WordPress en web01) — Estudiante B

## VPN con IaC (Terraform + Ansible + OpenVPN) — Estudiante A

### Terraform

### Ansible

### Clientes (laptop, teléfono, web01)

## Servicios con Docker Compose

### DNS (BIND9) — Estudiante A

### LDAP (OpenLDAP) — Estudiante A

### Correo (docker-mailserver + Roundcube) — Estudiante A

### Preparación de docker01 (común a A y B)

1. **Estabilidad y Docker.**
   - `scripts/vm/ajustes-demo.sh` agrega 1 GB de swap y apaga las actualizaciones automáticas (ver §4, db01).
   - `docker/instalar-docker.sh` instala Docker 29.10 y el plugin Compose 5.8 desde el repositorio oficial de Docker (ya tiene Ubuntu 26.04 en arm64).
   - También limita los logs de cada contenedor a 3 × 10 MB y agrega `zekken` al grupo `docker`. Ese grupo equivale a root en la VM, así que solo lo tiene quien la administra.
2. **Secretos.** `docker/generar-env.sh` crea `docker/.env` (permisos 600) a partir de `.env.example`:
   - cada valor `cambiar` se reemplaza por una contraseña aleatoria alfanumérica de 24 caracteres (`openssl rand`), sin imprimirla;
   - las variables que ya existen no se tocan, así que A puede volver a correrlo para agregar las suyas.

   El `.env` vive solo en la VM y en el gestor de contraseñas. `docker/desplegar.sh` copia `docker/` desde el Mac excluyéndolo.
3. **Imágenes.** Todas con versión fija y comprobadas para arm64 en Docker Hub (ADR-0002). Los puertos se publican solo en `10.10.10.30`.

### OwnCloud — Estudiante B

`docker/04-owncloud`: OwnCloud 10.16.8 con MariaDB 10.11.19 (base de datos) y Redis 7.4.7 (caché y bloqueo de archivos). Son tres contenedores, pero **un** servicio del enunciado (pregunta #2).

- **Arranque ordenado.** MariaDB y Redis tienen *healthcheck*, y OwnCloud espera a que estén sanos (`depends_on: condition: service_healthy`). OwnCloud tiene su propio *healthcheck* (`/usr/bin/healthcheck`).
- **Solo OwnCloud publica un puerto** (`10.10.10.30:8080`). MariaDB y Redis solo son alcanzables dentro de la red del proyecto de Compose.
- **Dominios de confianza:** `cloud.paas.internal`, `docker01.paas.internal` y `10.10.10.30`. Con otro `Host`, OwnCloud responde 400.
- **Memoria acotada,** porque `docker01` comparte ~3 GB con los servicios de A: buffer de InnoDB de 128 MB y Redis con 64 MB. El conjunto usa ~300 MB.
- **Datos en volúmenes con nombre** (`owncloud_files`, `owncloud_mysql`, `owncloud_redis`): sobreviven a `down`/`up`, pero no a `down -v`.

**Pruebas (2026-11-27):**

| Prueba | Resultado |
|---|---|
| `docker exec owncloud occ status` | `installed: true`, versión 10.16.8 |
| `curl http://10.10.10.30:8080/status.php` y con `Host: cloud.paas.internal` | `200`, `"installed":true` |
| La misma petición con `Host: evil.example` | `400` (dominio no confiable) |
| `curl http://10.10.10.30:8080/remote.php/webdav/` sin credenciales | `401` |
| `nc -z 10.10.10.30 3306` desde el anfitrión | Cerrado: MariaDB no se publica |
| `occ config:system:get memcache.locking` | `\OC\Memcache\Redis` |
| Navegador del Mac en `http://10.10.10.30:8080` | Inicio de sesión como `admin` y subida de un archivo: `PUT /remote.php/dav/files/admin/… 201` desde `10.10.10.1` en el log, y el archivo aparece en el volumen `owncloud_files` |

### FTP (pure-ftpd) — Estudiante B

`docker/05-ftp`: pure-ftpd 1.0.54 (`crazymax/pure-ftpd`; `stilliard/pure-ftpd` no tiene arm64).

- **Dos conexiones.** FTP usa una conexión de **control** (puerto 21; dentro del contenedor, 2100) y otra de **datos**.
  - En modo **pasivo**, el servidor anuncia una IP y un puerto, y el cliente abre la conexión de datos hacia ellos.
  - Por eso se publica el rango `30000–30009` y se fuerza `PASSIVE_IP=10.10.10.30`. Sin eso, el contenedor anunciaría su IP interna de Docker (`172.x`) y el cliente no podría conectarse.
- **Usuarios virtuales** (`AUTH_METHOD=puredb`): `ftpuser` existe solo para FTP, no en el sistema. `05-ftp/crear-usuario.sh` lo crea con `pure-pw useradd` (UID/GID 1000), tomando la contraseña de `.env` por la entrada estándar.
- **Banderas** (`pureftpd.flags`):
  - Cada usuario queda encerrado en su carpeta (`--chrooteveryone`). No hay anónimos, no se resuelven nombres, y no se pueden escribir archivos ocultos.
  - El "modo seguro" de la imagen se apagó porque incluye `--norename`, que rompe `mv` en el punto de montaje.
- **Sin cifrado:** FTP manda la contraseña en claro. Es aceptable dentro de la LAN host-only. FTPS con un certificado de nuestra CA queda como mejora posible.

**Montaje en un cliente Linux** (lo pide el enunciado). `docker/probar-montajes.sh ftp` se corre en `web01`:

- Monta el FTP en `/mnt/ftp` con **`rclone mount`** (FUSE) y escribe y lee un archivo.
- **Problema encontrado:** `curlftpfs`, el cliente clásico, no funciona en Ubuntu 26.04. Con libcurl 8.18 falla con `Error setting curl:` antes de conectarse, incluso con credenciales falsas.
- La credencial queda en `/root/.config/rclone/rclone.conf` (600), ofuscada con `rclone obscure`. Ofuscar no es cifrar: la protegen los permisos. No se pasa por la línea de comandos porque se vería en `ps`.
- `--vfs-cache-mode writes` arma cada archivo en un caché local y lo sube completo, porque FTP no permite escribir a mitad de un archivo.

### SMB (Samba) — Estudiante B

`docker/06-smb`: Samba 4.23.10 (`dockurr/samba`). Recurso `//10.10.10.30/compartido` (volumen `smb_data`), con usuario `smbuser` y archivos con UID/GID 1000.

- **Solo el TCP 445.** SMB 2/3 va directo sobre TCP; el 139 es NetBIOS (SMB1) y no se publica.
- **Montaje:** `docker/probar-montajes.sh smb` en `web01` monta el recurso en `/mnt/smb` con `mount -t cifs`, dialecto **3.1.1** (el más nuevo, con firma y cifrado). Las credenciales van en un archivo temporal (600) que se borra después de montar.

**Pruebas de FTP y SMB (2026-11-27):**

| Prueba | Resultado |
|---|---|
| `curl ftp://10.10.10.30/` (login anónimo) | `530 Login authentication failed` |
| `smbutil view -N //guest@10.10.10.30` (invitado) | `Authentication error` |
| `probar-montajes.sh todos` en `web01` | `/mnt/ftp` (`fuse.rclone`) y `/mnt/smb` (`cifs`, `vers=3.1.1`) montados; archivo escrito y leído en ambos |
| Contenido de los volúmenes en `docker01` | `ftpuser/prueba-web01-124300.txt` ("hola desde web01 por ftp") y `prueba-web01-124316.txt` ("hola desde web01 por smb"), ambos con dueño 1000 |

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
