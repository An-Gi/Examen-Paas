# División del trabajo

## Criterio

La división se hace por **peso en la rúbrica** y no por número de tareas, y busca que cada estudiante tenga piezas que se apoyan entre sí:

- **A** se queda con la cadena **AWS → VPN → acceso público**, y con los servicios Docker que dependen del DNS (BIND9, Email con su registro MX y LDAP).
- **B** se queda con la cadena **WordPress → CA → Kubernetes** (el mismo CMS en dos plataformas), y con los servicios de archivos (OwnCloud, FTP, SMB).

| Rubro | Peso | Estudiante A | Estudiante B |
|---|---:|---:|---:|
| 6 servicios con Docker Compose | 30 % | 15 % (DNS, LDAP, Email) | 15 % (OwnCloud, FTP, SMB) |
| DB + WebServer + CMS sin contenedores | 20 % | — | 20 % |
| VPN con IaC (Terraform + Ansible) | 20 % | 20 % | — |
| CMS con Kubernetes | 10 % | — | 10 % |
| Acceso público al CMS con dominio | 10 % | 10 % | — |
| Documentación | 10 % | 5 % (§2, §3, diagrama) | 5 % (§5, §6, PDF) |
| **Total** | **100 %** | **50 %** | **50 %** |
| Extra (máx. 2 servicios) | +10 % | +5 % (Prometheus + Grafana) | +5 % (Uptime Kuma) |

Las secciones §1 (Introducción), §7 (Lecciones aprendidas) y §8 (Bibliografía) se escriben **entre los dos**. En §4 (Instalación) cada quien documenta sus servicios.

## Backlog por estudiante (horas estimadas)

### Estudiante A — ~39 h

| Fase | Tarea | h | Depende de |
|---|---|---:|---|
| F0 | Kick-off (juntos) | 1 | — |
| F0 | Herramientas, AWS (IAM, perfil, presupuesto), llave SSH, prueba de Terraform | 2 | — |
| F0 | Dominio, preguntas al profesor, issues | 1 | — |
| F2 | Terraform: SG, key pair, EC2, EIP, `local_file` para el inventario | 4 | F0 |
| F2 | Ansible, rol `openvpn`: PKI, `server.conf` TCP/TAP, `ip_forward`, NAT, CCD | 5 | Terraform |
| F2 | Clientes `.ovpn`: laptop, teléfono (TUN si aplica) y `web01` (entregar a B) | 2 | Rol openvpn |
| F2 | Documentación §4 de la VPN | 1 | — |
| F3 | `01-dns-bind9`: zonas directa e inversa de `paas.internal` | 2 | F0 |
| F3 | `02-ldap`: OpenLDAP + phpLDAPadmin, estructura y usuarios | 2,5 | F0 |
| F3 | `03-email`: docker-mailserver + Roundcube, cuentas y prueba interna | 3,5 | DNS (MX) |
| F5 | Registro A público, rol `nginx_proxy`, certbot y prueba de extremo a extremo | 5 | F2 + web01 de B |
| F6 | Extra: Prometheus + Grafana (node-exporter en las VMs) | 3 | F3 |
| F7 | §2 Ambiente, §3 Diseño, diagrama de red, comentarios en el código propio | 4 | — |
| F7 | Ensayos de defensa (juntos) | 3 | todo |

### Estudiante B — ~37 h

| Fase | Tarea | h | Depende de |
|---|---|---:|---|
| F0 | Kick-off (juntos) | 1 | — |
| F0 | Repositorio, herramientas | 1 | — |
| F0 | Red host-only, plantilla, 4 clones configurados | 2 | — |
| F1 | `db01`: MySQL con `bind-address`, base y usuario limitado a `web01` | 2 | F0 |
| F1 | CA con OpenSSL: raíz, CSR con SAN, firma, importar en navegador | 3 | F0 |
| F1 | `web01`: Apache + PHP + WordPress, vhosts `:80` y `:443` | 4 | db01, CA |
| F1 | Verificación y documentación §4 (nativo + CA) | 1 | — |
| F2 | Instalar el cliente VPN en `web01` con el `.ovpn` de A | 0,5 | F2 de A |
| F3 | `04-owncloud`: OwnCloud + MariaDB + Redis | 3 | F0 |
| F3 | `05-ftp`: pure-ftpd y montaje con `curlftpfs` desde otra VM | 2 | F0 |
| F3 | `06-smb`: Samba y montaje `cifs` desde otra VM | 2 | F0 |
| F4 | k3s y manifests (Namespace, Secret, MySQL StatefulSet, WP Deployment, Ingress) | 4 | F0 |
| F4 | Demo de escalado y autorrecuperación, documentación §4 | 2 | — |
| F6 | Extra: Uptime Kuma (+ preparar el respaldo DHCP) | 2,5 | F3 |
| F7 | §5 Actividades (`make horas`), §6 Autoevaluación y commits, PDF con pandoc | 4 | — |
| F7 | Ensayos de defensa (juntos) | 3 | todo |

> Las horas son estimaciones de planificación. En la bitácora solo se anota lo que **realmente** se trabajó. El profesor compara las horas con el producto.

## Puntos de integración (contratos entre A y B)

| Qué | De → A | Cuándo | Detalle |
|---|---|---|---|
| `web01.ovpn` con IP fija 10.8.0.20 | A → B | Fin de F2 | B lo instala en `web01` con `pull-filter ignore redirect-gateway` |
| WordPress que acepte `cms.<dominio>` | B → A | Antes de F5 | `WP_HOME` dinámico (ver `nativo/README.md`) |
| Nombres DNS de la LAN | B → A | F3 | `www`, `cms-k8s`, `cloud`, `ftp`, `smb` ya están en la zona; avisar si hay nuevos |
| Certificados de la CA para Email/LDAP | B → A | Opcional, F3 | `ca/scripts/ca.sh csr mail` + `firmar mail` |
| Puertos en `docker01` | A ↔ B | F3 | Tabla en `convenciones.md`; nadie publica un puerto que no esté ahí |
| IPs y dominios | A ↔ B | Siempre | `convenciones.md` es la fuente única |

## Protocolo de transferencia de conocimiento

La defensa exige que **ambos expliquen cualquier parte**. Por eso, en cada fase:

1. **Todo cambio llega por PR** y lo revisa el otro estudiante. El revisor debe entender el cambio, no solo aprobarlo.
2. **Al cerrar cada fase hay una sesión de 30 min**: quien la hizo la explica y el otro **la reproduce siguiendo solo el README** de la carpeta. Si no puede, el README está incompleto y se corrige.
3. Las preguntas que surjan se agregan a la sección *Preguntas probables en la defensa* del README correspondiente.
4. En los ensayos de la F7 **cada uno presenta las partes del otro**.
