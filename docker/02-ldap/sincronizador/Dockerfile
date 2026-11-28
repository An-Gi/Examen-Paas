# Sincronizador AD -> OpenLDAP — Estudiante A (Fase 3). Imagen mínima: Python + ldap3 de Alpine (arm64).
FROM alpine:3.22
RUN apk add --no-cache python3 py3-ldap3
COPY sincronizar.py /usr/local/bin/sincronizar.py
USER nobody
ENTRYPOINT ["python3", "-u", "/usr/local/bin/sincronizar.py"]
