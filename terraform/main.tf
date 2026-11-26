# Infraestructura de la VPN en AWS — Estudiante A
# Fase 0: solo la búsqueda de la AMI (valida credenciales, región y proveedor).
# Fase 2: key pair, security group, EC2, IP elástica e inventario de Ansible.
# Demo: terraform apply -> terraform output -> make vpn -> terraform destroy

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

# --- Fase 2 ------------------------------------------------------------------------

# Llave pública para entrar por SSH a la EC2 (la privada nunca sale de la laptop de A).
# Ansible la usa para conectarse; sin ella no hay forma de configurar la instancia.
resource "aws_key_pair" "admin" {
  key_name   = "${var.proyecto}-admin"
  public_key = file(pathexpand(var.ruta_llave_publica))
}

# Se usa la VPC por defecto: una sola instancia pública no justifica crear VPC, subredes
# y tablas de rutas propias (menos recursos = menos que explicar y menos que pueda fallar).
data "aws_vpc" "default" {
  default = true
}

# Firewall de la instancia. Es stateful: las respuestas salen solas, por eso basta con
# declarar el ingreso que se permite.
resource "aws_security_group" "vpn" {
  name        = "${var.proyecto}-vpn"
  description = "OpenVPN TCP, Nginx (CMS publico) y SSH restringido"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${var.proyecto}-vpn" }
}

# SSH solo desde la IP de administración: el puerto 22 abierto al mundo recibe fuerza bruta en minutos.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.vpn.id
  description       = "SSH de administracion (Ansible)"
  cidr_ipv4         = var.cidr_admin
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# OpenVPN abierto a todos: la autenticación la hace la PKI (certificado + tls-crypt), no la IP.
# TCP porque lo exige el enunciado.
resource "aws_vpc_security_group_ingress_rule" "openvpn" {
  security_group_id = aws_security_group.vpn.id
  description       = "OpenVPN TCP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = var.puerto_vpn
  to_port           = var.puerto_vpn
}

# HTTP y HTTPS: Nginx publica cms.<dominio> (Fase 5). El 80 también lo usa certbot (HTTP-01).
resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.vpn.id
  description       = "Nginx reverse proxy del CMS (${each.value})"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}

# Toda la salida permitida: la EC2 es el gateway a Internet de los clientes VPN (redirect-gateway).
resource "aws_vpc_security_group_egress_rule" "todo" {
  security_group_id = aws_security_group.vpn.id
  description       = "Salida a Internet (NAT de los clientes VPN, apt, certbot)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Servidor OpenVPN + Nginx. t3.micro alcanza: OpenVPN y Nginx con pocos clientes usan < 200 MB.
resource "aws_instance" "vpn" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tipo_instancia
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.vpn.id]

  # La instancia reenvía paquetes de los clientes VPN con su propia IP (MASQUERADE),
  # así que el source/dest check de AWS no estorba; se deja activo (valor por defecto).

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # IMDSv2 obligatorio: evita que un SSRF lea credenciales del servicio de metadatos.
  metadata_options {
    http_tokens = "required"
  }

  # Si AWS publica una AMI nueva, no recrear la instancia (perdería la PKI de OpenVPN).
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.proyecto}-vpn" }
}

# IP elástica: la IP pública automática cambia en cada stop/start, y de ella dependen el
# "remote" de los .ovpn y el registro A de cms.<dominio>. Se cobra si queda sin asociar.
resource "aws_eip" "vpn" {
  domain   = "vpc"
  instance = aws_instance.vpn.id

  tags = { Name = "${var.proyecto}-vpn" }
}

# Inventario de Ansible generado: Ansible siempre apunta a la IP actual sin editarlo a mano.
resource "local_file" "inventario_ansible" {
  filename = "${path.module}/../ansible/inventories/aws.ini"
  content = templatefile("${path.module}/templates/inventario.ini.tftpl", {
    ip_publica    = aws_eip.vpn.public_ip
    llave_privada = pathexpand(trimsuffix(var.ruta_llave_publica, ".pub"))
  })
  file_permission = "0644"
}
