-- Bases y usuarios de WordPress — db01 · Estudiante B (Fase 1)
-- Plantilla: instalar.sh la procesa con envsubst. NUNCA escribir contraseñas reales aquí.
-- Es idempotente: se puede volver a correr (por ejemplo, para cambiar una contraseña).

-- CMS nativo (web01). El usuario solo puede conectarse desde 10.10.10.20.
CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wp'@'10.10.10.20' IDENTIFIED BY '${WP_DB_PASS}';
ALTER USER 'wp'@'10.10.10.20' IDENTIFIED BY '${WP_DB_PASS}';
-- Privilegio mínimo: lo que WordPress usa para su contenido y para crear/actualizar sus tablas
-- (instalación, actualizaciones del núcleo y plugins). Sin GRANT OPTION, FILE, PROCESS ni SUPER,
-- y solo sobre su propia base.
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP,
      CREATE TEMPORARY TABLES, LOCK TABLES
  ON wordpress.* TO 'wp'@'10.10.10.20';
