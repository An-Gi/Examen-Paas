# Variables de entrada — Estudiante A
# Valores reales en terraform.tfvars (ignorado por Git). Ejemplo: terraform.tfvars.example

variable "region" {
  # Las cuentas creadas con "Sign up for AWS (new)" (proyectos) solo permiten EC2 en la región
  # asignada según el país de contacto: us-east-2 para América. us-east-1 da "explicit deny in a SCP".
  description = "Región de AWS"
  type        = string
  default     = "us-east-2"
}

variable "perfil_aws" {
  description = "Perfil de ~/.aws/credentials (aws configure --profile ...)"
  type        = string
  default     = "examen-paas"
}

variable "proyecto" {
  description = "Prefijo para nombres y etiquetas"
  type        = string
  default     = "examen-paas"
}

variable "tipo_instancia" {
  description = "Tipo de EC2 para OpenVPN + Nginx"
  type        = string
  default     = "t3.micro"
}

variable "cidr_admin" {
  description = "IP pública de administración (SSH) en formato CIDR, p. ej. 201.200.10.5/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_admin, 0))
    error_message = "cidr_admin debe ser un CIDR válido, p. ej. 201.200.10.5/32."
  }
}

variable "ruta_llave_publica" {
  description = "Llave pública SSH que se carga como key pair"
  type        = string
  default     = "~/.ssh/examen-paas.pub"
}

variable "puerto_vpn" {
  description = "Puerto TCP de OpenVPN, instancia TAP (plan B: 443 con port-share)"
  type        = number
  default     = 1194
}

variable "puerto_vpn_movil" {
  description = "Puerto TCP de la instancia OpenVPN TUN del teléfono (debe coincidir con vpn_movil_puerto de Ansible)"
  type        = number
  default     = 1195
}

# --- Active Directory (Fase 3, ad.tf) ----------------------------------------------

variable "crear_ad" {
  description = "Crea el Windows Domain Controller en EC2 (~USD 0,06/h). false = solo la VPN"
  type        = bool
  default     = false
}

variable "tipo_instancia_ad" {
  description = "Tipo de EC2 del AD. Windows con escritorio necesita ~4 GB"
  type        = string
  default     = "t3.medium"
}

variable "ad_dominio" {
  description = "Dominio de AD: subdominio de la zona interna para no chocar con el BIND de paas.internal"
  type        = string
  default     = "ad.paas.internal"
}

variable "ad_netbios" {
  description = "Nombre NetBIOS del dominio (PAAS\\usuario)"
  type        = string
  default     = "PAAS"
}

# Contraseñas: solo en terraform.tfvars (ignorado por Git) y en el gestor de contraseñas.
# Windows exige complejidad: >= 14 caracteres con mayúsculas, minúsculas y números.
variable "ad_password_admin" {
  description = "Administrator del dominio (y modo de restauración DSRM)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ad_password_sync" {
  description = "Cuenta svc-sync, que lee el AD desde docker01"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ad_password_usuarios" {
  description = "Contraseña inicial de los usuarios de prueba (ana.mora, luis.vargas)"
  type        = string
  default     = ""
  sensitive   = true
}
