# ADR-0003: Alcance de servicios y extras según las respuestas del profesor

- **Estado:** Propuesta (se acepta cuando A apruebe el PR; afecta su parte)
- **Fecha:** 2026-11-27
- **Autor:** Estudiante B
- **Revisor:** Estudiante A

## Contexto

Las respuestas a las [preguntas #2 a #9](../preguntas-profesor.md) cambian supuestos de ADR-0001. Lo esencial:

- **#2 y #3:** "solo lo que está en el enunciado cuenta como servicio". En la #3 el profesor no aclaró más.
- **#4:** los extras también pueden salir del enunciado: es extra **cualquier servicio por encima de los seis**.
- **#8:** sin respuesta.
- **#9:** el BIND en Docker puede apoyar el rubro de DNS, pero se prefiere un DNS **dedicado**.

**Criterio del grupo:** si una respuesta es vaga o no llegó, se toma la lectura **más conservadora** del enunciado. Así, ninguna interpretación del profesor nos deja con menos puntos de los planeados.

En la lista de servicios del enunciado, *FileServer* es **un** servicio con tres protocolos (FTP, SMB y NFS), igual que *DNS* (Bind) o *DHCP* (DHCPD). La lectura conservadora de la #3 es entonces que **FTP y SMB podrían contar como un solo servicio**. En ese caso, el plan de ADR-0001 (DNS, LDAP, Email, OwnCloud, FTP y SMB) quedaría en 5.

## Decisión

### 1. Servicios en Docker Compose: ocho del enunciado

| # | Servicio del enunciado | Carpeta | Responsable |
|---|---|---|---|
| 1 | DNS (Bind) | `01-dns-bind9` | A |
| 2 | Linux Domain Controller (LDAP) | `02-ldap` | A |
| 3 | Email Server | `03-email` | A |
| 4 | OwnCloud | `04-owncloud` | B |
| 5 | FileServer: FTP | `05-ftp` | B |
| 6 | FileServer: SMB | `06-smb` | B |
| 7 | DHCP (DHCPD) | `90-respaldo-dhcp` → `07-dhcp` | B |
| 8 | Encrypted Mail List Server (Schleuder) | `08-schleuder` (nueva) | A |

Además, **NFS** se agrega al FileServer (B) para que el servicio cumpla los tres protocolos que pide el enunciado. NFS no se cuenta como un servicio aparte.

Con ocho servicios, cualquier conteo del profesor nos favorece:

| Si el profesor cuenta… | Rubro de Docker (6) | Extras |
|---|---|---|
| FTP y SMB por separado | 1–6 | DHCP + Schleuder = **2** (el máximo) |
| FTP + SMB (+ NFS) como un FileServer | DNS, LDAP, Email, OwnCloud, FileServer, DHCP | Schleuder = **1** |

Los contenedores auxiliares (MariaDB y Redis de OwnCloud, Roundcube, phpLDAPadmin) **no cuentan** (#2): cada carpeta es un servicio.

### 2. Extras: servicios del enunciado, no herramientas externas

Prometheus + Grafana y Uptime Kuma **dejan de ser los extras**: no están en el enunciado y, según la #2, eso es lo que define un servicio. Los extras pasan a ser **DHCP y Schleuder**. Se eligieron por fiabilidad en la demo y facilidad de instalación:

| Candidato del enunciado | Viable en el Mac (ARM64, 16 GB) | Fiabilidad en la demo | Esfuerzo | Veredicto |
|---|---|---|---|---|
| **DHCP (DHCPD)** | Sí, la imagen ya existe | Alta: una VM pide IP y la recibe | ~2 h | **Elegido** |
| **Schleuder** | Sí, sobre el Email de A | Media-alta: un correo cifrado llega re-cifrado a cada miembro | ~4 h | **Elegido** |
| MySQL en Docker | Sí | Alta | ~1 h | Descartado: es el mismo servicio que `db01` (rubro nativo) y podría no contar como otro |
| Windows Domain Controller | No: sin Windows Server ARM para VirtualBox | — | Alto | Descartado |
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

## Alternativas consideradas

| Alternativa | Ventajas | Desventajas | Motivo del descarte |
|---|---|---|---|
| Mantener ADR-0001 (6 servicios y extras externos) | Ya estaba planeado | Si FTP+SMB cuentan como uno, faltaría un servicio (−5 % del 30 %); los extras externos podrían no contar | No cubre la lectura conservadora |
| FileServer en FreeBSD con jails | Es literalmente lo que pide el enunciado | Otra VM y otro SO (aarch64 en VirtualBox, sin probar) sin RAM disponible; no tiene rubro propio | Costo alto para un ítem sin peso propio; queda como riesgo documentado |
| CMS en k3s con su propio MySQL (StatefulSet) | Clúster autocontenido | Base y CMS en el mismo nodo, contra la regla del WebServer | Lectura conservadora de la #8 |

## Consecuencias

- **Carga:**
  - B suma NFS y DHCP (~4 h) y deja Uptime Kuma (−2,5 h); la F4 se simplifica.
  - A suma Schleuder (~4 h) y el BIND público (~2,5 h), y deja Prometheus + Grafana (−3 h).
  - El reparto queda algo cargado hacia A. Se puede rebalancear en la revisión de este PR.
- **Contratos nuevos:**
  - B → A: crear la base `wordpress_k8s` en `db01`.
  - A → B: Schleuder necesita las cuentas de correo de los miembros de la lista.
- **Riesgo que queda:** que el profesor exija FreeBSD con jails para el FileServer. Se documenta en la §6 como limitación.
- **Archivos afectados:**
  - `convenciones.md` (puertos y la red `wan-dhcp`), `division-trabajo.md`, el `README.md` raíz y la §3 y §4 de `documentacion.md`.
  - `k8s/` (F4), `docker/90-respaldo-dhcp` (F3), y `terraform/` y `ansible/` (A, F5).
