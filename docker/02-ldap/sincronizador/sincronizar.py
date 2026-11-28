"""Sincronización en un solo sentido: Active Directory -> OpenLDAP — Estudiante A (Fase 3).

El AD (Windows Server en EC2, terraform/ad.tf) es la fuente de verdad: los usuarios se crean allí y
este proceso los copia cada INTERVALO segundos al OpenLDAP de docker01 (ADR-0004).

  AD  OU=Usuarios,DC=ad,DC=paas,DC=internal      ->  OpenLDAP  ou=usuarios / ou=grupos, dc=paas,dc=internal
      usuario activo  (sAMAccountName)            ->  uid=<sam>  inetOrgPerson + posixAccount
      grupo           (cn, member)                ->  cn=<grupo> groupOfNames

- Solo toca entradas con la marca employeeType / businessCategory = ad-sync: lo creado a mano no se borra.
- Altas, cambios y bajas: un usuario borrado o deshabilitado en el AD desaparece de OpenLDAP.
- uidNumber = 10000 + RID (la última parte del SID): estable entre ejecuciones y único en el dominio.
- Las contraseñas NO se copian: el AD nunca entrega sus hashes por LDAP (unicodePwd es de solo escritura).
"""
import hashlib
import os
import ssl
import sys
import time

from ldap3 import ALL_ATTRIBUTES, MODIFY_REPLACE, SUBTREE, Connection, Server, Tls

MARCA = "ad-sync"
BASE_UID = 10000
GID_USUARIOS = BASE_UID + 513  # RID de "Domain Users": grupo primario de todos los usuarios del AD


def env(nombre, defecto=None):
    valor = os.environ.get(nombre, defecto)
    if valor is None:
        sys.exit(f"Falta la variable de entorno {nombre}")
    return valor


AD_URL = env("AD_URL")                       # ldaps://dc01.ad.paas.internal (por la VPN)
AD_USUARIO = env("AD_USUARIO")               # svc-sync@ad.paas.internal
AD_PASSWORD = env("AD_PASSWORD")
AD_BASE = env("AD_BASE")                     # OU=Usuarios,DC=ad,DC=paas,DC=internal
AD_CA = env("AD_CA", "/ad-ca/ad-ca.crt")    # raíz de la CA del AD (PAAS-AD-CA) para verificar LDAPS
LDAP_URL = env("LDAP_URL", "ldap://openldap:389")
LDAP_ADMIN = env("LDAP_ADMIN")               # cn=admin,dc=paas,dc=internal
LDAP_PASSWORD = env("LDAP_PASSWORD")
LDAP_BASE = env("LDAP_BASE")                 # dc=paas,dc=internal
INTERVALO = int(env("INTERVALO", "120"))
OU_USUARIOS = f"ou=usuarios,{LDAP_BASE}"
OU_GRUPOS = f"ou=grupos,{LDAP_BASE}"


def log(mensaje):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), mensaje, flush=True)


def conectar_ad(verificar=True):
    """LDAPS: Windows Server 2025 rechaza el bind simple sin TLS ni firma por el 389.

    Con verificar=True se exige que el certificado del DC esté firmado por la raíz guardada en AD_CA
    y que su nombre coincida con el de AD_URL (dc01.ad.paas.internal, no la IP).
    """
    tls = Tls(validate=ssl.CERT_REQUIRED, ca_certs_file=AD_CA) if verificar else Tls(validate=ssl.CERT_NONE)
    return Connection(Server(AD_URL, use_ssl=True, tls=tls, connect_timeout=10), AD_USUARIO, AD_PASSWORD,
                      auto_bind=True, receive_timeout=30)


def obtener_ca(destino):
    """Primera vez (confianza en el primer uso): lee la raíz PAAS-AD-CA publicada en el AD y la guarda.

    La conexión ya va cifrada, pero todavía sin verificar; por eso se imprime la huella SHA-256, que
    debe coincidir con la que el AD dejó en C:\\paas\\bootstrap.log ("Raíz PAAS-AD-CA SHA256: ...").
    """
    with conectar_ad(verificar=False) as ad:
        dominio = ",".join(p for p in AD_BASE.split(",") if p.upper().startswith("DC="))
        ad.search(f"CN=Certification Authorities,CN=Public Key Services,CN=Services,CN=Configuration,{dominio}",
                  "(objectClass=certificationAuthority)", SUBTREE, attributes=["cn", "cACertificate"])
        if not ad.entries:
            sys.exit("El AD todavía no publica su CA (etapa 3 del arranque sin terminar)")
        der = ad.entries[0].cACertificate.raw_values[0]
    with open(destino, "w") as f:
        f.write(ssl.DER_cert_to_PEM_cert(der))
    log(f"raíz {ad.entries[0].cn} guardada en {destino}")
    log(f"SHA256: {hashlib.sha256(der).hexdigest().upper()}")


def rid(sid_binario):
    """Último bloque de 32 bits del objectSid (little endian): el número relativo dentro del dominio."""
    return int.from_bytes(sid_binario[-4:], "little")


def leer_ad(ad):
    """Devuelve {sam: atributos} de los usuarios activos y {grupo: [sam]} de los grupos de AD_BASE."""
    # userAccountControl bit 2 = cuenta deshabilitada (regla de coincidencia bit a bit de AD)
    ad.search(AD_BASE, "(&(objectCategory=person)(objectClass=user)"
                       "(!(userAccountControl:1.2.840.113556.1.4.803:=2)))",
              SUBTREE, attributes=["sAMAccountName", "givenName", "sn", "displayName", "mail", "objectSid"])
    usuarios, dn_a_sam = {}, {}
    for e in ad.entries:
        sam = str(e.sAMAccountName).lower()
        dn_a_sam[e.entry_dn.lower()] = sam
        nombre = str(e.givenName) if e.givenName else sam
        apellido = str(e.sn) if e.sn else sam
        usuarios[sam] = {
            "objectClass": ["inetOrgPerson", "posixAccount"],
            "uid": sam,
            "cn": str(e.displayName) if e.displayName else f"{nombre} {apellido}",
            "givenName": nombre,
            "sn": apellido,
            "mail": str(e.mail) if e.mail else f"{sam}@paas.internal",
            "uidNumber": str(BASE_UID + rid(e.objectSid.raw_values[0])),
            "gidNumber": str(GID_USUARIOS),
            "homeDirectory": f"/home/{sam}",
            "loginShell": "/bin/bash",
            "employeeType": MARCA,
        }
    ad.search(AD_BASE, "(objectClass=group)", SUBTREE, attributes=["cn", "member"])
    grupos = {}
    for e in ad.entries:
        miembros = sorted(dn_a_sam[m.lower()] for m in e.member.values if m.lower() in dn_a_sam)
        grupos[str(e.cn)] = miembros
    return usuarios, grupos


def leer_ldap(ldap, base, marca_attr):
    ldap.search(base, f"({marca_attr}={MARCA})", SUBTREE, attributes=ALL_ATTRIBUTES)
    return {e.entry_dn: e.entry_attributes_as_dict for e in ldap.entries}


def comparar(actual, deseado):
    """Atributos que cambiaron (objectClass no se toca: una entrada no cambia de tipo)."""
    cambios = {}
    for attr, valor in deseado.items():
        if attr == "objectClass":
            continue
        nuevo = valor if isinstance(valor, list) else [valor]
        if sorted(map(str, actual.get(attr, []))) != sorted(nuevo):
            cambios[attr] = [(MODIFY_REPLACE, nuevo)]
    return cambios


def aplicar(ldap, existentes, deseados):
    """Altas, cambios y bajas para que `existentes` (con la marca) quede igual a `deseados`."""
    resumen = {"altas": 0, "cambios": 0, "bajas": 0}
    for dn, attrs in deseados.items():
        if dn not in existentes:
            ldap.add(dn, attributes=attrs)
            log(f"alta   {dn}: {ldap.result['description']}")
            resumen["altas"] += 1
        else:
            cambios = comparar(existentes[dn], attrs)
            if cambios:
                ldap.modify(dn, cambios)
                log(f"cambio {dn} {sorted(cambios)}: {ldap.result['description']}")
                resumen["cambios"] += 1
    for dn in set(existentes) - set(deseados):
        ldap.delete(dn)
        log(f"baja   {dn}: {ldap.result['description']}")
        resumen["bajas"] += 1
    return resumen


def sincronizar():
    with conectar_ad() as ad:
        usuarios, grupos = leer_ad(ad)
    with Connection(Server(LDAP_URL, connect_timeout=10), LDAP_ADMIN, LDAP_PASSWORD, auto_bind=True) as ldap:
        # Usuarios primero: los grupos apuntan a ellos con member
        r1 = aplicar(ldap, leer_ldap(ldap, OU_USUARIOS, "employeeType"),
                     {f"uid={sam},{OU_USUARIOS}": a for sam, a in usuarios.items()})
        # groupOfNames exige al menos un miembro: un grupo vacío en el AD no se copia
        deseados = {
            f"cn={g},{OU_GRUPOS}": {"objectClass": ["groupOfNames"], "cn": g, "businessCategory": MARCA,
                                    "member": [f"uid={s},{OU_USUARIOS}" for s in miembros]}
            for g, miembros in grupos.items() if miembros
        }
        r2 = aplicar(ldap, leer_ldap(ldap, OU_GRUPOS, "businessCategory"), deseados)
    log(f"sincronizado: {len(usuarios)} usuarios y {len(deseados)} grupos del AD "
        f"(usuarios {r1}, grupos {r2})")


if __name__ == "__main__":
    if "--obtener-ca" in sys.argv:
        obtener_ca(AD_CA)
        sys.exit(0)
    una_vez = "--una-vez" in sys.argv
    while True:
        try:
            sincronizar()
        except Exception as error:  # el AD puede estar apagado (EC2 detenida): se reintenta
            log(f"ERROR {type(error).__name__}: {error}")
            if una_vez:
                sys.exit(1)
        if una_vez:
            break
        time.sleep(INTERVALO)
