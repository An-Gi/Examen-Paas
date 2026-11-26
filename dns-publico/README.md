# Acceso público al CMS con nombre de dominio

**Responsable:** Estudiante A (con B para WordPress) · **Fase:** 5 · **Rubro:** 10 %

## Flujo

```
Navegador (Internet) ──DNS──▶ cms.examenpaas.tech  A  <IP elástica>
        │
        └──HTTP/HTTPS──▶ Nginx en EC2 ──túnel VPN (TAP)──▶ web01 10.8.0.20 (Apache + WordPress)
```

## Registros en el registrador

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| A | `cms` | `terraform output ip_publica` | 300 |
| CAA (opcional) | `@` | `0 issue "letsencrypt.org"` | 3600 |

## Pasos

1. `terraform apply` (F2) → anotar la IP elástica, que no cambia mientras el recurso exista.
2. Crear el registro A y verificarlo: `dig +short cms.examenpaas.tech` y `dig @1.1.1.1 +short cms.examenpaas.tech`.
3. B confirma que `web01` es cliente VPN con `10.8.0.20` y que WordPress tiene el `WP_HOME` dinámico.
4. `make proxy` (rol `nginx_proxy`).
5. HTTPS público: `nginx_proxy_certbot: true` y `make proxy` de nuevo.
6. Prueba final desde el **teléfono con datos móviles** (fuera de la LAN y sin VPN).

> Si `terraform destroy` borra la IP elástica, la siguiente tendrá otro valor: actualizar el registro A antes de la defensa.

## Plan B

**Cloudflare Tunnel** (`cloudflared` en `web01`) si la VPN falla el día de la defensa. Requiere tener el dominio en Cloudflare: decidirlo en la Fase 5, no el día de la defensa.

## Terminado cuando

- [ ] `curl -I https://cms.examenpaas.tech` → `200` desde fuera de la LAN
- [ ] Al apagar el cliente VPN de `web01`, el sitio deja de responder (prueba de que pasa por el túnel)
- [ ] El candado público es válido (Let's Encrypt)

## Preguntas probables en la defensa

- ¿Qué es un registro A, qué es el TTL y por qué lo bajamos a 300?
- ¿Por qué el certificado público es de Let's Encrypt y no de nuestra CA?
- ¿Qué ve el usuario si `web01` está apagado? (502 de Nginx)
