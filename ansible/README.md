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
│   └── nginx_proxy/         ← cms.<dominio> → web01 por el túnel
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
- Clientes en la **computadora** y el **teléfono**. Ver la pregunta #1 sobre TAP en móviles.
- `web01` es cliente con IP fija `10.8.0.20` (CCD) y `pull-filter ignore "redirect-gateway"`, porque solo usa el túnel para el reverse proxy.

## Terminado cuando (F2)

- [ ] Correr el playbook dos veces da `changed=0` la segunda vez (idempotente)
- [ ] En la laptop conectada: `curl ifconfig.me` devuelve la IP elástica
- [ ] `ip -d link show tap0` en el cliente confirma la interfaz TAP
- [ ] El teléfono conectado navega por AWS (TUN si así se acordó con el profesor)
- [ ] Desde la EC2: `ping 10.8.0.20` llega a `web01`

## Preguntas probables en la defensa

- Diferencia entre TAP (capa 2) y TUN (capa 3). ¿Por qué el teléfono no soporta TAP?
- ¿Qué hacen `ip_forward` y `MASQUERADE`?
- ¿Por qué TCP es peor que UDP para una VPN (*TCP meltdown*)?
- ¿Qué protege `tls-crypt`?
- ¿Cómo se revoca un cliente?
