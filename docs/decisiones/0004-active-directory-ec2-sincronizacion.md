# ADR-0004: Active Directory en EC2 y sincronización AD → OpenLDAP

- **Estado:** Propuesta (se acepta cuando B apruebe el PR: agrega un cliente VPN en `docker01`, VM compartida)
- **Fecha:** 2026-11-28
- **Autor:** Estudiante A
- **Revisor:** Estudiante B

## Contexto

La consulta C3 (ADR-0003 §7) hace obligatoria la sincronización del LDAP con **Active Directory**, y el AD pasa a ser uno de los ocho servicios. ADR-0003 dejó abierto *dónde* corre Windows Server y pidió un spike de ≤ 1 h. Resultado del spike (2026-11-28):

- **No existe Windows Server para ARM64.** Microsoft no publica ISO ni VHD ARM64 de Windows Server 2025, y retiró de Windows Update los archivos de prueba que habían circulado. La anfitriona es un Mac Apple Silicon (ADR-0002), así que una VM normal de Windows Server no es posible.
- En el Mac solo se podría **emular** x86 (UTM/QEMU): 5–10 veces más lento y 2–4 GB más de RAM en un equipo de 16 GB que ya usa ~10 GB en VMs.

## Decisión

1. **Windows Server 2025 (Desktop Experience) en una EC2 t3.medium** de la misma VPC que la VPN (`terraform/ad.tf`), con la AMI oficial de Amazon (licencia incluida).
   - Se crea solo con `crear_ad = true` (~USD 0,06/h): se enciende para las pruebas y la defensa.
   - **Sin IP pública.** Su security group solo acepta tráfico del servidor VPN. Los clientes VPN llegan con la IP privada del servidor gracias al `MASQUERADE` del rol `openvpn`.
   - IP privada fija **`172.31.0.50`** (host `.50` de la subred por defecto de `us-east-2a`, donde también va la VPN). Sin fijar la subred, AWS elige una zona al azar y la IP cambiaba entre `apply` y `apply`.
   - La instalación es automática (`templates/ad-bootstrap.ps1.tftpl`), en cuatro etapas con reinicios: nombre `dc01` → bosque `ad.paas.internal` (NetBIOS `PAAS`, con DNS integrado) → `OU=Usuarios` y `OU=Servicios`, grupo `Estudiantes`, dos usuarios de prueba y la cuenta de solo lectura `svc-sync` → CA empresarial **AD CS** (`PAAS-AD-CA`), que le emite al DC su certificado para LDAPS.
   - El script se entrega en el formato nativo de EC2Launch v2 (YAML, `frequency: always`) y reinicia con `exit 3010`. Las dos alternativas obvias fallaron en la prueba: `Restart-Computer` corta al agente antes de que programe la siguiente ejecución, y EC2Launch v2 ignora `<persist>` del formato XML.
2. **Dominio `ad.paas.internal`**: un subdominio de la zona interna, para no chocar con el BIND de `paas.internal` en `docker01`.
3. **`docker01` es cliente VPN** (`docker01.ovpn`, IP fija `10.8.0.30`). Ignora el `redirect-gateway` y solo enruta la VPC (`172.31.0.0/16`) por el túnel, así que sus servicios siguen saliendo por la LAN.
4. **LDAPS verificado.** Windows Server 2025 rechaza el *bind* simple por el 389 sin firma ni TLS (`Strong(er) authentication required`). En lugar de desactivar esa protección, el sincronizador se conecta a `ldaps://dc01.ad.paas.internal:636` y verifica el certificado del DC contra la raíz `PAAS-AD-CA`. La raíz se descarga una sola vez (`sincronizar.py --obtener-ca`, confianza en el primer uso) y su huella SHA-256 se compara con la que el AD deja en `C:\paas\bootstrap.log`.
5. **Sincronización en un solo sentido, AD → OpenLDAP**, con un sincronizador propio en Python (`docker/02-ldap/sincronizador`, `ldap3`), que corre como tercer contenedor del servicio LDAP cada 120 s:
   - copia los usuarios activos y los grupos de `OU=Usuarios` a `ou=usuarios` y `ou=grupos`;
   - aplica altas, cambios y bajas, y solo toca las entradas que él creó (marca `ad-sync`);
   - asigna `uidNumber` = 10000 + RID del SID, que es estable y único.

## Alternativas consideradas

| Alternativa | Ventajas | Desventajas | Motivo del descarte |
|---|---|---|---|
| Windows Server x86 emulado en el Mac | AD real y local | Muy lento; no cabe en la RAM | Riesgo alto en la demo |
| PC Windows x86 de B (32 GB) | AD real y rápido | No va a la defensa presencial; habría que llegar por túnel desde la red del TEC | Punto de falla que no controlamos |
| Samba 4 como AD DC (arm64, en Docker) | Local, liviano, sin costo | No es *Windows* Domain Controller | El profesor podría no aceptarlo (lectura conservadora, ADR-0003) |
| LSC (LDAP Synchronization Connector) | Herramienta estándar | Java (~200 MB de RAM por ejecución), configuración XML extensa y difícil de explicar | Un script de ~150 líneas hace lo mismo para este alcance y se defiende línea por línea |
| Desactivar la firma LDAP en el DC (`LDAPServerIntegrity`) | Rápido; *bind* simple por el 389 | Apaga una protección por defecto; la contraseña de `svc-sync` viajaría solo protegida por la VPN | LDAPS con AD CS es lo correcto y cuesta una etapa más |
| Sincronización en ambos sentidos | Cambios desde cualquier lado | Conflictos y el doble de lógica | La C3 no la pide |

## Consecuencias

- **Costo:** ~USD 0,06/h mientras el AD existe. `terraform destroy` lo borra junto con la VPN.
- **La demo depende de Internet**, igual que la VPN y el acceso público.
- **Prueba real (2026-11-28):** la instalación de 4 etapas tarda ~25 min. Altas, cambios (apellido), bajas (usuario deshabilitado) y miembros de grupo se copian. Una segunda ejecución da 0 cambios. Una entrada creada a mano en OpenLDAP no se toca. Con un certificado que no es de `PAAS-AD-CA`, la conexión se rechaza (`CERTIFICATE_VERIFY_FAILED`). El servicio usa ~170 MB.
- **Las contraseñas no se sincronizan.** El AD nunca entrega sus hashes por LDAP (`unicodePwd` es de solo escritura), así que en OpenLDAP los usuarios existen sin contraseña. Si hiciera falta autenticar contra OpenLDAP, la opción sería *pass-through* (`{SASL}` + `saslauthd` contra el AD). Se documenta como limitación.
- **Contrato nuevo A ↔ B:** `docker01.ovpn` se instala en `docker01` como servicio (`openvpn-client@docker01`), igual que `web01.ovpn` en `web01`.
- **La raíz `PAAS-AD-CA` cambia en cada instalación del AD:** después de un `destroy`/`apply` hay que repetir `--obtener-ca` en `docker01`.
- Las contraseñas del AD viajan en el `user_data` de la instancia, que es legible en sus metadatos. Es un riesgo aceptado para el examen: solo se llega a la instancia por la VPN.
