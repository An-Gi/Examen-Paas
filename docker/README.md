# 6 servicios con Docker Compose

**Responsables:** Estudiante A (01–03) y Estudiante B (04–06) · **Fase:** 3 · **Rubro:** 30 % (el de mayor peso)

Todos corren en `docker01` (10.10.10.30). Los puertos se publican **solo en esa IP** (tabla en [`docs/convenciones.md`](../docs/convenciones.md)).

| # | Carpeta | Servicio (lista del enunciado) | Resp. | Prueba de demo | Estado |
|---|---|---|---|---|---|
| 1 | `01-dns-bind9` | DNS · BIND9 | A | `dig @10.10.10.30 web01.paas.internal +short` | ⬜ |
| 2 | `02-ldap` | Linux Domain Controller · LDAP | A | `ldapsearch` + alta de usuario en phpLDAPadmin | ⬜ |
| 3 | `03-email` | Email Server | A | Correo de usuario1 a usuario2 por Roundcube | ⬜ |
| 4 | `04-owncloud` | OwnCloud | B | Login y subida de un archivo | ⬜ |
| 5 | `05-ftp` | FileServer · FTP | B | `curlftpfs` montado en otra VM | ⬜ |
| 6 | `06-smb` | FileServer · SMB | B | `mount -t cifs` en otra VM | ⬜ |
| 7 | `90-respaldo-dhcp` | DHCP (respaldo) | B | Solo si falla uno de los 6 | — |
| + | `extras/monitoreo` | Prometheus + Grafana (extra) | A | Dashboard de las VMs | ⬜ |
| + | `extras/uptime-kuma` | Uptime Kuma (extra) | B | Panel con todos los servicios en verde | ⬜ |

## Uso

```bash
cd docker
cp .env.example .env               # contraseñas reales desde el gestor compartido
./compose.sh 01-dns-bind9 up -d    # un servicio
./compose.sh todos up -d           # los 6 calificables
./compose.sh 04-owncloud logs -f
```

## Reglas

- **Un servicio por carpeta**, con su `docker-compose.yml` y un encabezado que indica responsable y prueba de demo.
- Contenedores auxiliares (bases de datos, interfaces web) van en la **misma** carpeta y no cuentan como servicio aparte (pregunta #2).
- **Fijar las versiones de las imágenes** (nada de `latest` en la defensa). Las marcadas con `TODO` se fijan en la Fase 3.
- Datos en **volúmenes con nombre**, para que sobrevivan a un `down`/`up`.
- Evitar NFS en contenedor: necesita módulos del kernel y modo privilegiado, y suele fallar.
- El correo hacia Internet no funciona (el puerto 25 está bloqueado por ISPs y AWS): la demo es dentro de `paas.internal`.

## Preparar docker01 (una vez, quien llegue primero)

```bash
# Docker Engine oficial: https://docs.docker.com/engine/install/ubuntu/
sudo usermod -aG docker paas
# Clientes para las pruebas en las otras VMs:
sudo apt install -y dnsutils ldap-utils curlftpfs cifs-utils
```

## Preguntas probables en la defensa

- ¿Diferencia entre volumen con nombre y *bind mount*?
- ¿Por qué el puerto 53 se publica solo en 10.10.10.30? (`systemd-resolved`)
- ¿Por qué FTP necesita puertos pasivos y qué es `PUBLICHOST`?
- ¿Qué pasa con los datos si se ejecuta `docker compose down -v`?
