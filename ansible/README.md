# Ansible — OpenVPN y reverse proxy en la EC2

**Responsable:** Estudiante A · **Fases:** 2 (rol `openvpn`) y 5 (rol `nginx_proxy`) · **Rubros:** VPN con IaC (20 %) y acceso público (10 %)

```
ansible/
├── ansible.cfg
├── inventories/
│   ├── aws.ini              ← lo genera Terraform (ignorado por Git)
│   ├── aws.ini.example
│   └── group_vars/all.yml   ← red VPN, clientes, dominio
├── playbooks/vpn.yml        ← openvpn + nginx_proxy (tag: proxy)
├── roles/
│   ├── openvpn/             ← PKI easy-rsa, server.conf TCP/TAP, NAT, clientes .ovpn
│   └── nginx_proxy/         ← cms.examenpaas.tech → web01 por el túnel
└── clientes-ovpn/           ← .ovpn traídos con fetch (ignorados por Git)
```

## Uso

```bash
make tf-apply       # crea la EC2 y genera inventories/aws.ini
make vpn            # rol openvpn
make proxy          # rol nginx_proxy (Fase 5)
```

## Requisitos de la VPN (enunciado)

- **TCP** e interfaz **TAP**. El tráfico se **rutea** por AWS (`redirect-gateway def1`).
- Clientes en la **computadora** y el **teléfono**. El teléfono usa una segunda instancia **TUN** (`openvpn-server@movil`, TCP 1195, `10.9.0.0/24`), porque las apps móviles no soportan TAP sin root. El profesor lo aceptó (pregunta #1); TAP con root vale +7,5 % extra.
- `web01` es cliente con IP fija `10.8.0.20` (CCD) y `pull-filter ignore "redirect-gateway"`, porque solo usa el túnel para el reverse proxy.

## Terminado cuando (F2)

Prueba real del 2026-11-26 (EC2 en us-east-2, OpenVPN 2.6.19):

- [x] Correr el playbook dos veces da `changed=0` la segunda vez (idempotente)
- [x] Con el perfil `laptop` conectado, la IP de salida es la IP elástica (probado en un contenedor Linux)
- [x] `ip -d link show tap0` en el cliente confirma la interfaz TAP
- [x] El teléfono (OpenVPN Connect, perfil TUN) navega por AWS: `checkip.amazonaws.com` muestra la IP elástica
- [x] Desde la EC2: `ping 10.8.0.20` llega al cliente `web01` (probado en un contenedor; falta repetirlo con la VM `web01`)

> **macOS no soporta TAP** (Apple eliminó las extensiones de kernel; Tunnelblick y OpenVPN Connect solo hacen TUN
> en Apple Silicon). El cliente TAP "computadora" de la demo tiene que ser Linux (una VM o un contenedor con
> `--cap-add NET_ADMIN --device /dev/net/tun`) o Windows (adaptador TAP-Windows).
>
> Cada `terraform destroy` borra la PKI: el siguiente `apply` + `make vpn` genera una CA nueva y **todos los
> `.ovpn` cambian** (hay que volver a entregar `web01.ovpn`). La IP elástica también cambia.

## Preguntas probables en la defensa

- Diferencia entre TAP (capa 2) y TUN (capa 3). ¿Por qué el teléfono no soporta TAP?
- ¿Qué hacen `ip_forward` y `MASQUERADE`?
- ¿Por qué TCP es peor que UDP para una VPN (*TCP meltdown*)?
- ¿Qué protege `tls-crypt`?
- ¿Cómo se revoca un cliente?
