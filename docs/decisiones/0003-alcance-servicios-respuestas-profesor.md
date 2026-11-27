# ADR-0003: Alcance de servicios y extras según las respuestas del profesor

- **Estado:** Propuesta (actualización del 2026-11-27 con las consultas C1–C3; se acepta cuando B apruebe el PR, porque afecta su parte)
- **Fecha:** 2026-11-27
- **Autor:** Estudiante B · **Actualización:** Estudiante A
- **Revisor:** Estudiante A · **Revisor de la actualización:** Estudiante B

## Contexto

Las respuestas a las [preguntas #2 a #9](../preguntas-profesor.md) y a las consultas C1 a C3 cambian supuestos de ADR-0001. Lo esencial:

- **#2 y #3:** "solo lo que está en el enunciado cuenta como servicio". En la #3 el profesor no aclaró más.
- **#4:** los extras también pueden salir del enunciado: es extra **cualquier servicio por encima de los seis**.
- **#8:** sin respuesta.
- **#9:** el BIND en Docker puede apoyar el rubro de DNS, pero se prefiere un DNS **dedicado**.
- **C1 a C3:** consultas de otro estudiante del curso, respondidas por el profesor el 2026-11-27. No son nuestras, así que no están en `preguntas-profesor.md`, pero valen para todos los grupos:
  - **C1:** el FileServer va en **FreeBSD con jails**, aunque la rúbrica lo agrupe en "6 servicios con Docker-Compose". FTP y SMB en Docker **no** cumplen.
  - **C2:** el FileServer necesita **los tres** protocolos: FTP, SMB y NFS.
  - **C3:** la sincronización del LDAP con **Active Directory es obligatoria**. Un OpenLDAP independiente no basta. Según el profesor, "la instalación del AD es facilísima".

**Criterio del grupo:** si una respuesta es vaga o no llegó, se toma la lectura **más conservadora** del enunciado. Así, ninguna interpretación del profesor nos deja con menos puntos de los planeados.

En la lista de servicios del enunciado, *FileServer* es **un** servicio con tres protocolos (FTP, SMB y NFS), igual que *DNS* (Bind) o *DHCP* (DHCPD). La C2 lo confirma: FTP, SMB y NFS son **un solo** servicio. La C1 lo saca de Docker. Con eso, el plan original de esta ADR (ocho servicios en Docker, con FTP y SMB entre ellos) ya no se sostiene.

## Decisión

### 1. Servicios: ocho del enunciado, seis en Docker Compose

| # | Servicio del enunciado | Plataforma | Carpeta | Responsable |
|---|---|---|---|---|
| 1 | DNS (Bind) | Docker (`docker01`) | `01-dns-bind9` | A |
| 2 | Linux Domain Controller (LDAP), sincronizado con AD | Docker (`docker01`) | `02-ldap` | A |
| 3 | Email Server | Docker (`docker01`) | `03-email` | A |
| 4 | OwnCloud | Docker (`docker01`) | `04-owncloud` | B |
| 5 | DHCP (DHCPD) | Docker (`docker01`) | `90-respaldo-dhcp` → `07-dhcp` | B |
| 6 | Encrypted Mail List Server (Schleuder) | Docker (`docker01`) | `08-schleuder` (nueva) | A |
| 7 | **FileServer: FTP + SMB + NFS** | **FreeBSD con jails** (VM nueva `files01`, §6) | `freebsd/` (nueva) | B |
| 8 | **Windows Domain Controller (Active Directory)** | Windows Server (dónde corre se decide en §7) | `windows-ad/` (nueva) | A |

El AD era un candidato descartado (§2). La C3 lo vuelve **obligatorio**, porque el LDAP tiene que sincronizarse con él. Como también es un servicio del enunciado, se cuenta.

Con ocho servicios, cualquier conteo del profesor nos favorece:

| Si el profesor cuenta… | Rubro "6 servicios" | Extras |
|---|---|---|
| El FileServer dentro del rubro (lectura de la C1) | FileServer + 5 de Docker | El 6.º de Docker + AD = **2** (el máximo) |
| Solo los servicios en Docker Compose | Los 6 de Docker | FileServer + AD = **2** (el máximo) |
| El AD como parte del LDAP (no como servicio aparte) | Cualquiera de los dos anteriores | **1** |

Los contenedores auxiliares (MariaDB y Redis de OwnCloud, Roundcube, phpLDAPadmin) **no cuentan** (#2): cada carpeta es un servicio.

`docker/05-ftp` y `docker/06-smb` (PR #7) **dejan de contarse** como servicios. Se conservan como respaldo hasta que el FileServer de FreeBSD pase las mismas pruebas (`probar-montajes.sh`). Después se mueven a `docker/90-respaldo-ftp` y `docker/90-respaldo-smb`, o se eliminan. Su configuración se reutiliza en las jails: las banderas de pure-ftpd, los usuarios virtuales, el recurso de Samba y las pruebas de montaje.

### 2. Extras: servicios del enunciado, no herramientas externas

Prometheus + Grafana y Uptime Kuma **dejan de ser los extras**: no están en el enunciado y, según la #2, eso es lo que define un servicio. Los extras salen de los ocho servicios de §1: qué servicios terminan siendo extra depende del conteo del profesor (tabla de §1). DHCP y Schleuder se eligieron por fiabilidad en la demo y facilidad de instalación:

| Candidato del enunciado | Viable en el Mac (ARM64, 16 GB) | Fiabilidad en la demo | Esfuerzo | Veredicto |
|---|---|---|---|---|
| **DHCP (DHCPD)** | Sí, la imagen ya existe | Alta: una VM pide IP y la recibe | ~2 h | **Elegido** |
| **Schleuder** | Sí, sobre el Email de A | Media-alta: un correo cifrado llega re-cifrado a cada miembro | ~4 h | **Elegido** |
| **Windows Domain Controller** | Por verificar (§7) | Media: alta de usuario en AD que aparece en el LDAP | ~4–5 h con la sincronización | **Obligatorio** por la C3 (antes descartado) |
| MySQL en Docker | Sí | Alta | ~1 h | Descartado: es el mismo servicio que `db01` (rubro nativo) y podría no contar como otro |
| Thin Client (LTSP) | No en la práctica: PXE con VMs ARM | Baja | Alto | Descartado |
| BigBlueButton | No: exige Ubuntu x86 y ~16 GB solo para él | — | Muy alto | Descartado |
| OpenStack | No: controlador + nodo de cómputo no caben en la RAM que queda | — | Muy alto | Descartado |

Uptime Kuma puede seguir como **panel de apoyo** para la defensa (ver de un vistazo que todo está arriba), pero no se presenta ni se cuenta como servicio. Prometheus + Grafana queda a criterio de A; se recomienda no hacerlo, porque `docker01` tiene solo 3,5 GB.

### 3. DHCP en un segmento propio

El enunciado dice que el DHCP "se publicará para la WAN, por lo que este servicio puede estar fuera de la LAN". En `lan-paas` ya responde el DHCP de vmnet (`.2–.9`, ADR-0002). Dos servidores en el mismo segmento hacen que gane la primera oferta, y eso no es fiable en una demo. Por eso el DHCP sirve en una **red interna de VirtualBox aparte** (`wan-dhcp`): `docker01` recibe una 3.ª NIC y una VM cliente pide su IP ahí. El direccionamiento exacto se fija en la F3 y se anota en `convenciones.md`.

### 4. CMS en Kubernetes con la base de datos de `db01` (#8 sin respuesta)

El enunciado dice que el Database Server "será utilizado por una aplicación de WordPress u otro CMS". En el WebServer agrega que "la base de datos no puede estar presente en el mismo servidor". El clúster es de un solo nodo (`k8s01`), así que un MySQL en un StatefulSet quedaría **en el mismo servidor que el CMS**. Lectura conservadora:

- WordPress en k3s usa MySQL en `db01`, con una base **propia** (`wordpress_k8s`) y un usuario limitado a `10.10.10.40`. Los dos CMS quedan independientes.
- Dentro del clúster se llega a la base por un `Service` sin selector con un `Endpoints` a `10.10.10.10:3306`. Los pods siguen usando un nombre DNS de Kubernetes.
- Se elimina `k8s/manifests/02-mysql.yaml` (StatefulSet). La demo de escalado y de autorrecuperación sigue igual con el Deployment de WordPress.

### 5. DNS dedicado para el dominio público (#9), propuesta para A

El enunciado pide "un servicio de DNS con zonas para el dominio seleccionado, utilizando BIND". Hoy `examenpaas.tech` usaría el DNS de name.com, y el único BIND sería el de Docker, que sirve solo la LAN (`paas.internal`). Para que el rubro de DNS (10 %) tenga un BIND **dedicado**:

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| **A. BIND autoritativo en la EC2** para `examenpaas.tech`, instalado con un rol de Ansible y delegado desde name.com (registros *glue* `ns1`/`ns2.examenpaas.tech` → IP elástica) | Es BIND y sirve las zonas del dominio elegido. Es público y se demuestra con `dig +trace`. Suma IaC. Sin costo extra | Si la EC2 cae, el dominio no resuelve. Cambiar los NS en el registro tarda hasta 24–48 h: hay que hacerlo **temprano** |
| B. BIND en Docker con las zonas de `paas.internal` y `examenpaas.tech` | Ya planeado; el profesor lo acepta | No es dedicado, y la zona pública solo existe dentro de la LAN |
| C. VM aparte con BIND en la LAN | Dedicado | No es público y consume RAM que no hay |

**Recomendación: A.** El BIND de Docker sigue con `paas.internal` y cuenta como servicio Docker. El de la EC2 es autoritativo para `examenpaas.tech` (`cms`, `ns1`, `ns2`). Si name.com o el registro `.tech` exigen dos NS con IPs distintas, `ns2` puede ser un secundario gratuito (por ejemplo, Hurricane Electric con AXFR desde la EC2). El Security Group abre 53/udp y 53/tcp.

### 6. FileServer en FreeBSD con jails (C1 y C2), B

- **VM nueva `files01`:** FreeBSD aarch64 en `lan-paas`, con ~1 GB de RAM y 1 CPU. Las jails comparten el kernel del anfitrión, así que tres jails cuestan poco más que una VM sola. La IP y la versión de FreeBSD se fijan en la F3 y se anotan en `convenciones.md`.
- **Una jail por protocolo**, cada una con su IP en `lan-paas`:
  - `ftp`: pure-ftpd, con las mismas banderas y usuarios virtuales que `docker/05-ftp`.
  - `smb`: Samba, solo con el TCP 445 y SMB 3.1.1, como `docker/06-smb`.
  - `nfs`: servidor NFSv4. **Hay que verificarlo primero:** el servidor NFS dentro de una jail requiere una jail VNET con `allow.nfsd` (FreeBSD 13.3/14.1 o posterior). Si no funciona, `nfsd` corre en el anfitrión `files01` y se exporta la carpeta de una jail. Esa limitación se documenta en la §6.
- **Pruebas de la demo:** `probar-montajes.sh` (de `docker/`) se adapta a las IPs de las jails y monta desde `web01` los tres protocolos: `rclone mount` (FTP), `mount -t cifs` (SMB) y `mount -t nfs` (NFS). `jls` en `files01` muestra las tres jails.
- **Primer paso (spike de ≤ 1 h):** comprobar que FreeBSD aarch64 arranca en VirtualBox 7.2 sobre Apple Silicon y ve la red `lan-paas`. Hasta ahora no se ha probado (ADR-0002). Si falla, la alternativa es UTM (QEMU), aunque falta verificar que quede en la misma red que las VMs de VirtualBox.

### 7. Active Directory y sincronización con el LDAP (C3), A

**AD como fuente de verdad.** Los usuarios se crean en AD y se copian en una sola dirección al OpenLDAP de `02-ldap`. Una sincronización en las dos direcciones duplica el trabajo y los conflictos, y la C3 no la pide.

**Dónde corre Windows Server.** Es lo que falta decidir. ADR-0002 encontró que no hay Windows Server ARM para VirtualBox, así que A hace un spike de ≤ 1 h antes de elegir:

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| **A. Windows Server en una VM local** (imagen ARM64, si existe, en VirtualBox o UTM) | AD real dentro de `lan-paas`, sin costo | Hay que confirmar que exista y funcione una imagen ARM64. Windows Server Core necesita ≥ 2 GB, y la RAM ya está justa (Consecuencias) |
| **B. Windows Server en una EC2** (AMI oficial x86) | AD real con instalación estándar, sin depender del Mac | Costo por hora más alto que Linux (licencia incluida) contra un presupuesto de USD 5: se enciende solo para las pruebas y la defensa. `docker01` tiene que llegar a la EC2 por la VPN, y hoy el único cliente VPN de la LAN es `web01` |
| C. Samba 4 como AD DC (Linux, ARM64, en Docker o en una VM) | Implementa el protocolo de AD, es liviano y corre en el Mac | No es *Windows* Domain Controller: el profesor podría no aceptarlo como AD ni como servicio. Se usa solo como plan B |

**Recomendación:** Windows Server real (A o B, según el spike); C solo si ninguna funciona, y se documenta como limitación. Es la lectura conservadora, y coincide con el comentario del profesor de que la instalación es fácil, que apunta al asistente de Windows Server.

**Sincronización.** Se propone **LSC** (LDAP Synchronization Connector) en `docker01`: lee AD por LDAP, escribe en OpenLDAP y corre de forma periódica (temporizador de systemd o cron, cada pocos minutos). La alternativa más simple es un script con `ldapsearch` y `ldapadd`/`ldapmodify`. La herramienta la elige A. **Prueba de la demo:** se crea un usuario en "Usuarios y equipos de Active Directory", y después de la sincronización aparece en el `ldapsearch` del OpenLDAP y en phpLDAPadmin.

## Alternativas consideradas

| Alternativa | Ventajas | Desventajas | Motivo del descarte |
|---|---|---|---|
| Mantener ADR-0001 (6 servicios y extras externos) | Ya estaba planeado | Si FTP+SMB cuentan como uno, faltaría un servicio (−5 % del 30 %); los extras externos podrían no contar | No cubre la lectura conservadora |
| FileServer en Docker Compose (FTP y SMB en `docker01`, plan anterior de esta ADR) | Ya implementado y probado (PR #7) | Contradice la C1 | El profesor exige FreeBSD con jails (C1) |
| FileServer con solo uno o dos protocolos | Menos trabajo | Servicio incompleto | La C2 exige los tres |
| OpenLDAP independiente, con sus propios usuarios | Ya planeado, sin VM extra | No sincroniza con nada | La C3 hace obligatoria la sincronización con AD |
| CMS en k3s con su propio MySQL (StatefulSet) | Clúster autocontenido | Base y CMS en el mismo nodo, contra la regla del WebServer | Lectura conservadora de la #8 |

## Consecuencias

- **Carga (estimación inicial):**
  - B suma NFS y DHCP (~4 h) y deja Uptime Kuma (−2,5 h); la F4 se simplifica. Con la C1 suma la VM `files01` y las tres jails (~6 h), y reutiliza la configuración de FTP y SMB del PR #7.
  - A suma Schleuder (~4 h) y el BIND público (~2,5 h), y deja Prometheus + Grafana (−3 h). Con la C3 suma el AD y la sincronización (~4–5 h).
  - Las dos cargas suben de forma parecida. Se puede rebalancear en la revisión de este PR.
- **RAM:** hoy las VMs usan 9 GB de 16. `files01` suma ~1 GB. Un Windows Server local sumaría ≥ 2 GB, o sea un total de ~12 GB con macOS por encima. Si el AD va en la EC2 o en Samba, no se suma nada local. `docker01` libera un poco de memoria cuando FTP y SMB salen de Docker.
- **Contratos nuevos:**
  - B → A: crear la base `wordpress_k8s` en `db01`.
  - A → B: Schleuder necesita las cuentas de correo de los miembros de la lista.
  - A → B: si el AD va en la EC2, decir cómo llega `docker01` a la VPN (cliente propio o ruta por `web01`).
- **Riesgos que quedan:**
  - FreeBSD aarch64 en VirtualBox sobre Apple Silicon no se ha probado (spike de §6).
  - El servidor NFS dentro de una jail depende de la versión de FreeBSD y de VNET (§6).
  - Puede que no haya Windows Server ARM64 utilizable, y la EC2 Windows consume presupuesto (§7).
  - El profesor podría no aceptar Samba como AD, si se llega al plan C.
- **Archivos afectados:**
  - `convenciones.md` (puertos, la red `wan-dhcp`, el nodo `files01` con las IPs de sus jails y el nodo del AD), `division-trabajo.md`, el `README.md` raíz, `docker/README.md` (FTP y SMB pasan a respaldo), `docs/demo/guion-defensa.md` y la §3, §4 y §6 de `documentacion.md`.
  - `k8s/` (F4), `docker/90-respaldo-dhcp` (F3), `docker/02-ldap` (sincronización), `freebsd/` y `windows-ad/` (nuevas), y `terraform/` y `ansible/` (A, F5, y la EC2 del AD si se elige B).
