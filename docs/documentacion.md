---
title: "Examen en casa — PaaS"
subtitle: "Red de servicios segura virtualizada"
author:
  - "Estudiante A: Angie Esquivel (carné)"
  - "Estudiante B: Alejandro Quesada (carné)"
date: "II-2026"
lang: es
toc: true
numbersections: true
geometry: margin=2.5cm
---

<!--
  Plantilla con las 9 secciones exactas que pide el enunciado. NO cambiar el orden ni los títulos.
  PDF: `make pdf`  → docs/build/documentacion.pdf
  Responsables: §1, §7 y §8 A+B · §2, §3 A · §4 cada quien lo suyo · §5, §6 B · §9 A+B
-->

# Introducción

<!-- A+B · Redactada en el kick-off (Fase 0), con palabras propias. ¿Qué problema se resuelve y por qué? -->

Las organizaciones rara vez dependen de un solo servicio: necesitan resolver nombres, guardar datos, publicar un sitio web, compartir archivos, comunicarse por correo y dar acceso remoto seguro a sus usuarios. Cada uno de esos servicios habla un protocolo distinto de la capa de aplicación (DNS, HTTP/HTTPS, SMTP/IMAP, FTP, SMB, LDAP, MySQL, OpenVPN), y el trabajo de un administrador de redes consiste tanto en ponerlos a funcionar como en lograr que convivan en una misma red sin estorbarse y sin exponer más de lo necesario.

Este examen plantea montar esa infraestructura completa, una pequeña *plataforma como servicio* (PaaS), sobre **una sola máquina física**. Para lograrlo, la virtualización es la pieza central: una LAN virtual privada (`10.10.10.0/24`, dominio interno `paas.internal`) agrupa varias máquinas virtuales, y cada una cumple un papel concreto. La seguridad es un requisito explícito, no un agregado: el sitio web debe servirse también por HTTPS con un certificado emitido por **nuestra propia entidad certificadora** (creada con OpenSSL), el acceso remoto pasa por una VPN y los secretos nunca se guardan en el repositorio.

El enunciado lista muchos servicios posibles, pero la evaluación premia seis resultados concretos. Por eso decidimos implementar exactamente lo que se califica y hacerlo de forma demostrable:

- **WordPress sin contenedores**, con la base de datos MySQL en un servidor distinto del servidor web, servido por HTTP y por HTTPS.
- **Seis servicios con Docker Compose**: DNS (BIND9), directorio LDAP, correo electrónico, OwnCloud, FTP y SMB.
- **El mismo CMS desplegado en Kubernetes** (k3s), para comparar ambos modelos de publicación.
- **Una VPN OpenVPN (TCP, interfaz TAP) en Amazon Web Services**, creada y configurada como infraestructura como código con Terraform y Ansible.
- **Acceso público al CMS** con el dominio **`examenpaas.tech`**: el tráfico llega a la instancia en AWS y viaja por el túnel VPN hasta el servidor web de la LAN.

Más allá de la nota, el objetivo es entender cada protocolo lo suficiente para explicar qué ocurre en la red cuando algo funciona y, sobre todo, cuando falla. Como la calificación depende de una defensa en la que ambos integrantes deben poder responder sobre cualquier parte, repartimos el trabajo por peso en la rúbrica (Estudiante A: la cadena AWS → VPN → dominio público y los servicios ligados al DNS; Estudiante B: la cadena WordPress → CA → Kubernetes y los servicios de archivos), pero cada cambio pasa por la revisión del otro. Este documento recoge el diseño, la instalación de cada servicio, las decisiones tomadas y lo aprendido en el proceso.

# Ambiente de desarrollo

<!-- A · Herramientas con su versión exacta (`make verificar` ayuda a obtenerlas). -->

| Herramienta | Versión | Uso |
|---|---|---|
| VirtualBox | | Hipervisor de la LAN virtual |
| Ubuntu Server | 26.04 LTS (ARM64) | SO de las VMs de la LAN |
| Ubuntu Server | 24.04 LTS (amd64) | SO de la EC2 (AMI de Canonical) |
| Terraform | | Aprovisionamiento en AWS |
| Ansible | | Configuración de OpenVPN y Nginx |
| Docker / Compose | | 6 servicios en contenedores |
| k3s | | Kubernetes de un nodo |
| OpenSSL | | Entidad certificadora |
| Git / GitHub | | Control de versiones |
| pandoc | | Generación de este PDF |

Máquina anfitriona: _CPU, RAM, disco, SO._

# Diseño

<!-- A · Decisiones (resumen de docs/decisiones/), diagrama y justificación. -->

## Diagrama de red

![Diagrama de red](img/red.png)

## Decisiones principales

<!-- Una subsección por decisión: contexto → decisión → alternativas descartadas. -->

### Alcance según la rúbrica

### Plataforma de virtualización y direccionamiento

### VPN TCP/TAP en AWS y su uso como camino del acceso público

### Servicios elegidos para Docker Compose

### Kubernetes con k3s

# Instalación de servicios

<!-- Cada quien documenta lo suyo: comandos reales, archivos de configuración relevantes y la prueba que demuestra que funciona. -->

## Entidad certificadora (OpenSSL) — Estudiante B

## Servidor de base de datos (MySQL en db01) — Estudiante B

## Servidor web y CMS (Apache + WordPress en web01) — Estudiante B

## VPN con IaC (Terraform + Ansible + OpenVPN) — Estudiante A

### Terraform

### Ansible

### Clientes (laptop, teléfono, web01)

## Servicios con Docker Compose

### DNS (BIND9) — Estudiante A

### LDAP (OpenLDAP) — Estudiante A

### Correo (docker-mailserver + Roundcube) — Estudiante A

### OwnCloud — Estudiante B

### FTP (pure-ftpd) — Estudiante B

### SMB (Samba) — Estudiante B

## CMS en Kubernetes (k3s) — Estudiante B

## Acceso público al CMS con dominio — Estudiante A

## Extras

### Prometheus + Grafana — Estudiante A

### Uptime Kuma — Estudiante B

# Actividades realizadas por estudiante

<!-- B · Generar con `make horas-md` y pegar aquí. Una línea por actividad. -->

## Estudiante A

| Fecha | Actividad | Horas |
|---|---|---:|
| | | |
| **Total** | | **0** |

## Estudiante B

| Fecha | Actividad | Horas |
|---|---|---:|
| | | |
| **Total** | | **0** |

# Autoevaluación

<!-- B · Con aporte de A. Honesta: el profesor compara contra lo demostrado. -->

## Estado final

## Problemas encontrados

## Limitaciones

## Reporte de commits

<!-- `make commits` → docs/build/commits.md -->

## Calificación según la rúbrica (0 a 10)

| Rubro | Peso | Nota (0–10) | Comentario |
|---|---:|---:|---|
| DataBase, WebServer y CMS sin contenedores | 20 % | | |
| VPN con IaC | 20 % | | |
| CMS con Kubernetes | 10 % | | |
| Acceso público al CMS con nombre de dominio (DNS) | 10 % | | |
| 6 servicios con Docker Compose | 30 % | | |
| Documentación | 10 % | | |
| Extra (máx. 2 servicios) | 10 % | | |

## Autoevaluación (1 a 5)

Escala: [1] Muy malo · [2] Malo · [3] Regular · [4] Bueno · [5] Muy bueno

| Rubro | Estudiante A | Estudiante B |
|---|:-:|:-:|
| Aprendizaje de servicios | | |
| Aprendizaje de IaC | | |
| Aprendizaje de PaaS | | |

# Lecciones aprendidas

<!-- A+B · Dirigidas a un estudiante que lleve el curso en el futuro. -->

# Bibliografía

<!-- A+B · Agregar fuentes conforme se usan (no al final). Formato APA o IEEE, consistente. -->

# Documentación del código fuente

<!-- A+B · Indicar dónde y cómo está documentado el código. -->

El código está comentado en su origen:

| Componente | Ubicación | Convención |
|---|---|---|
| Terraform | `terraform/*.tf` | Encabezado por archivo y comentario por recurso |
| Ansible | `ansible/roles/*/tasks/main.yml` | `name:` descriptivo en cada tarea y comentarios en las decisiones |
| Docker Compose | `docker/*/docker-compose.yml` | Encabezado con responsable y prueba de demo |
| Kubernetes | `k8s/manifests/*.yaml` | Encabezado por manifest |
| CA | `ca/scripts/ca.sh`, `ca/*.cnf` | Comentario por paso |
| Scripts | `scripts/**` | Uso y propósito en el encabezado |
