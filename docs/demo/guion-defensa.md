# Guion de la defensa (20 min)

**Orden: lo de más peso primero.** Si el tiempo se acaba, lo que falte es lo que menos vale.

## Antes de entrar (T−60 min)

- [ ] Snapshot `pre-defensa` en las 4 VMs. Las VMs encendidas y verificadas con `bash docs/demo/chequeo-previo.sh` _(crear en la F7)_.
- [ ] `terraform apply` hecho, playbook aplicado y `cms.examenpaas.tech` respondiendo desde datos móviles.
- [ ] CA importada en el navegador de la demo. Teléfono con el perfil VPN cargado.
- [ ] Este archivo abierto, con los comandos listos para copiar y pegar.
- [ ] Plan B de red: hotspot propio y OpenVPN en TCP 443.

## Tiempos

| Min | Rubro | Peso | Presenta | Prueba |
|---|---|---:|---|---|
| 0–1 | Diagrama y arquitectura | — | A | `docs/img/red.png` |
| 1–7 | 6 servicios Docker Compose | 30 % | A (3) · B (3) | Ver la tabla de abajo |
| 7–11 | DB + Web + CMS nativo + CA | 20 % | B | HTTP, HTTPS con candado, `mysql` remoto, web01 sin MySQL |
| 11–15 | VPN con IaC | 20 % | A | `terraform plan`, playbook, `curl ifconfig.me` = IP de AWS, teléfono |
| 15–17 | CMS en Kubernetes | 10 % | B | `kubectl get all`, `scale`, borrar un pod |
| 17–19 | Acceso público con dominio | 10 % | A | `cms.examenpaas.tech` desde el teléfono con datos móviles |
| 19–20 | Extras | +10 % | A · B | Grafana · Uptime Kuma |

> En los ensayos se **invierten los roles** (A presenta lo de B y viceversa), porque el profesor puede preguntarle a cualquiera.

## Comandos

### Docker (docker01)

```bash
# TODO(A): completar y probar cada comando en el ensayo
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
dig @10.10.10.30 web01.paas.internal +short                   # 1 DNS
ldapsearch -x -H ldap://10.10.10.30 -b dc=paas,dc=internal    # 2 LDAP
# 3 Email: enviar usuario1 → usuario2 en http://webmail.paas.internal:8082
# TODO(B)
# 4 OwnCloud: login y subir un archivo en http://cloud.paas.internal:8080
curlftpfs ftp://USUARIO:CLAVE@10.10.10.30 /mnt/ftp && ls /mnt/ftp    # 5 FTP (desde web01)
sudo mount -t cifs //10.10.10.30/compartido /mnt/smb -o username=USUARIO   # 6 SMB (desde db01)
```

### Nativo (B)

```bash
# TODO(B)
```

### VPN con IaC (A)

```bash
# TODO(A)
```

### Kubernetes (B)

```bash
# TODO(B)
```

### Acceso público (A)

```bash
# TODO(A)
```

## Registro de ensayos

| Fecha | Duración | Errores encontrados | Corregido |
|---|---|---|---|
