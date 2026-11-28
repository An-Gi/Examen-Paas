# Windows Domain Controller (Active Directory) en AWS — Estudiante A (Fase 3)
# Por qué en EC2: no existe Windows Server para ARM64 y la anfitriona es un Mac Apple Silicon (ADR-0004).
# Solo se crea con crear_ad = true (cuesta ~USD 0,06/h): encenderlo para las pruebas y la defensa.
# Demo: RDP por la VPN a ad_ip_privada -> "Usuarios y equipos de Active Directory" -> nuevo usuario
#       en OU=Usuarios -> aparece en el OpenLDAP de docker01 tras la sincronización (docker/02-ldap).

# AMI oficial de Amazon con licencia de Windows incluida (Desktop Experience: trae la consola gráfica)
data "aws_ami" "windows" {
  count       = var.crear_ad ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }
}

# Firewall del AD: solo acepta tráfico que viene del servidor VPN. Los clientes VPN (laptop, teléfono,
# docker01) llegan con la IP privada del servidor VPN gracias al MASQUERADE del rol openvpn.
# Nada se abre a Internet: el AD ni siquiera tiene IP pública.
resource "aws_security_group" "ad" {
  count       = var.crear_ad ? 1 : 0
  name        = "${var.proyecto}-ad"
  description = "Active Directory: solo desde el servidor VPN"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${var.proyecto}-ad" }
}

# Todos los puertos desde la VPN: AD usa muchos (LDAP 389, Kerberos 88, DNS 53, RDP 3389, RPC...)
# y el origen ya está limitado a una sola máquina de confianza.
resource "aws_vpc_security_group_ingress_rule" "ad_desde_vpn" {
  count                        = var.crear_ad ? 1 : 0
  security_group_id            = aws_security_group.ad[0].id
  description                  = "Todo el trafico que llega por la VPN"
  referenced_security_group_id = aws_security_group.vpn.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "ad_salida" {
  count             = var.crear_ad ? 1 : 0
  security_group_id = aws_security_group.ad[0].id
  description       = "Respuestas y activacion de Windows (KMS de AWS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "ad" {
  count                       = var.crear_ad ? 1 : 0
  ami                         = data.aws_ami.windows[0].id
  instance_type               = var.tipo_instancia_ad
  vpc_security_group_ids      = [aws_security_group.ad[0].id]
  subnet_id                   = data.aws_subnet.vpn.id
  associate_public_ip_address = false
  # IP privada fija: docker01 y la documentación la usan; así no cambia entre apply y apply
  private_ip = cidrhost(data.aws_subnet.vpn.cidr_block, 50)
  # Sin key_name: EC2 solo cifra la contraseña de Windows con llaves RSA y la nuestra es ed25519.
  # La contraseña de Administrator la fija el script de arranque.

  # Instala el AD en tres etapas con reinicios entre ellas (templates/ad-bootstrap.ps1.tftpl).
  # Ojo: el user_data queda legible en los metadatos de la instancia; riesgo aceptado en el examen.
  user_data = templatefile("${path.module}/templates/ad-bootstrap.ps1.tftpl", {
    dominio       = var.ad_dominio
    netbios       = var.ad_netbios
    pass_admin    = var.ad_password_admin
    pass_sync     = var.ad_password_sync
    pass_usuarios = var.ad_password_usuarios
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30 # mínimo de la AMI de Windows
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition = alltrue([for p in [var.ad_password_admin, var.ad_password_sync, var.ad_password_usuarios] :
      length(p) >= 14 && can(regex("[A-Z]", p)) && can(regex("[a-z]", p)) && can(regex("[0-9]", p))])
      error_message = "Con crear_ad = true, las tres ad_password_* deben tener >= 14 caracteres con mayúsculas, minúsculas y números (terraform.tfvars)."
    }
  }

  tags = { Name = "${var.proyecto}-ad" }
}
