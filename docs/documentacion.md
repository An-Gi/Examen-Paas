---
title: "Examen en casa — PaaS"
subtitle: "Red de servicios segura virtualizada"
author:
  - "Estudiante A: _Nombre Apellido_ (carné)"
  - "Estudiante B: _Nombre Apellido_ (carné)"
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

_Por redactar en el kick-off._

# Ambiente de desarrollo

<!-- A · Herramientas con su versión exacta (`make verificar` ayuda a obtenerlas). -->

| Herramienta | Versión | Uso |
|---|---|---|
| VirtualBox | | Hipervisor de la LAN virtual |
| Ubuntu Server | 24.04.x LTS | SO de todas las VMs y de la EC2 |
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
