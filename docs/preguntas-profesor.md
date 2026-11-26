# Preguntas para el profesor

Las envía **A** en la Fase 0 (0.6). Las respuestas se anotan aquí con su fecha y se citan en la documentación cuando justifiquen una decisión.

| # | Pregunta | Por qué importa | Supuesto mientras no haya respuesta | Respuesta (fecha) |
|---|---|---|---|---|
| 1 | Las apps de OpenVPN para Android e iOS no soportan interfaces **TAP** sin root. ¿Se acepta una segunda instancia en **TUN** solo para el teléfono? | VPN (20 %) | Sí: TAP para laptop y `web01`, TUN para el móvil, justificado en la documentación | |
| 2 | ¿Los contenedores auxiliares (MariaDB y Redis de OwnCloud, Roundcube, phpLDAPadmin) cuentan como servicios aparte? | Docker (30 %) | **No**: cada carpeta cuenta como 1 servicio | |
| 3 | El FileServer se pide en FreeBSD con jails. ¿FTP y SMB en Docker sobre Linux cuentan para el rubro de Docker Compose? | Docker (30 %) | Sí, porque el rubro de Docker es independiente del FileServer | |
| 4 | ¿Qué servicios se aceptan como **extra**? ¿Prometheus + Grafana cuenta como 1? | Extra (+10 %) | Sí: Prometheus + Grafana = 1 y Uptime Kuma = 1 | |
| 5 | Para "acceso público con dominio", ¿sirve un subdominio gratuito (DuckDNS) o debe ser un dominio propio? | DNS (10 %) | Dominio propio: **`examenpaas.tech`** (name.com, Student Pack), reservado el 2026-11-25 | |
| 6 | ¿Cuenta de AWS propia o AWS Academy Learner Lab? | VPN (20 %) | Cuenta propia con presupuesto de USD 5 | |
| 7 | ¿La red de la universidad permite salida a TCP 1194? ¿Podemos usar nuestro propio hotspot en la defensa? | Demo | Plan B: OpenVPN en TCP 443 o hotspot | |
| 8 | ¿El CMS en Kubernetes puede tener su propia base de datos en el clúster o debe usar la de `db01`? | K8s (10 %) | Base propia (StatefulSet) | |
| 9 | ¿El DNS interno (BIND en Docker) puede contar como servicio Docker **y** apoyar el rubro de DNS? | Docker / DNS | Sí | |
| 10 | Fecha y hora de la defensa, y reglas exactas del formato de entrega en Google Drive (nombres de archivos y carpetas) | Logística (nota 0 si no se cumple) | — | |
