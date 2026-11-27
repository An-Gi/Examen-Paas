# CMS con Kubernetes (k3s)

**Responsable:** Estudiante B · **Fase:** 4 · **Rubro:** 10 %

WordPress en un clúster k3s de un nodo, en `k8s01` (10.10.10.40). Se publica con el Ingress Traefik que trae k3s en `http://cms-k8s.paas.internal`.

La **base de datos no está en el clúster**: es la base `wordpress_k8s` de MySQL en `db01`, con un usuario `wp_k8s` que solo puede entrar desde `10.10.10.40` ([ADR-0003](../docs/decisiones/0003-alcance-servicios-respuestas-profesor.md) §4). El clúster es de un nodo, y un MySQL dentro de él quedaría en el mismo servidor que el CMS, que el enunciado prohíbe.

> **Cambio pendiente (F4, [ADR-0003](../docs/decisiones/0003-alcance-servicios-respuestas-profesor.md) §4):** la base de datos sale del clúster. WordPress usará la base `wordpress_k8s` de `db01` por medio de un `Service` sin selector con un `Endpoints` a `10.10.10.10:3306`, y `02-mysql.yaml` (StatefulSet) se elimina. Lo que sigue describe el diseño anterior hasta que se haga la F4.

```
k8s/
├── instalar-k3s.sh            k3s v1.37.2+k3s1 fijo, NIC de la LAN, kubeconfig 600 → ~/.kube/config
├── crear-secret.sh            Secret wordpress-db: contraseña de wp_k8s + salts de WordPress
└── manifests/                 kubectl apply -k manifests/
    ├── kustomization.yaml
    ├── 00-namespace.yaml
    ├── 02-db-externa.yaml     Service "mysql" sin selector + EndpointSlice → 10.10.10.10:3306
    ├── 03-wordpress.yaml      PVC (local-path) + Deployment + Service
    └── 04-ingress.yaml        Ingress (Traefik) para cms-k8s.paas.internal
```

## Instalación

```bash
# En el Mac (raíz del repo): copiar los archivos
rsync -aR k8s scripts/vm/ajustes-demo.sh zekken@10.10.10.40:paas/
# En k8s01
sudo bash ~/paas/scripts/vm/ajustes-demo.sh   # swap y sin actualizaciones automáticas
sudo bash ~/paas/k8s/instalar-k3s.sh
bash ~/paas/k8s/crear-secret.sh               # pide la contraseña de wp_k8s (la de db01/instalar.sh)
kubectl apply -k ~/paas/k8s/manifests/
kubectl -n cms rollout status deploy/wordpress
```

Requisito previo: `db01` instalado (F1) y encendido. Luego se termina la instalación de WordPress en `http://cms-k8s.paas.internal`; en el Mac hace falta `10.10.10.40 cms-k8s.paas.internal` en `/etc/hosts` hasta que esté el BIND de A.

> `kubectl` sin sudo usa `~/.kube/config`. En una sesión interactiva lo exporta `~/.bashrc`; en `ssh k8s01 'comando'` no se lee `.bashrc`, así que hay que usar `export KUBECONFIG=~/.kube/config` (los scripts ya lo hacen).

## Demo (2 min)

```bash
kubectl -n cms get all,pvc,ingress,endpointslice
kubectl -n cms scale deploy/wordpress --replicas=3 && kubectl -n cms get pods -w      # ~12 s
kubectl -n cms delete pod -l app=wordpress --wait=false && kubectl -n cms get pods -w  # se recrean solos
curl -I http://cms-k8s.paas.internal
# La base es externa: el pod entra a db01 con la IP del nodo
kubectl -n cms exec deploy/wordpress -- getent hosts mysql
```

## Terminado cuando

- [x] `kubectl -n cms get pods`: todo en `Running`/`Ready`
- [x] `http://cms-k8s.paas.internal` carga WordPress desde la anfitriona
- [x] Los datos sobreviven a borrar los pods (contenido en el PVC, entradas en `db01`)
- [x] Escalar a 3 réplicas funciona en vivo
- [x] Ningún secreto en Git (el Secret lo crea `crear-secret.sh`; no hay archivo)

## Preguntas probables en la defensa

- ¿Por qué la base de datos está fuera del clúster? (regla del WebServer + clúster de un nodo, ADR-0003)
- ¿Qué es un Service sin selector y para qué sirve el EndpointSlice manual?
- ¿Con qué IP llega el pod a `db01`? (la del nodo, `10.10.10.40`: flannel hace SNAT al salir del clúster)
- ¿Por qué las salts de WordPress están en el Secret? (si cada réplica tuviera las suyas, una sesión no valdría en otro pod)
- readiness vs liveness: ¿por qué la de vida no consulta la base?
- ¿Qué hace el Ingress y quién es el Ingress Controller aquí? (Traefik, enruta por `Host`)
- ¿Cómo comparten 3 réplicas un PVC `ReadWriteOnce`? (un solo nodo; en multinodo haría falta RWX)
- ¿Un Secret está cifrado? (no: base64; lo protege el acceso a la API y el kubeconfig 600)
