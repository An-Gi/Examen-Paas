# CMS con Kubernetes (k3s)

**Responsable:** Estudiante B · **Fase:** 4 · **Rubro:** 10 %

WordPress + MySQL en un clúster k3s de un nodo, en `k8s01` (10.10.10.40). Se publica con el Ingress Traefik que trae k3s en `http://cms-k8s.paas.internal`.

> **Cambio pendiente (F4, [ADR-0003](../docs/decisiones/0003-alcance-servicios-respuestas-profesor.md) §4):** la base de datos sale del clúster. WordPress usará la base `wordpress_k8s` de `db01` por medio de un `Service` sin selector con un `Endpoints` a `10.10.10.10:3306`, y `02-mysql.yaml` (StatefulSet) se elimina. Lo que sigue describe el diseño anterior hasta que se haga la F4.

```
k8s/
├── instalar-k3s.sh
└── manifests/
    ├── kustomization.yaml
    ├── 00-namespace.yaml
    ├── 01-secret.example.yaml   → copiar a 01-secret.yaml (ignorado por Git)
    ├── 02-mysql.yaml            Service headless + StatefulSet + volumeClaimTemplate
    ├── 03-wordpress.yaml        PVC + Deployment + Service
    └── 04-ingress.yaml          Ingress (Traefik) para cms-k8s.paas.internal
```

## Uso

```bash
# En k8s01
bash instalar-k3s.sh
cp manifests/01-secret.example.yaml manifests/01-secret.yaml   # cambiar los valores
kubectl apply -k manifests/
kubectl -n cms get all
```

## Demo (2 min)

```bash
kubectl -n cms get all,pvc,ingress
kubectl -n cms scale deploy/wordpress --replicas=3 && kubectl -n cms get pods -w
kubectl -n cms delete pod -l app=wordpress --wait=false && kubectl -n cms get pods -w   # se recrean solos
curl -I http://cms-k8s.paas.internal
```

## Terminado cuando

- [ ] `kubectl -n cms get pods`: todo en `Running`/`Ready`
- [ ] `http://cms-k8s.paas.internal` carga WordPress desde la anfitriona
- [ ] Los datos sobreviven a borrar los pods (PVC)
- [ ] Escalar a 3 réplicas funciona en vivo
- [ ] Ningún secreto en Git

## Preguntas probables en la defensa

- Deployment vs StatefulSet: ¿por qué MySQL va en StatefulSet?
- ¿Qué hace el Ingress y quién es el Ingress Controller aquí?
- ¿Cómo comparten 3 réplicas de WordPress un PVC `ReadWriteOnce`? (un solo nodo; en multinodo haría falta RWX)
- ¿Qué pasa si se borra el namespace?
- ¿Un Secret está cifrado? (base64 no es cifrado)
