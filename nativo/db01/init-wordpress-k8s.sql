-- Base del CMS en Kubernetes — db01 · Estudiante B (Fase 1, la usa la F4)
-- ADR-0003 §4: el clúster es de un nodo, así que la base no vive en él. Base y usuario aparte:
-- los dos CMS son independientes y cada uno solo entra desde su servidor.
CREATE DATABASE IF NOT EXISTS wordpress_k8s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wp_k8s'@'10.10.10.40' IDENTIFIED BY '${WP_K8S_DB_PASS}';
ALTER USER 'wp_k8s'@'10.10.10.40' IDENTIFIED BY '${WP_K8S_DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP,
      CREATE TEMPORARY TABLES, LOCK TABLES
  ON wordpress_k8s.* TO 'wp_k8s'@'10.10.10.40';
