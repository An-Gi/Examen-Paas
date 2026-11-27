# ADR-0002: Anfitriona Mac (Apple Silicon) con VMs ARM64

- **Estado:** Aceptada
- **Fecha:** 2026-11-25
- **Autor:** Estudiante B
- **Revisor:** Estudiante A

## Contexto

ADR-0001 asumía una anfitriona x86 con VirtualBox y `vboxnet0`. En el kick-off (2026-11-25) se evaluaron los equipos del grupo:

| Equipo | CPU / RAM | A favor | En contra |
|---|---|---|---|
| MacBook de B | Apple M2 Pro (arm64) / 16 GB | Se lleva a la defensa presencial; todo corre localmente | Solo ejecuta VMs ARM64; RAM justa para 4 VMs |
| PC Windows de B | x86 / 32 GB | RAM de sobra; el plan x86 funciona sin cambios | No se lleva a la defensa: habría que controlarlo de forma remota (túneles) |

La revisión es **presencial**, lo que no se demuestra funcionando no se califica y cada error resta 2 puntos. Una anfitriona remota agrega puntos de falla que el grupo no controla durante la defensa (Internet de la casa, electricidad, reinicios de Windows Update, túnel hacia la red host-only).

## Decisión

La anfitriona de la demo es la **MacBook M2 Pro de B**, con **VirtualBox 7.2** y VMs **Ubuntu Server 26.04 LTS ARM64**. Consecuencias concretas:

1. **SO e ISO:** Ubuntu Server **26.04 LTS** (la LTS vigente; soporte estándar hasta 2031), `ubuntu-26.04-live-server-arm64.iso` (no `amd64`). Tipo de VM `Ubuntu_arm64` (VirtualBox 7.2.0 no lista 26.04; el tipo solo fija valores por defecto), `--platform-architecture arm`. La plantilla se llama `ubuntu2604-plantilla`.
   - Cambios de 26.04 a tener presentes: `sudo-rs` y coreutils en Rust por defecto (los scripts usan opciones estándar), MySQL **8.4** (autenticación `caching_sha2_password`, compatible con `php-mysql`/mysqlnd) y PHP 8.4+.
   - La EC2 de A sigue con la AMI de Ubuntu 24.04 amd64; alinearla con 26.04 es opcional y decisión de A.
2. **Red host-only:** en macOS VirtualBox 7 no existe `vboxnet0`; se usa una red `hostonlynet` llamada **`lan-paas`** (`10.10.10.0/24`). vmnet le da al anfitrión la **`lower-ip`** de la red (comprobado: con `.100–.150` el Mac quedó en `10.10.10.100`) en una interfaz `bridgeN` que aparece al arrancar la primera VM, y sirve DHCP en el resto del rango. Por eso la red se define con `--lower-ip 10.10.10.1 --upper-ip 10.10.10.9`: el anfitrión queda en `10.10.10.1`, el DHCP de vmnet en `.2–.9` (ninguna VM lo usa) y `.100–.150` queda libre para el DHCP de respaldo. Se confirma con `ifconfig | grep -B4 'inet 10.10.10.'`.
3. **RAM recortada** (16 GB en total, macOS + navegador necesitan ~6 GB):

   | VM | ADR-0001 | Ahora |
   |---|---:|---:|
   | `db01` | 1 GB | 1 GB |
   | `web01` | 2 GB | 1,5 GB |
   | `docker01` | 4 GB | 3,5 GB |
   | `k8s01` | 4 GB | 3 GB |
   | **Total** | 11 GB | **9 GB** |

   Durante el desarrollo se encienden solo las VMs necesarias. En la defensa, Docker Desktop queda cerrado.
4. **Imágenes de contenedores:** todas deben tener variante `arm64`. Revisión en Docker Hub (2026-11-25):

   | Imagen actual | arm64 | Reemplazo | Responsable |
   |---|:-:|---|---|
   | `internetsystemsconsortium/bind9:9.20` | ❌ | `ubuntu/bind9:9.20-26.04` (mismo BIND sobre la misma 26.04 de las VMs, imagen de Canonical; revisar rutas de `/etc/bind`) | A |
   | `stilliard/pure-ftpd` | ❌ | `crazymax/pure-ftpd:1.0.54` (mismo pure-ftpd; cambian las variables de entorno) | B |
   | docker-mailserver, Roundcube, OwnCloud, MariaDB, Redis, OpenLDAP, phpLDAPadmin, dhcpd, Samba, Prometheus, Grafana, Uptime Kuma, WordPress, MySQL | ✅ | — | — |

5. **k3s, MySQL 8 y Apache/PHP** tienen paquetes oficiales para arm64; no cambia nada.
6. El entregable "binario compilado para x86 (si aplica)" **no aplica**: el examen no compila programas propios.

## Alternativas consideradas

| Alternativa | Ventajas | Desventajas | Motivo del descarte |
|---|---|---|---|
| PC Windows x86 (32 GB) controlado de forma remota | RAM de sobra, plan x86 intacto | Requiere Tailscale o la VPN de AWS para llegar a la LAN host-only; depende de la red de la casa | Riesgo inaceptable en una defensa presencial. Queda como **anfitriona de respaldo y de pruebas pesadas** |
| UTM (QEMU / Virtualization.framework) en el Mac | Muy estable en Apple Silicon | Sin `VBoxManage`: habría que reescribir los scripts de VMs | VirtualBox 7.2 ya soporta ARM64 y conserva los scripts |
| Docker Desktop del Mac en lugar de `docker01` | Menos RAM | Mezcla la anfitriona con la LAN; la demo pierde el nodo aislado | Rompe la separación de ADR-0001 |

## Consecuencias

- La demo no depende de nada fuera del aula, salvo AWS (VPN y acceso público, que lo exigen igual).
- Hay que adaptar `scripts/vm/preparar-red-virtualbox.sh` y `scripts/vm/clonar-vms.sh` a `hostonlynet` y ARM (hecho en este mismo cambio).
- **Nombres de NIC invertidos en ARM** (comprobado en la plantilla, 2026-11-25): el adaptador 1 (NAT) aparece como `enp0s8`, que en x86 es la LAN, y el adaptador 2 (`lan-paas`) como `enp0s9`. `configurar-vm` detecta la NIC de la LAN como la que no lleva la ruta por defecto, e `instalar-k3s.sh` la busca por la IP `10.10.10.40`; ningún script supone `enp0s8`.
- *(Superado por [ADR-0003](0003-alcance-servicios-respuestas-profesor.md) §3: el DHCP de Docker pasa a la red interna `wan-dhcp`.)* El DHCP de vmnet (`.2–.9`) y el DHCP de respaldo (`.100–.150`) coexisten en `lan-paas`: en la demo del respaldo, el cliente puede recibir oferta de ambos. Si molesta, se demuestra con el cliente filtrando por servidor o apagando temporalmente la red de vmnet.
- Si un servicio nuevo no tiene imagen `arm64`, se busca otra imagen antes de forzar emulación (`platform: linux/amd64` no funciona dentro de una VM ARM sin QEMU).
- Pregunta probable en la defensa: *¿por qué ARM y no x86?* Respuesta: los protocolos y servicios son idénticos; cambia solo la arquitectura del binario.
