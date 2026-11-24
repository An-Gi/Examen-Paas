# Cómo trabajamos

## Flujo

1. Tomar un issue (o crearlo) y asignárselo.
2. Crear la rama desde `main` actualizada: `feat/<fase>-<tema>`. Ejemplos: `feat/f2-terraform-ec2`, `feat/f3-owncloud`, `fix/f1-vhost-https`, `docs/f7-diseno`.
3. Hacer **commits pequeños y frecuentes**. El reporte de commits forma parte de la autoevaluación, así que un solo commit gigante al final se ve mal.
4. Abrir un PR con la plantilla. **Lo revisa y aprueba el otro estudiante.**
5. En el mismo PR va la **actualización de la bitácora** con las horas de ese trabajo.
6. Merge con *Squash* o *Rebase*. Borrar la rama.

## Mensajes de commit (Conventional Commits)

```
<tipo>(<alcance>): <descripción en minúscula, imperativo>
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva (un servicio, un rol, un manifest) |
| `fix` | Corrección |
| `docs` | Solo documentación |
| `chore` | Mantenimiento (gitignore, Makefile, versiones) |
| `refactor` | Cambio sin efecto funcional |
| `test` | Pruebas o scripts de verificación |

**Alcances:** `infra`, `ca`, `nativo`, `tf`, `ansible`, `vpn`, `docker`, `dns`, `ldap`, `email`, `owncloud`, `ftp`, `smb`, `k8s`, `proxy`, `extras`, `docs`, `bitacora`.

Ejemplos:

```
feat(tf): security group con 22 restringido, 1194/tcp, 80 y 443
feat(owncloud): compose con mariadb y redis
fix(nativo): SAN de web01 incluía IP equivocada
docs(bitacora): registro de horas F1 del 2026-11-26
```

## Reglas

- **Secretos:** nunca. Si un hook de gitleaks bloquea el commit, **no** usar `--no-verify`: quitar el secreto. Si un secreto llega a GitHub, se **rota** (borrar el commit no alcanza).
- **Comentarios en el código:** la documentación §9 exige código comentado. Cada archivo de Terraform, playbook, compose y manifest lleva un encabezado con propósito, responsable y prueba de demo, y comentarios en las decisiones que no son obvias.
- **Marcadores `TODO(A)` / `TODO(B)`:** indican trabajo pendiente y su responsable. `make todos` los lista. Antes de la defensa no debe quedar ninguno en código que se vaya a mostrar.
- **Nada se rompe en `main`:** si algo ya funciona en la anfitriona, primero se toma un snapshot y después se cambia.
