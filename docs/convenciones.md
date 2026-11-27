# Convenciones (fuente única de verdad)

Si algo de aquí cambia, se cambia **primero en este archivo**, en un PR, y después en el código.

## Máquina anfitriona

| Campo | Valor |
|---|---|
| Equipo elegido | MacBook de B · Apple M2 Pro (arm64) · 16 GB RAM · macOS 26 ([ADR-0002](decisiones/0002-anfitriona-mac-arm64.md)) |
| Hipervisor | VirtualBox 7.2 (Apple Silicon) · invitados **Ubuntu Server 26.04 LTS ARM64** |
| Red host-only | `hostonlynet` **`lan-paas`** (macOS no tiene `vboxnet0`) · anfitrión `10.10.10.1/24` · IPs fijas en las VMs |

## Inventario de nodos

| Nodo | IP LAN | NIC LAN | Rol | RAM | CPU | Responsable |
|---|---|---|---|---|---|---|
| anfitrión | 10.10.10.1 | `bridgeN` (vmnet) | Navegador de la demo, cliente VPN | — | — | A + B |
| `db01` | 10.10.10.10 | enp0s9 | MySQL 8 nativo | 1 GB | 1 | B |
| `web01` | 10.10.10.20 | enp0s9 | Apache + PHP + WordPress, cliente VPN | 1,5 GB | 1 | B |
| `docker01` | 10.10.10.30 | enp0s9 | Docker Compose (8 servicios del enunciado, ADR-0003) | 3,5 GB | 2 | A + B |
| `k8s01` | 10.10.10.40 | enp0s9 | k3s + WordPress | 3 GB | 2 | B |
| EC2 `vpn` | IP elástica | ens5 | OpenVPN + Nginx reverse proxy | t3.micro | 2 | A |

- VMs ARM64 ([ADR-0002](decisiones/0002-anfitriona-mac-arm64.md), comprobado en la plantilla): **`enp0s8` = NAT** (salida a Internet, ruta por defecto) y **`enp0s9` = LAN**, sin gateway. Es al revés que en x86 (`enp0s3` NAT, `enp0s8` LAN); los scripts detectan la NIC de la LAN en lugar de suponer el nombre.
- RAM total de las VMs: 9 GB (recortada para la anfitriona de 16 GB).
- Rango `10.10.10.2–9`: DHCP de vmnet en `lan-paas` (el anfitrión toma `.1`). Nunca usar esas IPs como fijas. El DHCP de Docker (`07-dhcp`) **no** sirve en `lan-paas`: va en la red interna `wan-dhcp`, que se define en la F3 (ADR-0003 §3).
- Usuario de las VMs: **`zekken`** (creado al instalar la plantilla y heredado por los clones), con acceso solo por llave SSH y `sudo`.

## Red VPN

| Elemento | Valor |
|---|---|
| Protocolo / interfaz | TCP / TAP, puerto 1194 (plan B: TCP 443) · instancia `server` |
| Subred | `10.8.0.0/24` · servidor `10.8.0.1` |
| `web01` (IP fija por CCD) | `10.8.0.20`, sin `redirect-gateway` |
| Laptop | Dinámica del pool, con `redirect-gateway` |
| Teléfono | Instancia `movil`: TCP / **TUN**, puerto 1195, subred `10.9.0.0/24`, con `redirect-gateway`. Aceptado por el profesor sin root ([pregunta #1](preguntas-profesor.md)); TAP con root/jailbreak = extra +7,5 % |

## Dominios y nombres

| Dominio | Uso |
|---|---|
| `paas.internal` | Zona interna en BIND9 (`docker01`). Se usa `.internal` porque ICANN lo reservó en 2024 para redes privadas, así que nunca va a chocar con un dominio público. |
| `examenpaas.tech` | **Público.** Registrado en name.com con el GitHub Student Developer Pack (2026-11-25). Sin registros ni redirecciones aún |
| `cms.examenpaas.tech` | Registro A → IP elástica de EC2 → Nginx → VPN → `web01` |

| Nombre interno | Apunta a | Servicio |
|---|---|---|
| `db01`, `web01`, `docker01`, `k8s01` | su IP | Nodos |
| `www.paas.internal` | web01 | WordPress nativo |
| `cms-k8s.paas.internal` | k8s01 | WordPress en Kubernetes (Ingress) |
| `ns1`, `ldap`, `mail`, `webmail`, `cloud`, `ftp`, `smb`, `grafana`, `kuma` | docker01 | Servicios Docker |

## Puertos publicados en `docker01`

Todos se publican **solo en `10.10.10.30`**, no en `0.0.0.0`. Así se evita, por ejemplo, el choque con `systemd-resolved`, que usa `127.0.0.53:53`.

| Puerto | Servicio | Carpeta | Responsable |
|---|---|---|---|
| 53/udp, 53/tcp | BIND9 | `01-dns-bind9` | A |
| 389, 636 | OpenLDAP | `02-ldap` | A |
| 8081 | phpLDAPadmin | `02-ldap` | A |
| 25, 143, 465, 587, 993 | docker-mailserver | `03-email` | A |
| 8082 | Roundcube | `03-email` | A |
| 8080 | OwnCloud | `04-owncloud` | B |
| 21, 30000–30009 | pure-ftpd (pasivo) | `05-ftp` | B |
| 445 | Samba | `06-smb` | B |
| 2049 | NFS v4 (completa el FileServer) | `06-smb` o carpeta propia, se decide en la F3 | B |
| 67/udp (host, solo en `wan-dhcp`) | DHCP (extra) | `07-dhcp` | B |
| 3001 | Uptime Kuma (panel de apoyo, no se cuenta) | `extras/uptime-kuma` | B |

## Secretos

- Valores reales: **solo** en el gestor de contraseñas compartido y en archivos ignorados por Git (`.env`, `terraform.tfvars`, `01-secret.yaml`).
- En el repo solo existen los `*.example`, con valores `cambiar`.
- El `.env` de `docker/` se crea con `cp .env.example .env`.

## Snapshots de VirtualBox

`base` (plantilla) → `fase0-ok` → `fase1-ok` → … → `pre-defensa`. Se toma uno **siempre antes** de un cambio riesgoso en algo que ya funciona.

## Git

Ver [`CONTRIBUTING.md`](../CONTRIBUTING.md): ramas `feat/<fase>-<tema>`, Conventional Commits con alcance y PR revisado por el otro estudiante.
