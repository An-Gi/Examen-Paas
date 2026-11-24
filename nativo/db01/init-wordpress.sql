-- Base y usuario de WordPress — db01 · Estudiante B (Fase 1)
-- Plantilla: instalar.sh la procesa con envsubst. NUNCA escribir contraseñas reales aquí.
CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- El usuario solo puede conectarse desde web01
CREATE USER IF NOT EXISTS 'wp'@'10.10.10.20' IDENTIFIED BY '${WP_DB_PASS}';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wp'@'10.10.10.20';
-- TODO(B): ¿ALL o solo los privilegios que WordPress necesita? Justificarlo en la documentación.

FLUSH PRIVILEGES;
