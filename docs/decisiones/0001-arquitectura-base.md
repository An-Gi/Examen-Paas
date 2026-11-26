# ADR-0001: Arquitectura base y alcance

- **Estado:** Aceptada (kick-off del 2026-11-25)
- **Fecha:** 2026-11-24
- **Autor:** Estudiante A + Estudiante B
- **Modificada por:** [ADR-0002](0002-anfitriona-mac-arm64.md) (anfitriona Mac con VMs Ubuntu 26.04 ARM64, red `hostonlynet`, RAM recortada)

## Contexto

El enunciado describe muchos servicios (Windows DC, FreeBSD jails, LTSP, OpenStack, BigBlueButton, Schleuder…), pero la rúbrica solo califica 6 rubros más un extra. Lo que no se demuestra funcionando no se califica y cada error en la defensa resta 2 puntos. Todo debe correr en **una sola máquina física**.

## Decisión

1. **Alcance:** implementar solo lo que puntúa. Los servicios de la lista que no están en la rúbrica no se implementan, salvo que el profesor indique otra cosa.
2. **Virtualización:** VirtualBox 7 con **Ubuntu Server 24.04 LTS** en todas las VMs, clonadas desde una plantilla (clones enlazados para ahorrar disco).
3. **Red:** host-only `10.10.10.0/24` sin DHCP (IPs fijas) más NAT para salir a Internet. El anfitrión (`10.10.10.1`) llega a todas las VMs, así que el navegador de la demo corre en él.
4. **Dominio interno:** `paas.internal`. `.internal` está reservado por ICANN para uso privado, a diferencia de `.lan` o `.local` (este último choca con mDNS).
5. **Nodos separados por rubro:** `db01` y `web01` nativos (la rúbrica exige base de datos y web en servidores distintos y sin contenedores), `docker01` para Compose y `k8s01` para k3s. Así cada rubro se demuestra aislado y un fallo en uno no arrastra a los demás.
6. **AWS:** una EC2 t3.micro con IP elástica que cumple dos roles: servidor OpenVPN (TCP/TAP) y reverse proxy Nginx del CMS. El acceso público pasa por el túnel VPN hasta `web01`, de modo que la VPN y el DNS público se demuestran juntos.
7. **IaC:** Terraform crea la infraestructura y genera el inventario. Ansible configura el software. Estado de Terraform local, porque un solo operador (A) lo aplica.

## Alternativas consideradas

| Alternativa | Motivo del descarte |
|---|---|
| KVM/libvirt | Mejor rendimiento, pero no todos los equipos del grupo usan Linux; VirtualBox es multiplataforma |
| Todo en una sola VM | Viola la separación DB/Web y complica la demo |
| Cloudflare Tunnel para el acceso público | Más simple, pero no aprovecha la VPN. **Queda como plan B** |
| `.lan` como dominio interno | No está reservado y puede chocar en el futuro |
| Backend remoto de Terraform (S3) | Innecesario con un solo operador; agrega costo y complejidad |

## Consecuencias

- Las 4 VMs suman ~11 GB de RAM, así que la anfitriona necesita ≥ 16 GB.
- La EC2 genera costo mientras existe: presupuesto con alertas y `terraform destroy` al terminar cada sesión.
- El teléfono probablemente necesite una instancia TUN aparte (ver la pregunta #1 al profesor).
