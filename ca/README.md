# Entidad certificadora propia (OpenSSL)

**Responsable:** Estudiante B · **Fase:** 1 · **Rubro:** DB + Web + CMS sin contenedores (20 %)

El enunciado exige que el certificado HTTPS de `web01` sea autogenerado y firmado por una CA propia hecha con OpenSSL, y que **todo el procedimiento quede documentado**.

## Archivos

| Archivo | Qué es | ¿En Git? |
|---|---|---|
| `openssl-ca.cnf` | Configuración de la CA: base de datos, políticas, extensiones `ext_ca` y `ext_servidor` | ✅ |
| `web01.cnf` | Petición (CSR) de `web01` con **SAN** (DNS e IP) | ✅ |
| `scripts/ca.sh` | Pasos `init`, `ca`, `csr`, `firmar` | ✅ |
| `certs/ca.crt` | Certificado raíz (público, se importa en navegadores) | ✅ |
| `certs/web01.crt` | Certificado del servidor | ✅ |
| `private/*.key` | Llaves privadas | ❌ nunca |

## Pasos (Fase 1)

```bash
cd ca
bash scripts/ca.sh init          # estructura: private/ (700), index.txt, serial = 1000
bash scripts/ca.sh ca            # llave RSA 4096 cifrada con AES-256 + raíz autofirmada (10 años)
bash scripts/ca.sh csr web01     # llave RSA 2048 sin passphrase + CSR con el SAN de web01.cnf
bash scripts/ca.sh firmar web01  # firma con ext_servidor (397 días) + openssl verify
```

La CA vive **solo en el Mac** de B. `ca.sh ca` y `ca.sh firmar` piden la passphrase de la CA, que se guarda en el gestor de contraseñas. `ca.sh ca` se niega a sobrescribir una CA existente: si se regenerara, habría que volver a importar la raíz en todos los navegadores.

Copiar a `web01` con `bash nativo/desplegar.sh web01`. Copia `ca.crt`, `web01.crt` y `web01.key`, nunca `ca.key`. El instalador de `web01` los coloca en `/etc/ssl/paas/web01.crt` (644) y `/etc/ssl/private/web01.key` (640, `root:ssl-cert`), y agrega la raíz al almacén del sistema.

Importar `certs/ca.crt`:

- **Navegador de la demo:** Firefox usa su propio almacén (*Ajustes → Certificados → Importar*). Chrome y Edge usan el del sistema.
- **Sistema Linux:** `sudo cp ca.crt /usr/local/share/ca-certificates/paas-ca.crt && sudo update-ca-certificates`.
- **macOS (anfitriona):** `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt`. Safari y Chrome usan este llavero.

## Terminado cuando

- [x] `openssl verify -CAfile certs/ca.crt certs/web01.crt` → `OK`
- [x] `openssl x509 -in certs/web01.crt -noout -ext subjectAltName` muestra `web01.paas.internal`, `www.paas.internal` e `IP:10.10.10.20`
- [x] `https://web01.paas.internal` muestra el candado **sin advertencias** en el navegador de la demo
- [x] Cada comando quedó documentado en `docs/documentacion.md` §4

## Preguntas probables en la defensa

- ¿Por qué los navegadores ignoran el CN y exigen SAN?
- ¿Qué diferencia hay entre `ext_ca` (`CA:true`, `keyCertSign`) y `ext_servidor` (`serverAuth`)?
- ¿Por qué el certificado del servidor dura 397 días y no 10 años?
- ¿Qué pasa si se filtra `private/ca.key`?
- ¿Qué hace `copy_extensions` y qué riesgo tiene?
