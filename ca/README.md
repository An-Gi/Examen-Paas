# Entidad certificadora propia (OpenSSL)

**Responsable:** Estudiante B · **Fase:** 1 · **Rubro:** DB + Web + CMS sin contenedores (20 %)

El enunciado exige que el certificado HTTPS de `web01` sea autogenerado y firmado por una CA propia hecha con OpenSSL, y que **todo el procedimiento quede documentado**.

## Archivos

| Archivo | Qué es | ¿En Git? |
|---|---|---|
| `openssl-ca.cnf` | Configuración de la CA: base de datos, políticas, extensiones `ext_ca` y `ext_servidor` | ✅ |
| `web01.cnf` | Petición (CSR) de `web01` con **SAN** (DNS e IP) | ✅ |
| `scripts/ca.sh` | Pasos `init`, `ca`, `csr`, `firmar` (esqueleto con TODO) | ✅ |
| `certs/ca.crt` | Certificado raíz (público, se importa en navegadores) | ✅ |
| `certs/web01.crt` | Certificado del servidor | ✅ |
| `private/*.key` | Llaves privadas | ❌ nunca |

## Pasos (Fase 1)

```bash
cd ca
bash scripts/ca.sh init          # estructura index.txt / serial
bash scripts/ca.sh ca            # TODO(B) llave + certificado raíz
bash scripts/ca.sh csr web01     # TODO(B) llave + CSR con SAN
bash scripts/ca.sh firmar web01  # TODO(B) firma + verificación
```

Copiar a `web01`: `certs/web01.crt` → `/etc/ssl/paas/web01.crt` y `private/web01.key` → `/etc/ssl/private/web01.key` (permisos `640`, grupo `ssl-cert`).

Importar `certs/ca.crt`:

- **Navegador de la demo:** Firefox usa su propio almacén (*Ajustes → Certificados → Importar*). Chrome y Edge usan el del sistema.
- **Sistema Linux:** `sudo cp ca.crt /usr/local/share/ca-certificates/paas-ca.crt && sudo update-ca-certificates`.

## Terminado cuando

- [ ] `openssl verify -CAfile certs/ca.crt certs/web01.crt` → `OK`
- [ ] `openssl x509 -in certs/web01.crt -noout -ext subjectAltName` muestra `web01.paas.internal`, `www.paas.internal` e `IP:10.10.10.20`
- [ ] `https://web01.paas.internal` muestra el candado **sin advertencias** en el navegador de la demo
- [ ] Cada comando quedó documentado en `docs/documentacion.md` §4

## Preguntas probables en la defensa

- ¿Por qué los navegadores ignoran el CN y exigen SAN?
- ¿Qué diferencia hay entre `ext_ca` (`CA:true`, `keyCertSign`) y `ext_servidor` (`serverAuth`)?
- ¿Por qué el certificado del servidor dura 397 días y no 10 años?
- ¿Qué pasa si se filtra `private/ca.key`?
- ¿Qué hace `copy_extensions` y qué riesgo tiene?
