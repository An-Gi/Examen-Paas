# 6 servicios con Docker Compose

**Responsables:** Estudiante A (01–03) y Estudiante B (04–06) · **Fase:** 3 · **Rubro:** 30 % (el de mayor peso)

Todos corren en `docker01` (10.10.10.30). Los puertos se publican **solo en esa IP** (tabla en [`docs/convenciones.md`](../docs/convenciones.md)).

| # | Carpeta | Servicio (lista del enunciado) | Resp. | Prueba de demo | Estado |
|---|---|---|---|---|---|
| 1 | `01-dns-bind9` | DNS · BIND9 | A | `dig @10.10.10.30 web01.paas.internal +short` | ⬜ |
| 2 | `02-ldap` | Linux Domain Controller · LDAP | A | `ldapsearch` + alta de usuario en phpLDAPadmin | ⬜ |
| 3 | `03-email` | Email Server | A | Correo de usuario1 a usuario2 por Roundcube | ⬜ |
| 4 | `04-owncloud` | OwnCloud | B | Login y subida de un archivo | ✅ |
| 5 | `05-ftp` | FileServer · FTP | B | `rclone mount` en otra VM (`probar-montajes.sh ftp`) | ✅ |
| 6 | `06-smb` | FileServer · SMB | B | `mount -t cifs` en otra VM (`probar-montajes.sh smb`) | ✅ |
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
# En el Mac, desde la raíz del repo: copia docker/ (sin .env) a docker01
bash docker/desplegar.sh
# En docker01 (pide sudo):
sudo bash ~/paas/scripts/vm/ajustes-demo.sh     # swap y sin actualizaciones automáticas (rama F1)
sudo bash ~/paas/docker/instalar-docker.sh      # Docker oficial + Compose; zekken al grupo docker
bash ~/paas/docker/generar-env.sh               # .env con contraseñas aleatorias -> pasarlas al gestor
./compose.sh 04-owncloud up -d                  # y así cada servicio
bash 05-ftp/crear-usuario.sh                    # usuario virtual de FTP, después del up de 05-ftp
```

Prueba de montajes desde otra VM: `bash docker/desplegar.sh web01` y, en `web01`, `sudo bash ~/paas/docker/probar-montajes.sh todos`.

## Preguntas probables en la defensa

- ¿Diferencia entre volumen con nombre y *bind mount*?
- ¿Por qué el puerto 53 se publica solo en 10.10.10.30? (`systemd-resolved`)
- ¿Por qué FTP necesita puertos pasivos y qué es `PUBLICHOST`?
- ¿Qué pasa con los datos si se ejecuta `docker compose down -v`?
