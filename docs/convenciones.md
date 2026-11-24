# Convenciones (fuente única de verdad)

Si algo de aquí cambia, se cambia **primero en este archivo**, en un PR, y después en el código.

## Máquina anfitriona

| Campo | Valor |
|---|---|
| Equipo elegido | _por completar en el kick-off (de quién, RAM, CPU, SO)_ |
| Hipervisor | VirtualBox 7.x |
| Red host-only | `vboxnet0` · anfitrión `10.10.10.1/24` · sin DHCP |

## Inventario de nodos

| Nodo | IP LAN | NIC LAN | Rol | RAM | CPU | Responsable |
|---|---|---|---|---|---|---|
| anfitrión | 10.10.10.1 | vboxnet0 | Navegador de la demo, cliente VPN | — | — | A + B |
| `db01` | 10.10.10.10 | enp0s8 | MySQL 8 nativo | 1 GB | 1 | B |
| `web01` | 10.10.10.20 | enp0s8 | Apache + PHP + WordPress, cliente VPN | 2 GB | 1 | B |
| `docker01` | 10.10.10.30 | enp0s8 | Docker Compose (6 servicios + extras) | 4 GB | 2 | A + B |
| `k8s01` | 10.10.10.40 | enp0s8 | k3s + WordPress | 4 GB | 2 | B |
| EC2 `vpn` | IP elástica | ens5 | OpenVPN + Nginx reverse proxy | t3.micro | 2 | A |

- `enp0s3` = NAT (salida a Internet, ruta por defecto). `enp0s8` = LAN, sin gateway.
- Rango reservado para DHCP de respaldo: `10.10.10.100–150`. Nunca usar esas IPs como fijas.
- Usuario de las VMs: `paas`, con acceso solo por llave SSH.

## Red VPN

| Elemento | Valor |
|---|---|
| Protocolo / interfaz | TCP / TAP, puerto 1194 (plan B: TCP 443) |
| Subred | `10.8.0.0/24` · servidor `10.8.0.1` |
| `web01` (IP fija por CCD) | `10.8.0.20`, sin `redirect-gateway` |
| Laptop | Dinámica del pool, con `redirect-gateway` |
| Teléfono | TUN aparte `10.9.0.0/24` si el profesor lo acepta ([pregunta #1](preguntas-profesor.md)) |

## Dominios y nombres

| Dominio | Uso |
|---|---|
| `paas.internal` | Zona interna en BIND9 (`docker01`). Se usa `.internal` porque ICANN lo reservó en 2024 para redes privadas, así que nunca va a chocar con un dominio público. |
| `<dominio>.xyz` | **Público**, por completar: `__________` |
| `cms.<dominio>.xyz` | Registro A → IP elástica de EC2 → Nginx → VPN → `web01` |

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
| 67/udp (host) | DHCP (respaldo, apagado) | `90-respaldo-dhcp` | B |
| 3000, 9090 | Grafana, Prometheus | `extras/monitoreo` | A |
| 3001 | Uptime Kuma | `extras/uptime-kuma` | B |

## Secretos

- Valores reales: **solo** en el gestor de contraseñas compartido y en archivos ignorados por Git (`.env`, `terraform.tfvars`, `01-secret.yaml`).
- En el repo solo existen los `*.example`, con valores `cambiar`.
- El `.env` de `docker/` se crea con `cp .env.example .env`.

## Snapshots de VirtualBox

`base` (plantilla) → `fase0-ok` → `fase1-ok` → … → `pre-defensa`. Se toma uno **siempre antes** de un cambio riesgoso en algo que ya funciona.

## Git

Ver [`CONTRIBUTING.md`](../CONTRIBUTING.md): ramas `feat/<fase>-<tema>`, Conventional Commits con alcance y PR revisado por el otro estudiante.
