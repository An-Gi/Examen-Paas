# Variables de entrada — Estudiante A
# Valores reales en terraform.tfvars (ignorado por Git). Ejemplo: terraform.tfvars.example

variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
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
  description = "Puerto TCP de OpenVPN (plan B: 443 con port-share)"
  type        = number
  default     = 1194
}
