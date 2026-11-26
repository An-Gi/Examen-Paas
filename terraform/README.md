# Terraform — infraestructura de la VPN en AWS

**Responsable:** Estudiante A · **Fases:** 0 (prueba de humo) y 2 · **Rubro:** VPN con IaC (20 %)

Crea en la VPC por defecto de `us-east-2`: key pair, security group, EC2 Ubuntu 24.04 (t3.micro) e IP elástica. También **genera el inventario de Ansible** (`../ansible/inventories/aws.ini`) con `local_file`, así Ansible siempre apunta a la IP actual.

| Archivo | Contenido |
|---|---|
| `versions.tf` | Versiones de Terraform y proveedores (`aws`, `local`), proveedor con `default_tags` |
| `variables.tf` | Región, perfil, tipo de instancia, IP de administración, llave pública |
| `main.tf` | AMI de Ubuntu (Fase 0) + key pair, security group, EC2, IP elástica e inventario (Fase 2) |
| `outputs.tf` | `ami_ubuntu` (Fase 0); IP pública y comando SSH (Fase 2) |
| `templates/inventario.ini.tftpl` | Plantilla del inventario de Ansible |
| `terraform.tfvars.example` | Copiar a `terraform.tfvars` (ignorado por Git) |

## Fase 0: prueba de humo

```bash
cp terraform.tfvars.example terraform.tfvars    # completar cidr_admin
terraform init && terraform validate && terraform plan
# Esperado: "+ ami_ubuntu = ami-..." y 0 recursos
```

## Fase 2: terminado cuando

- [ ] `terraform plan` sin cambios después de `apply` (idempotente)
- [x] SSH solo desde `cidr_admin`; 1194/TCP, 1195/TCP (TUN del teléfono), 80 y 443 abiertos al mundo
- [x] `terraform output` muestra la IP elástica y se generó `ansible/inventories/aws.ini`
- [x] `terraform destroy` deja la cuenta en 0 recursos (incluida la IP elástica) — verificado con la AWS CLI el 2026-11-26
- [x] Cada recurso tiene un comentario que explica por qué existe

## Preguntas probables en la defensa

- ¿Qué es el *state* y por qué no está en Git?
- ¿Por qué una IP elástica y no la IP pública automática?
- ¿Qué pasa si ejecutan `terraform apply` dos veces?
- ¿Para qué sirve `.terraform.lock.hcl`?
- ¿Por qué el usuario IAM solo tiene `AmazonEC2FullAccess`?
