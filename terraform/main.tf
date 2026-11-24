# Infraestructura de la VPN en AWS — Estudiante A
# Fase 0: solo la búsqueda de la AMI (valida credenciales, región y proveedor).
# Fase 2: completar los recursos marcados con TODO(A).

# Ubuntu Server 24.04 LTS oficial de Canonical (mismo SO que las VMs de la LAN)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- TODO(A) · Fase 2 --------------------------------------------------------------
#
# 1. resource "aws_key_pair" "admin"
#      public_key = file(pathexpand(var.ruta_llave_publica))
#
# 2. resource "aws_security_group" "vpn"   (VPC por defecto)
#      ingreso 22/tcp      solo desde var.cidr_admin
#      ingreso var.puerto_vpn/tcp desde 0.0.0.0/0     (OpenVPN, TCP según el enunciado)
#      ingreso 80/tcp y 443/tcp desde 0.0.0.0/0       (Nginx: acceso público al CMS)
#      egreso  todo
#    Preferir aws_vpc_security_group_ingress_rule / egress_rule (una regla por recurso).
#
# 3. resource "aws_instance" "vpn"
#      ami = data.aws_ami.ubuntu.id, instance_type = var.tipo_instancia,
#      key_name, vpc_security_group_ids, root_block_device (gp3, 8 GB)
#
# 4. resource "aws_eip" "vpn"
#      domain = "vpc", instance = aws_instance.vpn.id
#
# 5. resource "local_file" "inventario_ansible"
#      filename = "${path.module}/../ansible/inventories/aws.ini"
#      content  = templatefile("${path.module}/templates/inventario.ini.tftpl", {
#        ip_publica    = aws_eip.vpn.public_ip
#        llave_privada = pathexpand(trimsuffix(var.ruta_llave_publica, ".pub"))
#      })
#      file_permission = "0644"
