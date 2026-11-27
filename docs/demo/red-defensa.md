# Red de la defensa: Linksys E1200 V2 con DD-WRT

El profesor permitió usar un punto de acceso propio (pregunta #7 de [`preguntas-profesor.md`](../preguntas-profesor.md)). Con el router del grupo, la demo no depende del Wi-Fi de la universidad: el Mac y el teléfono quedan en una red privada nuestra, y lo único que se usa del TEC es la salida a Internet por el cable.

Probado en la red del TEC (cable de pared) el 2026-11-27.

## Topología

```text
Toma de pared TEC (DHCP 172.30.16.0/20, DNS del TEC)
        │ cable
   [WAN] Linksys E1200 V2 · DD-WRT · NAT
        │ 192.168.50.1/24
        ├── LAN 1 (cable) ── Mac anfitrión (adaptador USB, 192.168.50.x)
        │                      ├── VirtualBox host-only 10.10.10.0/24 (db01, web01, docker01, k8s01)
        │                      └── VirtualBox NAT de cada VM → sale por el Mac → router
        └── Wi-Fi 2.4 GHz WPA2-AES ── teléfono (cliente OpenVPN TUN)
                                         │
                       Internet ── EC2 (OpenVPN, Nginx, cms.examenpaas.tech)
```

- **El Mac va por cable** a LAN 1: es más estable que el Wi-Fi en un aula llena.
- **192.168.50.0/24** no choca con nada del proyecto: ni el TEC (172.30.x, DNS en 172.20.10.x), ni las VMs (10.10.10.0/24), ni las VPN (10.8.0.0/24 y 10.9.0.0/24), ni el 192.168.1.0/24 que traen casi todos los routers y hotspots.
- Hay doble NAT (router + TEC). OpenVPN sale como cliente hacia la EC2, así que no hace falta abrir ningún puerto entrante.

## Configuración en DD-WRT

La clave del panel de administración y la del Wi-Fi están en el gestor de contraseñas del grupo; no se versionan.

| Pantalla | Opción | Valor |
|---|---|---|
| Setup → Basic Setup | WAN Connection Type | Automatic Configuration – DHCP |
| | Router IP / máscara | `192.168.50.1` / `255.255.255.0` |
| | DHCP Server | Activado, desde `192.168.50.100`, 50 direcciones |
| | Static DNS | Vacío: usa el DNS que entrega el TEC por la WAN |
| | Time Zone | America/Costa_Rica |
| Setup → MAC Address Clone | WAN MAC | Solo si la toma no da IP al router: la MAC del adaptador USB del Mac (`ifconfig en7`), que la toma ya acepta. Con la MAC clonada, el adaptador no se conecta a la pared al mismo tiempo |
| Wireless → Basic Settings | Modo / red | AP, Mixed |
| | Canal / ancho | **1**, 20 MHz (el 6, 9, 11 y 13 estaban ocupados en el aula) |
| Wireless → Wireless Security | Seguridad | WPA2 Personal, solo **AES** (sin TKIP) |
| Administration → Management | Remote Management | Desactivado |
| | Info Site | Protegido con contraseña |
| Services | Telnet | **Desactivado** (pendiente, ver abajo) |
| NAT/QoS → UPnP | UPnP | Desactivado |

El E1200 V2 solo tiene 2.4 GHz. El día de la defensa se vuelve a mirar qué canales están libres en el aula (*Status → Wireless → Site Survey*) y se cambia a 1, 6 u 11, el que tenga menos redes.

## Pruebas (2026-11-27, desde el Mac por LAN 1)

| Prueba | Comando | Resultado |
|---|---|---|
| IP y ruta por defecto | `route -n get default`, `ipconfig getpacket en7` | `192.168.50.103`, gateway y DNS `192.168.50.1` |
| Latencia al router / a Internet | `ping 192.168.50.1`, `ping 1.1.1.1` | ~1 ms / ~57 ms |
| DNS | `dig +short wordpress.org` | Resuelve |
| Salida TCP | `nc -z portquiz.net 22 80 443 1194` | Los cuatro abiertos: OpenVPN en TCP 1194 sale sin el plan de TCP 443 |
| HTTPS | `curl https://wordpress.org/` | 200 |
| Internet desde una VM (NAT de VirtualBox) | En web01: `curl http://ports.ubuntu.com/` | 200; la VM recibe `192.168.50.1` como DNS |
| Panel del router desde la LAN | `curl http://192.168.50.1/` | 401 (pide clave) |
| Telnet del router | `nc -z 192.168.50.1 23` | **Abierto**: hay que desactivarlo |

## Pendiente

- [ ] **B:** desactivar Telnet en *Services → Services → Telnet* y comprobar que `nc -z 192.168.50.1 23` falla.
- [ ] **A:** probar **UDP 1194** detrás del router contra la EC2 (`portquiz.net` solo prueba TCP). Si UDP no sale, el plan B es OpenVPN en TCP 1194, que sí sale.
- [ ] **A:** `examenpaas.tech` todavía usa los servidores DNS por defecto de name.com y resuelve a `91.195.240.94` (HTTP 503), no a la EC2. Se corrige al delegar la zona al BIND de la EC2 (ADR-0003).
- [ ] Probar el teléfono conectado al Wi-Fi del router con el perfil VPN cargado.
- [ ] El día de la defensa: apagar el Wi-Fi del TEC en el Mac (o bajarlo en el orden de servicios) para que todo salga por el router.
